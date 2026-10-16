import 'package:fluxora/manager/message_manager.dart';
import 'package:fluxora/widgets/scaffold.dart';
import 'package:flutter/material.dart';

extension BuildContextExtension on BuildContext {
  /// Run [callback] once the current route's transition has finished.
  ///
  /// Starting hardware-dependent work (camera, sensors) straight from a
  /// post-frame callback races the route push animation: the page is still
  /// animating in, and on desktop the surface the preview is supposed to attach
  /// to is not ready, so the start silently fails. Bailing out immediately when
  /// there is no `ModalRoute` or the animation is already done keeps this a
  /// no-op for non-route contexts.
  void afterRouteTransition(VoidCallback callback) {
    final animation = ModalRoute.of(this)?.animation;
    if (animation == null || animation.isCompleted) {
      callback();
      return;
    }
    void listener(AnimationStatus status) {
      if (!status.isCompleted) return;
      animation.removeStatusListener(listener);
      callback();
    }

    animation.addStatusListener(listener);
  }

  CommonScaffoldState? get commonScaffoldState {
    return findAncestorStateOfType<CommonScaffoldState>();
  }

  Future<void>? showNotifier(String text,
      {VoidCallback? onAction, String? actionLabel, bool showCountdown = false}) {
    return findAncestorStateOfType<MessageManagerState>()
        ?.message(text, onAction: onAction, actionLabel: actionLabel, showCountdown: showCountdown);
  }

  void showSnackBar(String message, {SnackBarAction? action}) {
    final width = viewWidth;
    EdgeInsets margin;
    if (width < 600) {
      margin = const EdgeInsets.only(bottom: 16, right: 16, left: 16);
    } else {
      margin = EdgeInsets.only(bottom: 16, left: 16, right: width - 316);
    }
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        action: action,
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1500),
        margin: margin,
      ),
    );
  }

  Size get appSize {
    return MediaQuery.of(this).size;
  }

  double get viewWidth {
    return appSize.width;
  }

  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  TextTheme get textTheme => Theme.of(this).textTheme;

  T? findLastStateOfType<T extends State>() {
    T? state;

    visitor(Element element) {
      if (!element.mounted) {
        return;
      }
      if (element is StatefulElement) {
        if (element.state is T) {
          state = element.state as T;
        }
      }
      element.visitChildren(visitor);
    }

    visitor(this as Element);
    return state;
  }
}

class BackHandleInherited extends InheritedWidget {
  final Function handleBack;

  const BackHandleInherited({
    super.key,
    required this.handleBack,
    required super.child,
  });

  static BackHandleInherited? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BackHandleInherited>();

  @override
  bool updateShouldNotify(BackHandleInherited oldWidget) {
    return handleBack != oldWidget.handleBack;
  }
}
