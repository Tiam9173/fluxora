use crate::service::hub::{run_service, signal_stop};

use std::ffi::OsString;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;

use once_cell::sync::OnceCell;
use tokio::runtime::Runtime;

use windows_service::{
    define_windows_service,
    service::{
        ServiceControl, ServiceControlAccept, ServiceExitCode, ServiceState, ServiceStatus,
        ServiceType,
    },
    service_control_handler::{self, ServiceControlHandlerResult, ServiceStatusHandle},
    service_dispatcher, Result,
};

const DEFAULT_SERVICE_NAME: &str = "FluxoraHelperService";

const SERVICE_TYPE: ServiceType = ServiceType::OWN_PROCESS;

/// Guard to make the Stop handler idempotent: the first Stop event sets
/// StopPending and signals the main loop; subsequent Stop events (e.g. SCM
/// sending Stop twice, or IPC stop arriving after SCM stop) are silently
/// acknowledged without repeating cleanup or racing the shutdown.
static STOP_REQUESTED: AtomicBool = AtomicBool::new(false);

/// Shared status handle — populated right after `register` returns, read by
/// the Stop handler closure. `ServiceStatusHandle` is `Copy + Send + Sync`,
/// so `OnceCell` gives us safe zero-allocation sharing.
static STATUS_HANDLE: OnceCell<ServiceStatusHandle> = OnceCell::new();

fn service_name() -> String {
    std::env::var("HELPER_SERVICE_NAME").unwrap_or_else(|_| {
        std::env::current_exe()
            .ok()
            .and_then(|path| {
                path.file_stem()
                    .map(|stem| stem.to_string_lossy().to_string())
            })
            .filter(|stem| stem.contains("Dev"))
            .unwrap_or_else(|| DEFAULT_SERVICE_NAME.to_string())
    })
}

pub fn main() -> Result<()> {
    start_service()
}

pub fn start_service() -> Result<()> {
    service_dispatcher::start(service_name(), service_entry)
}

define_windows_service!(service_entry, service_main);

pub fn service_main(_arguments: Vec<OsString>) {
    if let Ok(rt) = Runtime::new() {
        rt.block_on(async {
            if let Err(e) = run_windows_service().await {
                let log_name = if service_name().contains("Dev") {
                    "fluxora_dev_helper_error.log"
                } else {
                    "fluxora_helper_error.log"
                };
                let log_path = std::env::temp_dir().join(log_name);
                let ts = std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .map(|d| d.as_secs())
                    .unwrap_or(0);
                let msg = format!("[{}] service error: {}\n", ts, e);
                let _ = std::fs::OpenOptions::new()
                    .create(true)
                    .append(true)
                    .open(log_path)
                    .map(|mut f| {
                        use std::io::Write;
                        let _ = f.write_all(msg.as_bytes());
                    });
            }
        });
    }
}

async fn run_windows_service() -> anyhow::Result<()> {
    let service_name = service_name();

    // Register the control handler. The Stop handler sets StopPending on the
    // SCM, then signals the main loop via `signal_stop()` — it does NOT call
    // `process::exit(0)`. This lets `run_service()` return normally so the
    // `ServiceState::Stopped` report below (after the await) becomes reachable.
    let status_handle = service_control_handler::register(
        service_name,
        move |event| -> ServiceControlHandlerResult {
            match event {
                ServiceControl::Interrogate => ServiceControlHandlerResult::NoError,
                ServiceControl::Stop => {
                    // Idempotent: only the first Stop event does work.
                    if !STOP_REQUESTED.swap(true, Ordering::SeqCst) {
                        // Tell SCM we're stopping; this gives us time to
                        // clean up before reporting Stopped.
                        if let Some(handle) = STATUS_HANDLE.get() {
                            let _ = handle.set_service_status(ServiceStatus {
                                service_type: SERVICE_TYPE,
                                current_state: ServiceState::StopPending,
                                controls_accepted: ServiceControlAccept::empty(),
                                exit_code: ServiceExitCode::Win32(0),
                                checkpoint: 1,
                                wait_hint: Duration::from_secs(10),
                                process_id: None,
                            });
                        }

                        // Notify the main loop to shut down gracefully.
                        signal_stop();
                    }
                    ServiceControlHandlerResult::NoError
                }
                _ => ServiceControlHandlerResult::NotImplemented,
            }
        },
    )?;

    // Store the handle so the Stop handler closure can read it. Safe because
    // register() has returned before any Stop event can arrive, and
    // set() fails only if already set (which it isn't here).
    let _ = STATUS_HANDLE.set(status_handle);

    // Re-read the stored handle for our own use in this function.
    let status_handle = STATUS_HANDLE.get().expect("STATUS_HANDLE was just set");

    status_handle.set_service_status(ServiceStatus {
        service_type: SERVICE_TYPE,
        current_state: ServiceState::StartPending,
        controls_accepted: ServiceControlAccept::empty(),
        exit_code: ServiceExitCode::Win32(0),
        checkpoint: 0,
        wait_hint: Duration::from_secs(5),
        process_id: None,
    })?;

    status_handle.set_service_status(ServiceStatus {
        service_type: SERVICE_TYPE,
        current_state: ServiceState::Running,
        controls_accepted: ServiceControlAccept::STOP,
        exit_code: ServiceExitCode::Win32(0),
        checkpoint: 0,
        wait_hint: Duration::default(),
        process_id: None,
    })?;

    let result = run_service().await;

    let exit_code = if result.is_ok() {
        ServiceExitCode::Win32(0)
    } else {
        ServiceExitCode::ServiceSpecific(1)
    };
    let _ = status_handle.set_service_status(ServiceStatus {
        service_type: SERVICE_TYPE,
        current_state: ServiceState::Stopped,
        controls_accepted: ServiceControlAccept::empty(),
        exit_code,
        checkpoint: 0,
        wait_hint: Duration::default(),
        process_id: None,
    });

    result
}

// ── Test helpers ─────────────────────────────────────────────────────────────
// Reset global state between tests. In production, the process exits after
// Stopped is reported, so these are only needed for repeated test calls.

#[cfg(test)]
pub(crate) fn reset_stop_requested() {
    STOP_REQUESTED.store(false, Ordering::SeqCst);
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Test: STOP_REQUESTED swap returns true only once.
    ///
    /// This verifies that the Stop handler's `if !STOP_REQUESTED.swap(true, …)`
    /// guard correctly deduplicates: the first Stop event proceeds, all
    /// subsequent ones are silently acknowledged.
    #[test]
    fn stop_requested_swap_is_one_shot() {
        reset_stop_requested();

        // First swap: returns false (was not set), so `!false` = true → work proceeds.
        let first = STOP_REQUESTED.swap(true, Ordering::SeqCst);
        assert!(!first, "first swap should return false (was unset)");

        // Second swap: returns true (was set), so `!true` = false → work skipped.
        let second = STOP_REQUESTED.swap(true, Ordering::SeqCst);
        assert!(second, "second swap should return true (was set)");

        // Third swap: still true.
        let third = STOP_REQUESTED.swap(true, Ordering::SeqCst);
        assert!(third, "third swap should still return true");

        reset_stop_requested();
    }

    /// Test: after reset, STOP_REQUESTED is false again.
    ///
    /// This confirms the test helper works, so tests can be re-run.
    #[test]
    fn reset_clears_stop_requested() {
        STOP_REQUESTED.store(true, Ordering::SeqCst);
        assert!(STOP_REQUESTED.load(Ordering::SeqCst));

        reset_stop_requested();
        assert!(!STOP_REQUESTED.load(Ordering::SeqCst));
    }
}
