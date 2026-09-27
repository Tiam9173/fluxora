import 'package:fluxora/common/common.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluxora/views/profiles/add_profile.dart';

/// How the connection Hero should be presented for the current core state.
///
/// Pure presentation data — derived from the same providers the previous
/// implementation read, with no new data source and no new logic.
typedef _HeroPresentation = ({
  FluxoraFlowState flow,
  FluxoraStatusKind kind,
  String label,
  String value,
});

/// The Dashboard connection Hero (D4.6).
///
/// Was a half-width card whose header carried the state and whose body was a
/// single line of text. It is now the full-width (8-column) anchor of the
/// Dashboard: a [FluxoraCard] holding the brand's [FluxoraFlowIndicator] plus a
/// semantic [FluxoraStatus] and the mono uptime read-out.
///
/// **D4.6 regression fix.** The redesign dropped the card's `Info` header and
/// replaced the body's play/pause glyph with a decorative `Icon` — no
/// `onPressed`, no press feedback, no cursor change. The card was still the
/// control (its whole surface is a tap target), but nothing said so. The header
/// is back (`Icons.power_settings_new` + `powerSwitch`) and the trailing glyph
/// is now an `IconButton.filledTonal`. The D4.6 body — flow indicator, status,
/// uptime — is untouched.
///
/// **Behaviour is unchanged**: the same `startButtonSelectorStateProvider` /
/// `runTimeProvider` / `isRestartingCoreProvider` / `isSmartStoppedProvider`
/// drive it, tapping still calls `updateStatus`, long-press still offers a core
/// restart, and a missing profile still opens the add-profile sheet.
class StartButton extends ConsumerStatefulWidget {
  const StartButton({super.key});

