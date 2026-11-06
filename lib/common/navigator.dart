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
          reduceMotion: FluxoraMotion.ofContext(context).reduceMotion,
        ),
      );
    }
    return await Navigator.of(context).push<T>(
      _CleanCupertinoPageRoute(
        builder: (context) => child,
        maintainState: maintainState,
        reduceMotion: FluxoraMotion.ofContext(context).reduceMotion,
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
  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : super.transitionDuration;
  @override
  Duration get reverseTransitionDuration =>
      reduceMotion ? Duration.zero : super.reverseTransitionDuration;

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
      child: reduceMotion || FluxoraMotion.ofContext(context).reduceMotion
          ? result
          : FadeTransition(
              opacity: animation.drive(CurveTween(curve: FluxoraMotion.enter)),
              child: result,
            ),
    );
  }

  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : FluxoraMotion.base;

  @override
  Duration get reverseTransitionDuration =>
      reduceMotion ? Duration.zero : FluxoraMotion.fast;
}
