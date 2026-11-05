use crate::ipc;
use once_cell::sync::Lazy;
use std::time::Duration;
use tokio::sync::Notify;

const DEFAULT_PIPE_NAME: &str = r"\\.\pipe\Fluxora.Helper";

/// Upper bound on Core cleanup. `stop_core()` does `kill()` + `wait()`, which
/// is normally instant but could block if the child is wedged.
const CORE_CLEANUP_TIMEOUT: Duration = Duration::from_secs(5);

/// Process-wide stop signal. Both the SCM Stop handler (windows.rs) and the
/// IPC `helper.stop_service` handler (rpc.rs) call `signal_stop()` to notify
/// the main service loop, which then performs cleanup and returns normally —
/// allowing `ServiceState::Stopped` to be reported.
///
/// Using `Notify` (not `oneshot`) means repeated stop signals are idempotent:
/// multiple `notify_one()` calls only wake the first `notified()` await; the
/// service loop exits once regardless of how many stop requests arrive.
static STOP_SIGNAL: Lazy<Notify> = Lazy::new(Notify::new);

/// Signal the service main loop to shut down.
///
/// Safe to call from any thread (SCM handler thread, IPC tokio task, etc.)
/// and safe to call multiple times — the first call wakes the loop; later
/// calls are no-ops.
pub fn signal_stop() {
    STOP_SIGNAL.notify_one();
}

fn pipe_name() -> String {
    std::env::var("HELPER_PIPE_NAME").unwrap_or_else(|_| DEFAULT_PIPE_NAME.to_string())
}

/// Run Core cleanup on a detached thread, waiting at most `CORE_CLEANUP_TIMEOUT`.
///
/// A plain detached thread — not `spawn_blocking` — is deliberate. `Runtime::drop`
/// shuts the blocking pool down with `shutdown(None)`, which waits on the pool
/// and joins its workers; a blocking task that never returns would therefore
/// hang the process no matter what `timeout` wrapped it. A detached thread is
/// never joined, so this bound is real: after the timeout we report Stopped and
/// process exit terminates the thread.
///
/// ponytail: on timeout the Core can briefly outlive the service. `stop_core()`
/// issues `kill()` before `wait()`, so by the 5s mark the Core is almost
/// certainly already terminated — only `wait()` can wedge.
fn cleanup_core_bounded() -> bool {
    let (tx, rx) = std::sync::mpsc::channel();
    std::thread::spawn(move || {
        let _ = tx.send(crate::ops::core::stop_core());
    });

    match rx.recv_timeout(CORE_CLEANUP_TIMEOUT) {
        Ok(message) if message.is_empty() => {
            crate::ops::logs::log_message("Core cleanup completed".to_string());
            true
        }
        Ok(message) => {
            crate::ops::logs::log_message(format!(
                "Core cleanup reported error during stop: {}",
                message
            ));
            false
        }
        Err(std::sync::mpsc::RecvTimeoutError::Timeout) => {
            crate::ops::logs::log_message(format!(
                "Core cleanup did not finish within {:?}; reporting Stopped anyway",
                CORE_CLEANUP_TIMEOUT
            ));
            false
        }
        Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => {
            crate::ops::logs::log_message(
                "Core cleanup thread ended without reporting a result".to_string(),
            );
            false
        }
    }
}

pub async fn run_service() -> anyhow::Result<()> {
    crate::rpc::init_auth_key();

    let pipe_name = pipe_name();

    // Race the IPC named-pipe loop against the stop signal. Whichever
    // finishes first wins:
    //  - If the pipe loop returns (fatal error), we propagate it.
    //  - If a stop signal fires (SCM Stop or IPC helper.stop_service),
    //    we perform Core cleanup and return Ok(()), allowing the caller
    //    (windows.rs) to report ServiceState::Stopped.
    tokio::select! {
        result = ipc::named_pipe::run(&pipe_name) => {
            result
        }
        _ = STOP_SIGNAL.notified() => {
            // Blocking for at most 5s on a worker thread is acceptable here:
            // this is the last thing the service does before returning.
            cleanup_core_bounded();

            // Always Ok: the service stopped as instructed. A cleanup
            // failure is logged above and surfaces in the helper log, not
            // as a service-specific exit code (which would make SCM treat
            // a clean stop as a crash).
            Ok(())
        }
    }
}

// NOTE: the old `hub::stop()` (which called `ops::core::stop_core()` directly
// and was paired with `std::process::exit(0)` at both call sites) has been
// removed. It bypassed the service main loop, so `ServiceState::Stopped` could
// never be reported (Windows error 7034). All stop paths now go through
// `signal_stop()` and let `run_service()` return normally.

