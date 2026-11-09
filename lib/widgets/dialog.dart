import 'dart:math';

import 'package:fluxora/providers/app.dart';
import 'package:fluxora/widgets/pop_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fluxora/state.dart';
import '../common/tokens/tokens.dart';
import 'glass_surface.dart';
import 'text.dart';

class GlassAlertDialog extends AlertDialog {
  const GlassAlertDialog({
    super.key,
    super.title,
    super.content,
    super.actions,
    super.contentPadding,
    super.backgroundColor,
    super.scrollable,
  });

  @override
  Widget build(BuildContext context) {
    final dialog = super.build(context);
    // Reuse the SDK's title, focus, scrolling and action layout.
    if (!FluxoraMaterial.of(context).liquid ||
        backgroundColor != null ||
        dialog is! Dialog ||
        dialog.child == null) {
      return dialog;
    }
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: FluxoraElevation.menu,
      insetPadding: dialog.insetPadding,
      insetAnimationDuration: FluxoraMotion.ofContext(context).fast,
      alignment: dialog.alignment,
      constraints: dialog.constraints,
      semanticsRole: dialog.semanticsRole,
      shape: const RoundedRectangleBorder(
        borderRadius: FluxoraRadius.dialogAll,
      ),
      child: GlassSurface(
        radius: FluxoraRadius.dialog,
        floating: true,
        blur: true,
        readable: true,
        child: Material(type: MaterialType.transparency, child: dialog.child),
      ),
    );
  }
}

class CommonDialog extends ConsumerWidget {
  final String title;
  final Widget? titleTrailing;
  final Widget? child;
  final List<Widget>? actions;
  final EdgeInsets? padding;
  final bool overrideScroll;
  final Color? backgroundColor;
  final double maxWidth;

  const CommonDialog({
    super.key,
    required this.title,
    this.titleTrailing,
    this.actions,
    this.child,
    this.padding,
    this.overrideScroll = false,
    this.backgroundColor,
    this.maxWidth = 300,
  });

  @override
  Widget build(BuildContext context, ref) {
    final size = ref.watch(viewSizeProvider);
    final isTv = globalState.isAndroidTV;
    return PopScope(
      canPop: !isTv,
      onPopInvokedWithResult: !isTv
          ? null
          : (didPop, result) {
              if (didPop) return;
              if (dismissTvInputFocus()) return;
              if (ModalRoute.of(context)?.isCurrent != true) return;
              Navigator.of(context).pop();
            },
      child: GlassAlertDialog(
        title: titleTrailing == null
            ? EmojiText(title)
            : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: EmojiText(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  titleTrailing!,
                ],
              ),
        actions: actions,
        contentPadding: padding,
        backgroundColor: backgroundColor,
        content: Container(
          constraints: BoxConstraints(
            maxHeight: min(size.height - 40, 500),
            maxWidth: maxWidth,
          ),
          width: size.width - 40,
          child: !overrideScroll ? SingleChildScrollView(child: child) : child,
        ),
      ),
    );
  }
}
