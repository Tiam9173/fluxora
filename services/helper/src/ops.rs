pub mod core {
    use once_cell::sync::Lazy;
    use serde::{Deserialize, Serialize};
    use sha2::{Digest, Sha256};
    use std::fs::{File, OpenOptions};
    use std::io::{BufRead, BufReader, Read};
    use std::path::{Path, PathBuf};
    use std::process::{Command, Stdio};
    use std::sync::atomic::{AtomicBool, Ordering};
    use std::sync::{Arc, Mutex};
    use std::thread;
    use std::time::Duration;

    use super::logs::log_message;

    const HASH_BUFFER_SIZE: usize = 65536;

    #[derive(Debug, Deserialize, Serialize, Clone)]
    pub struct StartParams {
        pub path: String,
        pub arg: String,
        pub home_dir: Option<String>,
    }

    static PROCESS: Lazy<Arc<Mutex<Option<std::process::Child>>>> =
        Lazy::new(|| Arc::new(Mutex::new(None)));

    pub fn start_core(start_params: StartParams) -> String {
        let core_path = match validate_core_path(&start_params.path) {
            Ok(path) => path,
            Err(e) => {
                log_message(e.clone());
                return e;
            }
        };

        // SEC-P0-01 — opened with write/delete sharing denied, and the handle is
        // held until the child image has been created. Without that, the file
        // could be replaced between the hash and `spawn()` (the TOCTOU window),
        // and the hash would describe a file that is no longer the one running.
        let file = match open_core_readonly(&core_path) {
            Ok(f) => f,
            Err(e) => {
                let msg = format!("Failed to open file: {}", e);
                log_message(msg.clone());
                return msg;
            }
        };

        if let Err(e) = file.lock_shared() {
            let msg = format!("Failed to lock file: {}", e);
            log_message(msg.clone());
            return msg;
        }

        let sha256 = match sha256_handle(&file) {
            Ok(hash) => hash,
            Err(e) => {
                let _ = file.unlock();
                let msg = format!("Failed to calculate SHA256: {}", e);
                log_message(msg.clone());
                return msg;
            }
        };

        if sha256 != env!("TOKEN") {
            let _ = file.unlock();
            let msg = format!("The SHA256 hash of the program requesting execution is: {}. The helper program only allows execution of applications with the SHA256 hash: {}.", sha256, env!("TOKEN"));
            log_message(msg.clone());
            return msg;
        }

        stop_core();
        let mut process = PROCESS.lock().unwrap_or_else(|e| e.into_inner());

        let mut command = Command::new(&core_path);
        command.stderr(Stdio::piped()).arg(&start_params.arg);

        if let Some(home_dir) = &start_params.home_dir {
            command.env("SAFE_PATHS", home_dir);
        }

        // The spawn happens while `file` still holds the deny-write handle, so
        // the image cannot have been swapped since it was hashed.
        let spawn_result = command.spawn();

        let _ = file.unlock();
        drop(file);

        match spawn_result {
            Ok(child) => {
                *process = Some(child);

                if let Some(ref mut child) = *process {
                    if let Some(stderr) = child.stderr.take() {
                        let reader = std::io::BufReader::new(stderr);
                        thread::spawn(move || {
                            for line in reader.lines() {
                                match line {
                                    Ok(output) => log_message(output),
                                    Err(_) => break,
                                }
                            }
                        });
                    }
                }
                start_dev_core_exit_watcher();
                "".to_string()
            }
            Err(e) => {
                log_message(e.to_string());
                e.to_string()
            }
        }
    }

    static WATCHER_STARTED: AtomicBool = AtomicBool::new(false);

    fn start_dev_core_exit_watcher() {
        if !should_exit_service_when_core_exits() {
            return;
        }
        if WATCHER_STARTED.swap(true, Ordering::SeqCst) {
            return;
        }

        thread::spawn(|| loop {
            thread::sleep(Duration::from_millis(500));

            let mut process = PROCESS.lock().unwrap_or_else(|e| e.into_inner());
            let Some(child) = process.as_mut() else {
                WATCHER_STARTED.store(false, Ordering::SeqCst);
                break;
            };

            match child.try_wait() {
                Ok(Some(status)) => {
                    log_message(format!("Core process exited: {}", status));
                    *process = None;
                    drop(process);
                    log_message("Dev helper service exiting after core exit".to_string());
                    std::process::exit(0);
                }
                Ok(None) => {}
                Err(e) => {
                    log_message(format!("Failed to monitor core process: {}", e));
                    *process = None;
                    drop(process);
                    std::process::exit(1);
                }
            }
        });
    }

    fn should_exit_service_when_core_exits() -> bool {
        env_contains_dev("HELPER_SERVICE_NAME")
            || env_contains_dev("HELPER_PIPE_NAME")
            || current_exe_name_contains_dev()
    }

    fn env_contains_dev(name: &str) -> bool {
        std::env::var(name)
            .map(|value| value.contains("Dev"))
            .unwrap_or(false)
    }

    fn current_exe_name_contains_dev() -> bool {
        std::env::current_exe()
            .ok()
            .and_then(|path| {
                path.file_stem()
                    .map(|stem| stem.to_string_lossy().to_string())
            })
            .map(|name| name.contains("Dev"))
            .unwrap_or(false)
    }

    /// Directories a core image may be started from.
    ///
    /// `HELPER_ALLOWED_CORE_DIR` wins when set (semicolon separated, so an
    /// install can list more than one). It is written into the service's
    /// `Environment` value at install time, which only an administrator can
    /// change — the same trust level as the service's `ImagePath`.
    ///
    /// When it is absent the default is **the directory the helper itself runs
    /// from**. The helper is only ever installed into the protected directory
    /// (SEC-P0-01), so "beside the helper" and "inside the protected directory"
    /// are the same thing, and no install-time configuration is required for the
    /// rule to hold.
    fn allowed_core_dirs() -> Vec<PathBuf> {
        if let Ok(raw) = std::env::var("HELPER_ALLOWED_CORE_DIR") {
            let dirs: Vec<PathBuf> = raw
                .split(';')
                .map(|s| s.trim())
                .filter(|s| !s.is_empty())
                .map(PathBuf::from)
                .collect();
            if !dirs.is_empty() {
                return dirs;
            }
        }

        std::env::current_exe()
            .ok()
            .and_then(|p| p.parent().map(|d| d.to_path_buf()))
            .into_iter()
            .collect()
    }

    fn same_path(a: &Path, b: &Path) -> bool {
        let (a, b) = (a.to_string_lossy(), b.to_string_lossy());
        if cfg!(windows) {
            a.eq_ignore_ascii_case(&b)
        } else {
            a == b
        }
    }

    /// SEC-P0-01 — the core image must live in a protected directory.
    ///
    /// Absolute and free of `..` was never enough: any user-writable folder
    /// satisfied it, which is exactly where an attacker can put a file whose
    /// hash they cannot forge but whose *path* they control. The check is now:
    ///
    /// 1. absolute, no `..`;
    /// 2. not a symlink / reparse point (nor is its parent);
    /// 3. after resolving both sides, the parent directory **is** one of
    ///    [`allowed_core_dirs`].
    ///
    /// Step 3 is what closes the privilege boundary: a standard user cannot
    /// write into `%ProgramFiles%\Fluxora\Service`, so the hash→spawn race is no
    /// longer something they can trigger at all.
    fn validate_core_path(path: &str) -> Result<PathBuf, String> {
        let raw = Path::new(path);
        if !raw.is_absolute() {
            return Err("core path must be absolute".to_string());
        }
        if raw
            .components()
            .any(|c| matches!(c, std::path::Component::ParentDir))
        {
            return Err("core path must not contain '..'".to_string());
        }

        for candidate in [Some(raw), raw.parent()].into_iter().flatten() {
            match std::fs::symlink_metadata(candidate) {
                Ok(meta) if meta.file_type().is_symlink() => {
                    return Err(format!(
                        "core path must not be a link or reparse point: {}",
                        candidate.display()
                    ));
                }
                Ok(_) => {}
                Err(e) => {
                    return Err(format!(
                        "core path is not accessible: {} ({})",
                        candidate.display(),
                        e
                    ));
                }
            }
        }

        let resolved = std::fs::canonicalize(raw)
            .map_err(|e| format!("core path cannot be resolved: {} ({})", raw.display(), e))?;
        let parent = resolved
            .parent()
            .ok_or_else(|| "core path has no parent directory".to_string())?;

        let mut permitted = false;
        for dir in allowed_core_dirs() {
            if let Ok(dir_resolved) = std::fs::canonicalize(&dir) {
                if same_path(parent, &dir_resolved) {
                    permitted = true;
                    break;
                }
            }
        }

        if !permitted {
            return Err(format!(
                "core path is outside the protected directory: {}",
                parent.display()
            ));
        }

        Ok(resolved)
    }

    pub fn stop_core() -> String {
        let mut process = PROCESS.lock().unwrap_or_else(|e| e.into_inner());
        if let Some(mut child) = process.take() {
            let _ = child.kill();
            let _ = child.wait();
        }
        *process = None;
        "".to_string()
    }

    /// Opens the image for reading while denying every writer.
    ///
    /// `FILE_SHARE_READ` alone means a second open that asks for `WRITE` or
    /// `DELETE` access fails, so the file cannot be replaced or renamed for as
    /// long as this handle lives. Rust's default is to share everything, which
    /// is what made the old hash→spawn window exploitable.
    #[cfg(windows)]
    fn open_core_readonly(path: &Path) -> std::io::Result<File> {
        use std::os::windows::fs::OpenOptionsExt;
        const FILE_SHARE_READ: u32 = 0x0000_0001;
        OpenOptions::new()
            .read(true)
            .share_mode(FILE_SHARE_READ)
            .open(path)
    }

    #[cfg(not(windows))]
    fn open_core_readonly(path: &Path) -> std::io::Result<File> {
        OpenOptions::new().read(true).open(path)
    }

    /// Hashes the file **through the handle that was just validated**.
    ///
    /// The previous version cached `(path, size, mtime) -> hash`. That is a
    /// bypass in its own right: an attacker who can write the file can keep its
    /// size and restore its timestamp, and the cache then hands back the hash of
    /// the file that used to be there. A core start is rare enough that
    /// re-reading it costs nothing worth that risk.
    fn sha256_handle(file: &File) -> std::io::Result<String> {
        let mut hasher = Sha256::new();
        let mut buffer = [0; HASH_BUFFER_SIZE];
        let mut reader = BufReader::new(file);

        loop {
            let bytes_read = reader.read(&mut buffer)?;
            if bytes_read == 0 {
                break;
            }
            hasher.update(&buffer[..bytes_read]);
        }

        Ok(format!("{:x}", hasher.finalize()))
    }

    #[cfg(test)]
    mod tests {
        use super::*;
        use std::fs;

        /// `HELPER_ALLOWED_CORE_DIR` is process-global, so the cases that touch
        /// it run one at a time.
        static ENV_LOCK: Mutex<()> = Mutex::new(());

        struct TempDir(PathBuf);

        impl TempDir {
            fn new(tag: &str) -> Self {
                let base = std::env::temp_dir()
                    .join(format!("fluxora_core_path_{}_{}", tag, std::process::id()));
                let _ = fs::remove_dir_all(&base);
                fs::create_dir_all(&base).expect("create temp dir");
                TempDir(base)
            }

            fn file(&self, name: &str) -> PathBuf {
                let path = self.0.join(name);
                fs::write(&path, b"not-a-real-core").expect("write temp file");
                path
            }
        }

        impl Drop for TempDir {
            fn drop(&mut self) {
                let _ = fs::remove_dir_all(&self.0);
            }
        }

        fn as_str(path: &Path) -> &str {
            path.to_str().expect("temp paths are valid UTF-8")
        }

        #[test]
        fn lexical_rules_still_apply() {
            // Relative paths never resolved to a directory before and must not
            // start doing so now.
            assert!(validate_core_path("FluxoraCore.exe").is_err());

            let traversal = if cfg!(windows) {
                r"C:\a\..\b\FluxoraCore.exe"
            } else {
                "/a/../b/FluxoraCore.exe"
            };
            let err = validate_core_path(traversal).expect_err("'..' must be refused");
            assert!(err.contains(".."), "unexpected message: {}", err);
        }

        #[test]
        fn a_core_outside_the_allowed_directory_is_refused() {
            let _guard = ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());

            let allowed = TempDir::new("allowed");
            let other = TempDir::new("other");
            std::env::set_var("HELPER_ALLOWED_CORE_DIR", &allowed.0);

            assert!(
                validate_core_path(as_str(&allowed.file("FluxoraCore.exe"))).is_ok(),
                "a core beside the helper must be accepted"
            );

            let err = validate_core_path(as_str(&other.file("FluxoraCore.exe")))
                .expect_err("a user-writable directory must be refused");
            assert!(
                err.contains("outside the protected directory"),
                "unexpected message: {}",
                err
            );

            std::env::remove_var("HELPER_ALLOWED_CORE_DIR");
        }

        #[test]
        fn a_sibling_sharing_a_name_prefix_is_not_accepted() {
            let _guard = ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());

            let base = TempDir::new("prefix");
            let allowed = base.0.join("Service");
            let sibling = base.0.join("Service-evil");
            fs::create_dir_all(&allowed).expect("mkdir allowed");
            fs::create_dir_all(&sibling).expect("mkdir sibling");
            fs::write(allowed.join("FluxoraCore.exe"), b"x").expect("write allowed");
            fs::write(sibling.join("FluxoraCore.exe"), b"x").expect("write sibling");

            std::env::set_var("HELPER_ALLOWED_CORE_DIR", &allowed);

            assert!(validate_core_path(as_str(&allowed.join("FluxoraCore.exe"))).is_ok());
            assert!(
                validate_core_path(as_str(&sibling.join("FluxoraCore.exe"))).is_err(),
                "'Service-evil' must not pass a prefix comparison"
            );

            std::env::remove_var("HELPER_ALLOWED_CORE_DIR");
        }

        #[test]
        fn without_configuration_the_helpers_own_directory_is_the_default() {
            let _guard = ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
            std::env::remove_var("HELPER_ALLOWED_CORE_DIR");

            let exe = std::env::current_exe().expect("current_exe");
            let dir = exe.parent().expect("test binary has a parent");
            let probe = dir.join(format!("fluxora_default_probe_{}.tmp", std::process::id()));
            fs::write(&probe, b"x").expect("write probe beside the helper");

            assert!(
                validate_core_path(as_str(&probe)).is_ok(),
                "no HELPER_ALLOWED_CORE_DIR must fall back to the helper's directory"
            );

            let _ = fs::remove_file(&probe);
        }

        #[test]
        fn a_missing_core_is_refused() {
            let _guard = ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());

            let allowed = TempDir::new("missing");
            std::env::set_var("HELPER_ALLOWED_CORE_DIR", &allowed.0);

            let absent = allowed.0.join("FluxoraCore.exe");
            let err = validate_core_path(as_str(&absent)).expect_err("must not resolve");
            assert!(err.contains("not accessible"), "unexpected message: {}", err);

            std::env::remove_var("HELPER_ALLOWED_CORE_DIR");
        }
    }
}

