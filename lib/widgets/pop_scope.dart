import 'dart:async';

import 'package:bett_box/state.dart';
import 'package:flutter/material.dart';

bool dismissTvInputFocus() {
  if (!globalState.isAndroidTV) return false;
  final node = FocusManager.instance.primaryFocus;
  if (node == null) return false;
  final context = node.context;
  if (context == null) return false;
  final isInput =
      context.widget is EditableText ||
      context.findAncestorWidgetOfExactType<EditableText>() != null ||
      context.widget is Slider ||
      context.findAncestorWidgetOfExactType<Slider>() != null;
  if (!isInput) return false;
  node.enclosingScope?.requestScopeFocus();
  return true;
}

class CommonPopScope extends StatelessWidget {
  final Widget child;
  final FutureOr<bool> Function()? onPop;

  const CommonPopScope({super.key, required this.child, this.onPop});

  @override
  Widget build(BuildContext context) {
    final isTv = globalState.isAndroidTV;
    final intercept = onPop != null || isTv;
    return PopScope(
      canPop: !intercept,
      onPopInvokedWithResult: !intercept
          ? null
          : (didPop, _) async {
              if (didPop) return;
              if (dismissTvInputFocus()) return;

              if (onPop != null) {
                final res = await onPop!();
                if (!context.mounted) return;
                if (!res) return;
              }

              if (ModalRoute.of(context)?.isCurrent != true) return;
              Navigator.of(context).pop();
            },
      child: child,
    );
  }
}

class SystemBackBlock extends StatefulWidget {
  final Widget child;

  const SystemBackBlock({super.key, required this.child});

  @override
  State<SystemBackBlock> createState() => _SystemBackBlockState();
}

class _SystemBackBlockState extends State<SystemBackBlock> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      globalState.appController.backBlock();
    });
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      globalState.appController.unBackBlock();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
