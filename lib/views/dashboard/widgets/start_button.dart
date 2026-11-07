import 'package:fluxora/common/common.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluxora/views/profiles/add_profile.dart';
import 'package:fluxora/views/proxies/notification_switch_card.dart';

/// How the connection Hero should be presented for the current core state.
///
/// Pure presentation data — derived from the same providers the previous
/// implementation read, with no new data source and no new logic.
typedef _HeroPresentation = ({
  FluxoraStatusKind kind,
  String label,
  String value,
});

/// A single token-driven entrance; reduced motion renders the final state.
class _HeroEntrance extends StatefulWidget {
  const _HeroEntrance({required this.child});

  final Widget child;

  @override
  State<_HeroEntrance> createState() => _HeroEntranceState();
}

class _HeroEntranceState extends State<_HeroEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  /// Runs the entrance exactly once, even if dependencies are rebuilt.
  bool _played = false;

  FluxoraMotionSet get _motion => FluxoraMotion.ofContext(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = _motion;
    _controller.duration = motion.base;
    if (motion.reduceMotion) {
      _played = true;
      _controller.value = 1;
    } else if (!_played) {
      _played = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = _motion;
    return AnimatedBuilder(
      animation: _controller,
      // `child` is threaded through so the Hero subtree is never rebuilt by the
      // entrance animation.
      child: widget.child,
      builder: (context, child) {
        final t = motion.reduceMotion ? 1.0 : _controller.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            // Starts 4 px low and lifts to its resting place.
            offset: Offset(0, motion.enterOffset.dy * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}

class StartButton extends ConsumerStatefulWidget {
  const StartButton({super.key});

  @override
  ConsumerState<StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends ConsumerState<StartButton> {
  /// Restarts the core without touching the profile or the selected node.
  ///
  /// The service stays up throughout, which is why the notification does not
  /// flicker: only the core behind it is replaced.
  Future<void> _handleRestartCore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appLocalizations.restartCore),
        content: Text(appLocalizations.restartCoreTip),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(appLocalizations.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(appLocalizations.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await globalState.appController.restartCore();
    } catch (e) {
      if (!mounted) return;
      // Success is already visible in the status row.
      context.showSnackBar('$e');
    }
  }

  bool _isDisabled = false;
  bool? _requestedStart;

  void _handleStart() async {
    if (_isDisabled) return;
    final isStart = ref.read(runTimeProvider) != null;
    final newState = !isStart;
    setState(() {
      _isDisabled = true;
      _requestedStart = newState;
    });

    try {
      await globalState.appController.updateStatus(newState);
    } catch (e) {
      commonPrint.log('updateStatus failed: $e');
      // The primary action used to fail silently: the optimistic toggle was
      // rolled back in `finally`, so the card simply snapped back with no
      // explanation. The sibling restart path already reports failures through
      // a snackbar, and this is the more important of the two — a user who
      // taps "connect" and sees nothing happen has no way to tell a failure
      // from a missed tap.
      if (mounted) context.showSnackBar('$e');
    } finally {
      if (mounted) {
        setState(() {
          _isDisabled = false;
          _requestedStart = null;
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
      // `showNotifier(success)` must only run after a successful restart; an
      // unhandled throw here would also leave the user with no feedback at all.
      try {
        await globalState.appController.restartCore();
        globalState.showNotifier(appLocalizations.success);
      } catch (e) {
        commonPrint.log('restartCore failed: $e');
        if (!mounted) return;
        context.showSnackBar('$e');
      }
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
    final runTime = ref.watch(runTimeProvider);
    final profile = ref.watch(currentProfileProvider);
    final selectedMap = ref.watch(selectedMapProvider);
    final selectedName =
        selectedMap[profile?.currentGroupName] ??
        profile?.label ??
        appLocalizations.profiles;
    final mode = ref.watch(patchClashConfigProvider.select((s) => s.mode));

    // item — the Hero's one-shot entrance. Wrapping the scroll content keeps the
    // 1 s tick listener untouched: `_HeroEntrance` passes its child through and
    // never rebuilds it, so per-second updates cost nothing extra.
    return _HeroEntrance(
      child: ValueListenableBuilder<int>(
        valueListenable: dashboardRefreshManager.tick1s,
        builder: (_, _, _) {
          final isStart = runTime != null;
          final displayStart = !isSmartStopped && isStart;
          // Busy means initialization or a real operation still awaiting completion.
          final busy = !state.isInit || _isDisabled || isRestarting;

          final hero = _isDisabled
              ? (
                  kind: FluxoraStatusKind.connecting,
                  label: _requestedStart == true
                      ? appLocalizations.startVpn
                      : appLocalizations.stopVpn,
                  value: '',
                )
              : _resolveHero(
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

          final scheme = context.colorScheme;
          final action = canPress
              ? _handleStart
              : hasNoProfile
              ? _handleShowAddProfile
              : null;
          final largeText =
              MediaQuery.textScalerOf(context).scale(16) > 22 &&
              MediaQuery.sizeOf(context).width < 600;
          final control = DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: scheme.primary.withValues(alpha: .3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: SizedBox(
                width: 56,
                height: 56,
                child: AnimatedSwitcher(
                  duration: FluxoraMotion.ofContext(context).fast,
                  child: busy
                      ? Padding(
                          key: const ValueKey('connection-pending'),
                          padding: EdgeInsets.all(16),
                          child: FluxoraMotion.ofContext(context).reduceMotion
                              ? const Icon(
                                  Icons.hourglass_top_rounded,
                                  size: 24,
                                )
                              : const CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton.filled(
                          key: ValueKey(displayStart),
                          onPressed: action,
                          tooltip: hasNoProfile
                              ? appLocalizations.checkOrAddProfile
                              : appLocalizations.powerSwitch,
                          style: IconButton.styleFrom(
                            fixedSize: const Size(56, 56),
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                          ),
                          icon: Icon(
                            hasNoProfile
                                ? Icons.add_rounded
                                : displayStart
                                ? Icons.pause_rounded
                                : Icons.power_settings_new_rounded,
                            size: 28,
                          ),
                        ),
                ),
              ),
            ),
          );
          return SizedBox(
            height: getWidgetHeight(largeText ? 2.4 : 2),
            child: FluxoraCard(
              filled: true,
              onTap: action,
              onLongPress: canPress ? _handleLongPress : null,
              semanticLabel: hero.label,
              padding: EdgeInsets.zero,
              child: AnimatedContainer(
                duration: FluxoraMotion.ofContext(context).base,
                curve: FluxoraMotion.standard,
                decoration: BoxDecoration(
                  borderRadius: FluxoraRadius.cardAll,
                  border: Border.all(
                    color: displayStart
                        ? FluxoraStatus.colorOf(
                            context,
                            FluxoraStatusKind.connected,
                          ).withValues(alpha: .4)
                        : Colors.transparent,
                  ),
                  color: scheme.surfaceContainerHigh,
                  gradient: FluxoraMaterial.of(context).blurEnabled
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.alphaBlend(
                              FluxoraColors.flowViolet.withValues(
                                alpha: scheme.brightness == Brightness.light
                                    ? .10
                                    : .22,
                              ),
                              scheme.surfaceContainer,
                            ),
                            Color.alphaBlend(
                              FluxoraColors.auroraBlue.withValues(alpha: .06),
                              scheme.surfaceContainer,
                            ),
                          ],
                        )
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(FluxoraSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      ExcludeSemantics(
                                        child: FluxoraStatus(
                                          status: hero.kind,
                                          showLabel: false,
                                        ),
                                      ),
                                      const SizedBox(width: FluxoraSpacing.sm),
                                      Flexible(
                                        child: Text(
                                          Localizations.localeOf(
                                                    context,
                                                  ).languageCode ==
                                                  'zh'
                                              ? '连接'
                                              : 'Connection',
                                          style: context.textTheme.labelMedium
                                              ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: FluxoraSpacing.sm),
                                  Text(
                                    statusLabel,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.textTheme.titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: scheme.onSurface,
                                        ),
                                  ),
                                  if (readOut.isNotEmpty) ...[
                                    const SizedBox(height: FluxoraSpacing.xs),
                                    Text(
                                      readOut,
                                      style: FluxoraTypography.numericLabel
                                          .copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (!largeText) ...[
                              const SizedBox(width: FluxoraSpacing.md),
                              control,
                            ],
                          ],
                        ),
                      ),
                      Divider(
                        color: scheme.onSurface.withValues(alpha: .1),
                        height: FluxoraSpacing.lg,
                      ),
                      Row(
                        children: [
                          ExcludeSemantics(
                            child: Icon(
                              Icons.route_outlined,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: FluxoraSpacing.sm),
                          Expanded(
                            child: InkWell(
                              key: const ValueKey('connection-node-picker'),
                              borderRadius: FluxoraRadius.smAll,
                              onTap: () => showNotificationSwitchCard(context),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: EmojiText(
                                        selectedName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.textTheme.bodyMedium
                                            ?.copyWith(color: scheme.onSurface),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.expand_more_rounded,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: FluxoraSpacing.sm),
                          Text(
                            Intl.message(mode.name),
                            style: context.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          if (largeText) ...[
                            const SizedBox(width: FluxoraSpacing.sm),
                            control,
                          ],
                          if (displayStart)
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: IconButton(
                                onPressed: busy ? null : _handleRestartCore,
                                tooltip: appLocalizations.restartCore,
                                icon: const Icon(Icons.restart_alt, size: 22),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
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
        kind: FluxoraStatusKind.connecting,
        label: appLocalizations.init,
        value: '',
      );
    }
    if (isRestarting) {
      return (
        kind: FluxoraStatusKind.connecting,
        label: appLocalizations.restartCoreTitle,
        value: '',
      );
    }
    if (isSmartStopped) {
      return (
        kind: FluxoraStatusKind.disconnected,
        label: appLocalizations.coreSuspended,
        value: appLocalizations.serviceReady,
      );
    }
    if (!hasProfile) {
      return (
        kind: FluxoraStatusKind.warning,
        label: appLocalizations.checkOrAddProfile,
        value: '',
      );
    }
    if (started) {
      return (
        kind: FluxoraStatusKind.connected,
        label: appLocalizations.coreConnected,
        value: _formatRunTime(runTime),
      );
    }
    return (
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
