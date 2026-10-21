import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/providers/chain_proxy.dart';
import 'package:fluxora/views/proxies/chain_support_confirm_dialog.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:fluxora/enum/enum.dart';

class ChainSupportPanel extends ConsumerStatefulWidget {
  const ChainSupportPanel({super.key});

  @override
  ConsumerState<ChainSupportPanel> createState() => _ChainSupportPanelState();
}

class _ChainSupportPanelState extends ConsumerState<ChainSupportPanel> {
  bool _isGenerating = false;

  void _createPackage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const ChainSupportConfirmDialog(),
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() {
        _isGenerating = true;
      });

      try {
        await chainProxyManager.createSupportPackage();
      } finally {
        if (mounted) {
          setState(() {
            _isGenerating = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final package = ref.watch(chainSupportPackageProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return CommonCard(
      type: CommonCardType.filled,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.support_agent_outlined,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                // item 4 — unwrapped this card title overflowed by 32 px at
                // 280 dp under the 1.4x text scale.
                Flexible(
                  child: Text(
                    appLocalizations.chainSupportTitle,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (package != null) ...[
              Text(
                appLocalizations.chainPackageReady,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${appLocalizations.chainGeneratedOn} '
                '${package.createdAt.toIso8601String().split('T').first}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {}, // Simulated open folder
                      child: Text(appLocalizations.chainOpenFolder),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {}, // Simulated share
                      child: Text(appLocalizations.chainShareLabel),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                appLocalizations.chainDiagnosticPackage,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.archive_outlined, size: 18),
                  label: Text(
                    _isGenerating
                        ? appLocalizations.chainCreatingPackage
                        : appLocalizations.chainCreateSupportPackage,
                  ),
                  onPressed: _isGenerating ? null : _createPackage,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