pub mod logs {
    use once_cell::sync::Lazy;
    use std::collections::VecDeque;
    use std::sync::{Arc, Mutex};

    const MAX_LOG_ENTRIES: usize = 100;

    static LOGS: Lazy<Arc<Mutex<VecDeque<String>>>> =
        Lazy::new(|| Arc::new(Mutex::new(VecDeque::with_capacity(MAX_LOG_ENTRIES))));

    pub fn log_message(message: String) {
        let mut log_buffer = LOGS.lock().unwrap_or_else(|e| e.into_inner());
        if log_buffer.len() == MAX_LOG_ENTRIES {
            log_buffer.pop_front();
        }
        log_buffer.push_back(message);
    }

    pub fn logs() -> Vec<String> {
        LOGS.lock()
            .unwrap_or_else(|e| e.into_inner())
            .iter()
            .cloned()
            .collect()
    }
}

pub mod process {
    use serde::{Deserialize, Serialize};

    #[derive(Debug, Deserialize, Serialize, Clone)]
    pub struct PriorityParams {
        pub process_name: String,
        pub enable: bool,
    }

    pub fn set_process_priority(process_name: &str, enable: bool) -> String {
        use windows::Win32::Foundation::CloseHandle;
        use windows::Win32::System::Diagnostics::ToolHelp::{
            CreateToolhelp32Snapshot, Process32FirstW, Process32NextW, PROCESSENTRY32W,
            TH32CS_SNAPPROCESS,
        };
        use windows::Win32::System::Threading::{
            OpenProcess, ProcessMemoryPriority, SetPriorityClass, SetProcessInformation,
            ABOVE_NORMAL_PRIORITY_CLASS, MEMORY_PRIORITY_INFORMATION, MEMORY_PRIORITY_NORMAL,
            NORMAL_PRIORITY_CLASS, PROCESS_SET_INFORMATION,
        };

        let priority_class = if enable {
            ABOVE_NORMAL_PRIORITY_CLASS
        } else {
            NORMAL_PRIORITY_CLASS
        };

        unsafe {
            let snapshot = match CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0) {
                Ok(s) => s,
                Err(e) => return format!("Failed to create snapshot: {}", e),
            };

            let mut entry = PROCESSENTRY32W {
                dwSize: std::mem::size_of::<PROCESSENTRY32W>() as u32,
                ..Default::default()
            };

            let mut found = false;

            if Process32FirstW(snapshot, &mut entry).is_ok() {
                loop {
                    let exe_name = String::from_utf16_lossy(&entry.szExeFile);
                    let exe_name = exe_name.trim_end_matches('\0');

                    if exe_name.eq_ignore_ascii_case(process_name) {
                        let process_handle = match OpenProcess(
                            PROCESS_SET_INFORMATION,
                            false,
                            entry.th32ProcessID,
                        ) {
                            Ok(h) => h,
                            Err(e) => {
                                crate::ops::logs::log_message(format!(
                                    "Failed to open process {}: {}",
                                    entry.th32ProcessID, e
                                ));
                                if Process32NextW(snapshot, &mut entry).is_err() {
                                    break;
                                }
                                continue;
                            }
                        };

                        match SetPriorityClass(process_handle, priority_class) {
                            Ok(_) => {
                                found = true;
                                crate::ops::logs::log_message(format!(
                                    "Set priority for {} (PID: {}) to {}",
                                    process_name,
                                    entry.th32ProcessID,
                                    if enable { "above normal" } else { "normal" }
                                ));
                            }
                            Err(e) => {
                                crate::ops::logs::log_message(format!(
                                    "Failed to set priority for {}: {}",
                                    process_name, e
                                ));
                            }
                        }

                        if enable {
                            let memory_priority = MEMORY_PRIORITY_INFORMATION {
                                MemoryPriority: MEMORY_PRIORITY_NORMAL,
                            };
                            if let Err(e) = SetProcessInformation(
                                process_handle,
                                ProcessMemoryPriority,
                                &memory_priority as *const MEMORY_PRIORITY_INFORMATION as _,
                                std::mem::size_of::<MEMORY_PRIORITY_INFORMATION>() as u32,
                            ) {
                                crate::ops::logs::log_message(format!(
                                    "Failed to set memory priority for {}: {}",
                                    process_name, e
                                ));
                            } else {
                                crate::ops::logs::log_message(format!(
                                    "Set memory priority for {} (PID: {}) to normal",
                                    process_name, entry.th32ProcessID
                                ));
                            }
                        }

                        let _ = CloseHandle(process_handle);
                    }

                    if Process32NextW(snapshot, &mut entry).is_err() {
                        break;
                    }
                }
            }

            let _ = CloseHandle(snapshot);

            if found {
                "".to_string()
            } else {
                format!("Process {} not found", process_name)
            }
        }
    }
}
