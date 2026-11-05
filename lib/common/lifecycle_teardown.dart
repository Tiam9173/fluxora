import 'package:fluxora/common/print.dart';

/// One cleanup action in the shared exit / restart chain.
///
/// Steps are **independent by design**: [runTeardown] runs every one of them
/// even when an earlier one throws. That is the fix for P9B-D1 — the exit chain
/// used to be a single `try` block, so a throw in `savePreferences()` skipped
/// the system-proxy release entirely and left the OS pointing at a dead port.
class TeardownStep {
  const TeardownStep(this.name, this.run, {this.keepOnRestart = false});

  /// Used in logs and in [TeardownResult.failures]; keep it short and stable.
  final String name;

  final Future<void> Function() run;

  /// Skip this step during a **controlled restart hand-off**.
  ///
  /// N6: `--restart` used to run the whole exit chain, so the `helper-stop`
  /// step stopped the helper service and the successor could not start it
  /// again — a standard user's `sc start` is refused (error 5). The restarted
  /// instance then fell back to spawning the core itself.
  ///
  /// A normal exit still runs this step. The flag says "keep this resource
  /// alive for the successor", not "never stop it".
  final bool keepOnRestart;
}

/// What the chain produced. Never thrown — the caller decides what to do with
/// a non-clean result, and must not report success on one.
class TeardownResult {
  TeardownResult(this.failures);

  /// `"<step name>: <error>"`, in the order the failures happened.
  final List<String> failures;

  bool get clean => failures.isEmpty;

  @override
  String toString() =>
      clean ? 'clean' : 'failed(${failures.length}): ${failures.join('; ')}';
}

/// Runs [steps] in order, collecting failures instead of aborting.
///
/// When [restart] is true, steps marked [TeardownStep.keepOnRestart] are
/// skipped entirely — their body never runs, so a failing stop cannot hide
/// behind the skip either.
Future<TeardownResult> runTeardown(
  List<TeardownStep> steps, {
  bool restart = false,
}) async {
  final failures = <String>[];
  for (final step in steps) {
    if (restart && step.keepOnRestart) {
      commonPrint.log('Teardown step "${step.name}" kept for the restart hand-off');
      continue;
    }
    try {
      await step.run();
    } catch (e) {
      failures.add('${step.name}: $e');
      commonPrint.log('Teardown step "${step.name}" failed: $e');
    }
  }
  return TeardownResult(failures);
}

/// The shared exit / restart chain.
///
/// P9B-D3: `--restart` used to call `Restart.restartApp()` straight from the
/// control channel, so the core, the helper service and the system proxy were
/// never torn down — the old process just vanished. Both paths now run the same
/// steps, in the same order, before either tail executes.
class LifecycleTeardown {
  LifecycleTeardown({
    required this.steps,
    required this.onExit,
    required this.onRestart,
  });

  /// Built lazily so the step list reflects the state at teardown time.
  final List<TeardownStep> Function() steps;

  /// Final action for a normal exit (`system.exit()`).
  final Future<void> Function() onExit;

  /// Final action for a restart (`Restart.restartApp()`).
  final Future<void> Function() onRestart;

  Future<TeardownResult>? _inFlight;

  /// Runs the chain exactly once, then hands over to [onExit] or [onRestart].
  ///
  /// A second call — a tray double-click, an `--exit` arriving while the first
  /// teardown is still running — returns the same future instead of tearing
  /// down twice.
  Future<TeardownResult> run({required bool restart}) {
    return _inFlight ??= _run(restart: restart);
  }

  Future<TeardownResult> _run({required bool restart}) async {
    final result = await runTeardown(steps(), restart: restart);
    // Both tails run even when steps failed. A process that skipped its exit
    // because one cleanup failed is worse than one that exits and logs the
    // failure list — and a restart that never happens would strand the user.
    if (restart) {
      await onRestart();
    } else {
      await onExit();
    }
    return result;
  }
}
