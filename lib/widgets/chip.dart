import 'dart:ui' show PointerDeviceKind;

import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:flutter/material.dart';

import 'text.dart';

class CategoryFilterBar extends StatelessWidget {
  const CategoryFilterBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final behavior = ScrollConfiguration.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScrollConfiguration(
          behavior: behavior.copyWith(
            dragDevices: {...behavior.dragDevices, PointerDeviceKind.mouse},
            scrollbars: false,
          ),
          child: SingleChildScrollView(
            primary: false,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(spacing: 8, children: children),
          ),
        ),
        Divider(
          height: 1,
          color: context.colorScheme.outlineVariant.withValues(alpha: .45),
        ),
      ],
    );
  }
}

class CategoryFilterChip extends StatelessWidget {
  const CategoryFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      shape: const StadiumBorder(),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      side: WidgetStateBorderSide.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: colors.primary, width: 2);
        }
        return selected
            ? BorderSide.none
            : BorderSide(color: colors.outlineVariant);
      }),
      backgroundColor: colors.surfaceContainerLow,
      selectedColor: colors.secondaryContainer,
      labelStyle: context.textTheme.labelLarge?.copyWith(
        color: selected ? colors.onSecondaryContainer : colors.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class CommonChip extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ChipType type;
  final Widget? avatar;
  final TextStyle? labelStyle;

  const CommonChip({
    super.key,
    required this.label,
    this.labelStyle,
    this.onPressed,
    this.avatar,
    this.type = ChipType.action,
  });

  @override
  Widget build(BuildContext context) {
    final focusedBorder = WidgetStateBorderSide.resolveWith((states) {
      if (states.contains(WidgetState.focused)) {
        return BorderSide(color: context.colorScheme.primary, width: 2);
      }
      return null;
    });
    final focusedColor = WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.focused)) {
        return context.colorScheme.primary.withValues(alpha: 0.2);
      }
      return null;
    });

    if (type == ChipType.delete) {
      return Chip(
        avatar: avatar,
        side: focusedBorder,
        color: focusedColor,
        labelPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 4),
        clipBehavior: Clip.antiAlias,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onDeleted: onPressed ?? () {},
        labelStyle: labelStyle,
        label: EmojiText(label),
      );
    }
    return ActionChip(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: avatar,
      side: focusedBorder,
      color: focusedColor,
      clipBehavior: Clip.antiAlias,
      labelPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 4),
      onPressed: onPressed ?? () {},
      labelStyle: labelStyle,
      label: EmojiText(label),
    );
  }
}