  @override
  ConsumerState<StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends ConsumerState<StartButton> {
  bool _isDisabled = false;
  bool? _optimisticStart;

  void _handleStart() async {
    if (_isDisabled) return;
    final isStart = ref.read(runTimeProvider) != null;
    final newState = !isStart;
    setState(() {
      _isDisabled = true;
      _optimisticStart = newState;
    });

    try {
      await globalState.appController.updateStatus(newState);
    } catch (e) {
      commonPrint.log('updateStatus failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDisabled = false;
          _optimisticStart = null;
        });
      }
    }
  }

  Future<void> _handleLongPress() async {
    final isStart = ref.read(runTimeProvider) != null;
    if (!isStart) return;

    final result = await globalState.showCommonDialog<bool>(
      child: CommonDialog(
        title: appLocalizations.restartCoreTitle,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop(false);
            },
            child: Text(appLocalizations.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop(true);
            },
            child: Text(appLocalizations.confirm),
          ),
        ],
        child: Text(appLocalizations.restartCoreDesc),
      ),
    );

    if (result == true) {
      await globalState.appController.restartCore();
      globalState.showNotifier(appLocalizations.success);
    }
  }

  void _handleShowAddProfile() {
    showExtend(
      context,
      builder: (_, type) {
        return AdaptiveSheetScaffold(
          type: type,
          body: AddProfileView(context: context),
          title: appLocalizations.add,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(startButtonSelectorStateProvider);
    final isSmartStopped = ref.watch(isSmartStoppedProvider);
    final canPress =
        state.isInit && state.hasProfile && !_isDisabled && !isSmartStopped;
    final hasNoProfile =
        state.isInit && !state.hasProfile && !_isDisabled && !isSmartStopped;
    final isRestarting = ref.watch(isRestartingCoreProvider);

    return ValueListenableBuilder<int>(
      valueListenable: dashboardRefreshManager.tick1s,
      builder: (_, _, _) {
        final runTime = ref.read(runTimeProvider);
        final isStart = runTime != null;
        final displayStart =
            isSmartStopped ? false : (_optimisticStart ?? isStart);
        // Busy covers the initial read plus the brief optimistic toggle window.
        final busy = !state.isInit || _isDisabled || isRestarting;

        final hero = _resolveHero(
          isInit: state.isInit,
          hasProfile: state.hasProfile,
          isRestarting: isRestarting,
          isSmartStopped: isSmartStopped,
          started: displayStart,
          runTime: runTime,
        );

        // The header names the *control*; `hero.label` names the *state*.
        // `_resolveHero` reuses `powerSwitch` as its idle state label, which is
        // the same string the header now shows — in that one case the read-out
        // is promoted into the status slot so the card never prints it twice.
        final isIdleState = hero.label == appLocalizations.powerSwitch;
        final statusLabel = isIdleState ? hero.value : hero.label;
        final readOut = isIdleState ? '' : hero.value;

        return SizedBox(
          // Height budget (D4.6 header restore): card padding (md ×2) + power
          // header (`baseInfoEdgeInsets.top` + glyph line) + one body row, which
          // the 40×40 action button dominates. `getWidgetHeight(1)` alone (84)
          // is no longer enough once the header row is back.
          height: getWidgetHeight(1) + FluxoraSpacing.xxl,
          child: FluxoraCard(
            onTap: canPress
                ? _handleStart
                : hasNoProfile
                ? _handleShowAddProfile
                : null,
            onLongPress: canPress ? _handleLongPress : null,
            semanticLabel: hero.label,
            // Restores the power affordance D4.6 dropped: a power glyph plus a
            // control label in the card header, so the card reads as the
            // start/stop control instead of a status card that happens to hold a
            // play icon. Layout stays D4.6's — only the header comes back.
            info: Info(
              label: appLocalizations.powerSwitch,
              iconData: Icons.power_settings_new,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: FluxoraSpacing.lg,
              vertical: FluxoraSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FluxoraFlowIndicator(state: hero.flow, width: 56, height: 16),
                const SizedBox(width: FluxoraSpacing.lg),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FluxoraStatus(
                        status: hero.kind,
                        label: statusLabel,
                        semanticLabel: statusLabel,
                      ),
                      if (readOut.isNotEmpty) ...[
                        const SizedBox(height: FluxoraSpacing.xxs),
                        Text(
                          readOut,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FluxoraTypography.numericLabel.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: FluxoraSpacing.md),
                // A real Material 3 button, not a decorative glyph. D4.6 left a
                // bare `Icon` here (no `onPressed`), which removed the only
                // visible cue that the card starts/stops the service.
                //
                // Nested buttons do not double-fire: hit testing walks deepest
                // first, so the IconButton's tap recognizer enters the gesture
                // arena before the card's `OutlinedButton`, and the arena sweep
                // accepts the first member and rejects the rest. `_handleStart`'s
                // synchronous `_isDisabled` guard is the second line of defence.
                SizedBox(
                  width: 40,
                  height: 40,
                  child: busy
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton.filledTonal(
                          onPressed: canPress
                              ? _handleStart
                              : hasNoProfile
                              ? _handleShowAddProfile
                              : null,
                          tooltip: appLocalizations.powerSwitch,
                          icon: Icon(
                            displayStart
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                            size: 20,
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Maps the existing core state onto Fluxora flow / status / text.
  ///
  /// Labels reuse existing localisation keys only — no new strings, so no
  /// l10n regeneration was needed.
  _HeroPresentation _resolveHero({
    required bool isInit,
    required bool hasProfile,
    required bool isRestarting,
    required bool isSmartStopped,
    required bool started,
    required int? runTime,
  }) {
    if (!isInit) {
      return (
        flow: FluxoraFlowState.connecting,
        kind: FluxoraStatusKind.connecting,
        label: appLocalizations.serviceRunning,
        value: '',
      );
    }
    if (isRestarting) {
      return (
        flow: FluxoraFlowState.connecting,
        kind: FluxoraStatusKind.connecting,
        label: appLocalizations.restartCoreTitle,
        value: '',
      );
    }
    if (isSmartStopped) {
      return (
        flow: FluxoraFlowState.idle,
        kind: FluxoraStatusKind.disconnected,
        label: appLocalizations.coreSuspended,
        value: appLocalizations.serviceReady,
      );
    }
    if (!hasProfile) {
      return (
        flow: FluxoraFlowState.error,
        kind: FluxoraStatusKind.warning,
        label: appLocalizations.checkOrAddProfile,
        value: '',
      );
    }
    if (started) {
      return (
        flow: FluxoraFlowState.connected,
        kind: FluxoraStatusKind.connected,
        label: appLocalizations.coreConnected,
        value: _formatRunTime(runTime),
      );
    }
    return (
      flow: FluxoraFlowState.idle,
      kind: FluxoraStatusKind.disconnected,
      label: appLocalizations.powerSwitch,
      value: appLocalizations.serviceReady,
    );
  }

  String _formatRunTime(int? timeStamp) {
    if (timeStamp == null) return '00:00:00';

    final diff = timeStamp / 1000;
    int inHours = (diff / 3600).floor();
    int inMinutes = (diff / 60 % 60).floor();
    int inSeconds = (diff % 60).floor();

    // Limit maximum display to 999:59:59
    if (inHours > 999) {
      inHours = 999;
      inMinutes = 59;
      inSeconds = 59;
    }

    // If less than 100 hours, show 2 digits; otherwise 3
    final hourStr = inHours < 100
        ? inHours.toString().padLeft(2, '0')
        : inHours.toString().padLeft(3, '0');

    return '$hourStr:${inMinutes.toString().padLeft(2, '0')}:${inSeconds.toString().padLeft(2, '0')}';
  }
}
