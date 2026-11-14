import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/app.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/common/tokens/fluxora_motion.dart';
import 'package:flutter/cupertino.dart';

class BaseNavigator {
  static Future<T?> push<T>(
    BuildContext context,
    Widget child, {
    bool maintainState = true,
  }) async {
    if (globalState.appState.viewMode != ViewMode.mobile) {
      return await Navigator.of(context).push<T>(
        CommonDesktopRoute(
          builder: (context) => child,
          maintainState: maintainState,
        ),
      );
    }
    return await Navigator.of(context).push<T>(
      _CleanCupertinoPageRoute(
        builder: (context) => child,
        maintainState: maintainState,
      ),
    );
  }
}

class _CleanCupertinoPageRoute<T> extends CupertinoPageRoute<T> {
  _CleanCupertinoPageRoute({
    required super.builder,
    super.title,
    super.settings,
    super.fullscreenDialog,
    super.maintainState,
    this.reduceMotion = false,
  }) : super(allowSnapshotting: false);

  final bool reduceMotion;
  FluxoraMotionSet get _motion => reduceMotion
      ? FluxoraMotionSet.reduced
      : navigator == null
      ? FluxoraMotionSet.full
      : FluxoraMotion.ofContext(navigator!.context);
  @override
  Duration get transitionDuration => _motion.base;
  @override
  Duration get reverseTransitionDuration => _motion.fast;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => null;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) => false;

  @override
  bool didPop(T? result) {
    controller?.reverseDuration = _motion.fast;
    return super.didPop(result);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final reduced =
        reduceMotion || FluxoraMotion.ofContext(context).reduceMotion;
    return super.buildTransitions(
      context,
      reduced ? kAlwaysCompleteAnimation : animation,
      kAlwaysDismissedAnimation,
      child,
    );
  }

  @override
  Color? get barrierColor => null;
}

class CommonDesktopRoute<T> extends PageRoute<T> {
  final Widget Function(BuildContext context) builder;

  CommonDesktopRoute({
    required this.builder,
    this.maintainState = true,
    this.reduceMotion = false,
  });

  final bool reduceMotion;
  FluxoraMotionSet get _motion => reduceMotion
      ? FluxoraMotionSet.reduced
      : navigator == null
      ? FluxoraMotionSet.full
      : FluxoraMotion.ofContext(navigator!.context);

  @override
  final bool maintainState;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final Widget result = builder(context);
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: FadeTransition(
        opacity: reduceMotion || FluxoraMotion.ofContext(context).reduceMotion
            ? kAlwaysCompleteAnimation
            : animation.drive(CurveTween(curve: FluxoraMotion.enter)),
        child: result,
      ),
    );
  }

  @override
  Duration get transitionDuration =>
      _motion.expressive ? _motion.base : _motion.fast;

  @override
  Duration get reverseTransitionDuration =>
      _motion.expressive ? _motion.fast : Duration.zero;

  @override
  bool didPop(T? result) {
    controller?.reverseDuration = reverseTransitionDuration;
    return super.didPop(result);
  }
}