// ── Tests ────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Arc;
    use std::time::Duration;

    // NOTE: `STOP_SIGNAL` is a process-wide static `Notify`. Tests below use
    // a *local* `Notify` to verify the signal mechanism in isolation, because
    // the static `Notify` cannot be reset between tests (there is no
    // `Notify::reset()`). The production code path is identical —
    // `signal_stop()` calls `STOP_SIGNAL.notify_one()`, which behaves exactly
    // the same as `local_notify.notify_one()`.

    /// Test 1: notify_one() wakes a pending notified() future.
    ///
    /// Verifies the fundamental mechanism used by `signal_stop()`: when the
    /// SCM Stop handler or IPC handler calls `notify_one()`, the `select!`
    /// branch in `run_service()` fires.
    #[tokio::test]
    async fn notify_wakes_pending_notified() {
        let notify = Arc::new(Notify::new());
        let notify_for_task = notify.clone();

        // Start awaiting before signaling.
        let task = tokio::spawn(async move {
            tokio::time::timeout(Duration::from_secs(1), notify_for_task.notified()).await
        });

        // Give the task time to register its interest.
        tokio::time::sleep(Duration::from_millis(10)).await;

        notify.notify_one();

        let result = task.await.expect("task should complete");
        assert!(result.is_ok(), "notified() should fire after notify_one()");
    }

    /// Test 2: notify_one() before any notified() is awaited stores a permit,
    /// so the next notified() returns immediately. This is the behavior that
    /// makes stop signals safe if they arrive before run_service() enters
    /// its select! — the stop is not lost.
    #[tokio::test]
    async fn notify_before_await_stores_permit() {
        let notify = Notify::new();

        // Signal before anyone is listening.
        notify.notify_one();

        // The next notified() should return immediately (permit was stored).
        let result = tokio::time::timeout(Duration::from_millis(50), notify.notified()).await;

        assert!(
            result.is_ok(),
            "notified() should fire immediately when a permit is stored"
        );
    }

    /// Test 3: repeated notify_one() calls do not produce multiple wake-ups.
    ///
    /// This covers the scenario where SCM sends Stop twice, or IPC stop
    /// arrives after SCM stop. `Notify` only stores one permit, so extra
    /// calls are no-ops.
    #[tokio::test]
    async fn repeated_notify_is_idempotent() {
        let notify = Notify::new();

        // Fire multiple signals in rapid succession before anyone listens.
        notify.notify_one();
        notify.notify_one();
        notify.notify_one();

        // First notified() consumes the single stored permit.
        let r1 = tokio::time::timeout(Duration::from_millis(50), notify.notified()).await;
        assert!(r1.is_ok(), "first notified() should fire (stored permit)");

        // Second notified() should time out — no extra permits.
        let r2 = tokio::time::timeout(Duration::from_millis(50), notify.notified()).await;
        assert!(
            r2.is_err(),
            "second notified() should NOT fire — extra notify_one() calls do not store additional permits"
        );
    }

    /// Test 4: notify_one() can be called from a non-async (synchronous)
    /// context, simulating the SCM Stop handler closure which runs on a
    /// Windows callback thread (not a tokio task).
    #[tokio::test]
    async fn notify_from_sync_thread() {
        let notify = Arc::new(Notify::new());
        let notify_clone = notify.clone();

        let (tx, rx) = std::sync::mpsc::channel();

        // Spawn a standard OS thread (like the SCM handler's thread context).
        std::thread::spawn(move || {
            notify_clone.notify_one();
            let _ = tx.send(());
        });

        // Wait for the thread to call notify_one().
        rx.recv().expect("thread should complete");

        let result = tokio::time::timeout(Duration::from_secs(1), notify.notified()).await;

        assert!(
            result.is_ok(),
            "notified() should fire when notify_one() is called from a sync thread"
        );
    }

    /// Test 5: signal_stop() does not panic when called multiple times.
    ///
    /// This directly tests the production `signal_stop()` function. It cannot
    /// verify wakeup state (the static Notify is shared across all tests),
    /// but it confirms the function is safe to call repeatedly — the core
    /// invariant for idempotent stop handling.
    #[test]
    fn signal_stop_does_not_panic_on_repeated_calls() {
        signal_stop();
        signal_stop();
        signal_stop();
        // If we reach here, no panic occurred.
    }

    /// Test 6: bounded cleanup completes and reports success when there is no
    /// Core child process to stop.
    ///
    /// `stop_core()` with no tracked process returns `""` immediately, which
    /// `cleanup_core_bounded()` maps to `true`.
    #[test]
    fn cleanup_core_bounded_succeeds_without_child() {
        let clean = cleanup_core_bounded();
        assert!(clean, "cleanup with no child process should report clean");
    }

    /// Test 7: repeated cleanup is idempotent — calling it twice does not
    /// hang, panic, or report failure.
    ///
    /// This is the "重复 STOP 不产生重复清理或状态竞争" requirement: the
    /// second cleanup finds no process and returns clean immediately.
    #[test]
    fn cleanup_core_bounded_is_idempotent() {
        let first = cleanup_core_bounded();
        let second = cleanup_core_bounded();

        assert!(first, "first cleanup should report clean");
        assert!(second, "second cleanup should also report clean");
    }

    /// Test 8: cleanup is bounded — it must return well before
    /// `CORE_CLEANUP_TIMEOUT`, so a wedged Core can never hang the service
    /// shutdown path.
    #[test]
    fn cleanup_core_bounded_finishes_quickly() {
        let started = std::time::Instant::now();
        let _ = cleanup_core_bounded();
        let elapsed = started.elapsed();

        assert!(
            elapsed < CORE_CLEANUP_TIMEOUT,
            "cleanup took {:?}, which is not bounded by {:?}",
            elapsed,
            CORE_CLEANUP_TIMEOUT
        );
    }

    /// Test 9: the cleanup bound does not depend on the tokio runtime.
    ///
    /// Regression guard for the previous implementation, which wrapped
    /// `spawn_blocking` in `tokio::time::timeout`. That timeout bounded only
    /// the await: `Runtime::drop` shuts the blocking pool down with
    /// `shutdown(None)` and joins its workers, so a wedged blocking task
    /// still hung the process. Running cleanup with no runtime present at all
    /// proves it is a plain detached thread, not a runtime-owned task.
    #[test]
    fn cleanup_core_bounded_runs_without_runtime() {
        assert!(
            cleanup_core_bounded(),
            "cleanup must work with no tokio runtime in scope"
        );
    }
}
