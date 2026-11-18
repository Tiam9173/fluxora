import 'dart:math' show max;

import 'package:fluxora/common/common.dart';
import 'package:fluxora/widgets/fluxora/fluxora.dart';
import 'package:flutter/material.dart';

import 'add_profile.dart';

class ProfileImportEmptyState extends StatelessWidget {
  const ProfileImportEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 24);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: max(0.0, constraints.maxWidth - padding.horizontal),
            minHeight: max(0.0, constraints.maxHeight - padding.vertical),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: FluxoraEmptyState(
                title: appLocalizations.nullTip(appLocalizations.profiles),
                illustration: SizedBox(
                  width: 104,
                  height: 88,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.translate(
                        offset: const Offset(-10, -6),
                        child: Transform.rotate(
                          angle: -0.16,
                          child: Container(
                            width: 64,
                            height: 68,
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(7, 2),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.folder_open_rounded,
                            color: colors.onPrimaryContainer,
                            size: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                action: FilledButton.icon(
                  key: const ValueKey('import-first-profile'),
                  onPressed: () => showAddProfileSheet(context),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(appLocalizations.addProfile),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(148, 48),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
