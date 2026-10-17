import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/providers/config.dart';
import 'package:fluxora/widgets/widgets.dart';

/// Delay-animation preview.
///
/// Our own design: a live sample of the current choice at card size, then a
/// grid where every animation runs for real. Tapping a tile applies it on the
/// spot — the setting used to be a text-only option list, so the only way to
/// learn what "three bounce" looked like was to leave the page and trigger a
/// delay test.
void showDelayAnimationPreview(BuildContext context) {
  showSheet(
    context: context,
    builder: (_, type) => AdaptiveSheetScaffold(
      type: type,
      title: appLocalizations.delayAnimation,
      body: const _DelayAnimationPreviewBody(),
    ),
  );
}

class _DelayAnimationPreviewBody extends ConsumerWidget {
  const _DelayAnimationPreviewBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(
      proxiesStyleSettingProvider.select((state) => state.delayAnimation),
    );
    final colorScheme = context.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        // Live sample: the same shape a node card uses while testing, so the
        // choice is judged in context rather than as a bare spinner.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Center(
                  child: DelayAnimation(
                    type: selected,
                    size: 22,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      delayAnimationName(selected),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '365 ms',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          appLocalizations.delayAnimationDesc,
          style: TextStyle(
            fontSize: 11.5,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: DelayAnimationType.values.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 86,
          ),
          itemBuilder: (context, index) {
            final type = DelayAnimationType.values[index];
            return _AnimationTile(
              type: type,
              selected: type == selected,
              onTap: () {
                ref
                    .read(proxiesStyleSettingProvider.notifier)
                    .updateState(
                      (state) => state.copyWith(delayAnimation: type),
                    );
              },
            );
          },
        ),
      ],
    );
  }
}

class _AnimationTile extends StatelessWidget {
  const _AnimationTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final DelayAnimationType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Material(
      color: selected
          ? colorScheme.primary.withValues(alpha: 0.10)
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.4),
              width: selected ? 1.4 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 30,
                height: 30,
                child: Center(
                  child: DelayAnimation(
                    type: type,
                    size: 24,
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                delayAnimationName(type),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Localized name for one animation style. Kept next to the preview so the
/// settings list and the tiles can never disagree on what a style is called.
String delayAnimationName(DelayAnimationType type) {
  return switch (type) {
    DelayAnimationType.none => appLocalizations.noAnimation,
    DelayAnimationType.rotatingCircle => appLocalizations.rotatingCircle,
    DelayAnimationType.pulse => appLocalizations.pulse,
    DelayAnimationType.spinningLines => appLocalizations.spinningLines,
    DelayAnimationType.threeInOut => appLocalizations.threeInOut,
    DelayAnimationType.threeBounce => appLocalizations.threeBounce,
    DelayAnimationType.circle => appLocalizations.circle,
    DelayAnimationType.fadingCircle => appLocalizations.fadingCircle,
    DelayAnimationType.fadingFour => appLocalizations.fadingFour,
    DelayAnimationType.wave => appLocalizations.wave,
    DelayAnimationType.doubleBounce => appLocalizations.doubleBounce,
  };
}
