import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

/// item 6 (Bettbox 1.19.4) — the animation shown while a delay test is running.
///
/// Extracted from the proxy card, where it used to be a private method. Other
/// pages need the same animation ([SyncedLoading]), and two copies of this
/// switch would drift apart the moment a new style is added.
class DelayAnimation extends StatelessWidget {
  final DelayAnimationType type;
  final double size;
  final Color color;

  const DelayAnimation({
    super.key,
    required this.type,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return switch (type) {
      DelayAnimationType.none => Icon(Icons.bolt, size: size),
      DelayAnimationType.rotatingCircle => SpinKitRotatingCircle(
        color: color,
        size: size,
      ),
      DelayAnimationType.pulse => SpinKitPulse(color: color, size: size),
      DelayAnimationType.spinningLines => SpinKitSpinningLines(
        color: color,
        size: size,
      ),
      DelayAnimationType.threeInOut => SpinKitThreeInOut(
        color: color,
        size: size,
      ),
      DelayAnimationType.threeBounce => SpinKitThreeBounce(
        color: color,
        size: size,
      ),
      DelayAnimationType.circle => SpinKitCircle(color: color, size: size),
      DelayAnimationType.fadingCircle => SpinKitFadingCircle(
        color: color,
        size: size,
      ),
      DelayAnimationType.fadingFour => SpinKitFadingFour(
        color: color,
        size: size,
      ),
      DelayAnimationType.wave => SpinKitWave(color: color, size: size),
      DelayAnimationType.doubleBounce => SpinKitDoubleBounce(
        color: color,
        size: size,
      ),
    };
  }
}

/// item 6 (Bettbox 1.19.4) — a loading indicator that follows the delay-test
/// animation setting, so the whole app looks consistent while testing.
///
/// Opt-out by design: with `syncDelayAnimation` off, or with the animation set
/// to `none`, this returns [child] untouched — which is exactly the plain
/// `CircularProgressIndicator` the caller passed in. That keeps the feature a
/// pure addition: nothing changes for anyone who leaves it off.
class SyncedLoading extends ConsumerWidget {
  final double size;
  final Color? color;
  final Widget child;

  const SyncedLoading({
    super.key,
    required this.size,
    required this.child,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (type, sync) = ref.watch(
      proxiesStyleSettingProvider.select(
        (state) => (state.delayAnimation, state.syncDelayAnimation),
      ),
    );
    if (!sync || type == DelayAnimationType.none) return child;
    return Center(
      child: SizedBox.square(
        dimension: size,
        child: FittedBox(
          child: DelayAnimation(
            type: type,
            size: size,
            color: color ?? context.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
