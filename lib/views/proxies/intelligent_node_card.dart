import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/chain_proxy_node_view_model.dart';
import 'package:fluxora/models/protocol_capability.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/widgets/fluxora/fluxora_proxy_tile.dart';
import 'package:fluxora/widgets/fluxora/fluxora_status.dart';
import 'package:fluxora/widgets/fluxora/fluxora_latency_badge.dart';
import 'package:fluxora/l10n/chain_proxy_l10n.dart';
import 'package:fluxora/providers/providers.dart';

class IntelligentNodeCard extends ConsumerWidget {
  final ChainProxyNodeViewModel viewModel;
  final String groupName;
  final VoidCallback? onTap;
  final bool? forceSelected;
  final bool isDisabled;

  const IntelligentNodeCard({
    super.key,
    required this.viewModel,
    required this.groupName,
    this.onTap,
    this.forceSelected,
    this.isDisabled = false,
  });

  FluxoraStatusKind _mapHealthToStatus(ChainHealthStatus health) {
    switch (health) {
      case ChainHealthStatus.healthy:
        return FluxoraStatusKind.connected;
      case ChainHealthStatus.degraded:
        return FluxoraStatusKind.warning;
      case ChainHealthStatus.failed:
        return FluxoraStatusKind.error;
      case ChainHealthStatus.checking:
        return FluxoraStatusKind.connecting;
      case ChainHealthStatus.unknown:
      default:
        return FluxoraStatusKind.unknown;
    }
  }

  String _getHealthLabel(ChainHealthStatus health) {
    try {
      switch (health) {
        case ChainHealthStatus.healthy:
          return appLocalizations.healthHealthy;
        case ChainHealthStatus.degraded:
          return appLocalizations.healthWarning;
        case ChainHealthStatus.failed:
          return appLocalizations.healthError;
        case ChainHealthStatus.checking:
          return appLocalizations.testingHealth;
        case ChainHealthStatus.unknown:
        default:
          return appLocalizations.healthUntested;
      }
    } catch (_) {
      switch (health) {
        case ChainHealthStatus.healthy:
          return 'Healthy';
        case ChainHealthStatus.degraded:
          return 'Degraded';
        case ChainHealthStatus.failed:
          return 'Error';
        case ChainHealthStatus.checking:
          return 'Checking';
        default:
          return 'Untested';
      }
    }
  }

  String _getCapabilityLabel(CapabilityEvidenceType cap) {
    switch (cap) {
      case CapabilityEvidenceType.runtimeVerified:
      case CapabilityEvidenceType.userConfirmed:
      case CapabilityEvidenceType.configDeclared:
        return 'Compatible';
      case CapabilityEvidenceType.runtimeRejected:
        return 'Incompatible';
      default:
        return 'Unknown';
    }
  }

  Color _getCapabilityColor(CapabilityEvidenceType cap, ColorScheme colors) {
    switch (cap) {
      case CapabilityEvidenceType.runtimeVerified:
      case CapabilityEvidenceType.userConfirmed:
      case CapabilityEvidenceType.configDeclared:
        return colors.primary;
      case CapabilityEvidenceType.runtimeRejected:
        return colors.error;
      default:
        return colors.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    // We do NOT read selectedMap directly to compute Lock.
    // The ViewModel already provides `isLocked`.
    final bool isLocked = viewModel.isLocked;

    final bool isSelected = forceSelected ?? ref.watch(
      getSelectedProxyNameProvider(groupName).select((name) => name == viewModel.nodeName)
    );

    final status = isSelected 
        ? FluxoraStatusKind.connected 
        : _mapHealthToStatus(viewModel.health);

    final List<Widget> badges = [];

    // 1. Adaptive Score
    if (viewModel.score != null) {
      badges.add(_MiniBadge(
        icon: Icons.auto_awesome,
        text: 'Score: ${viewModel.score!.totalScore.toStringAsFixed(0)}',
        color: colorScheme.onTertiaryContainer,
        backgroundColor: colorScheme.tertiaryContainer,
      ));
    } else {
      badges.add(_MiniBadge(
        text: 'Score: --',
        color: colorScheme.onSurfaceVariant,
      ));
    }

    // 2. Health
    final healthLabel = _getHealthLabel(viewModel.health);
    badges.add(_MiniBadge(
      icon: Icons.favorite_outline,
      text: healthLabel,
      color: status == FluxoraStatusKind.connected || status == FluxoraStatusKind.warning ? colorScheme.onTertiaryContainer : colorScheme.onSurfaceVariant,
      backgroundColor: status == FluxoraStatusKind.connected || status == FluxoraStatusKind.warning ? colorScheme.tertiaryContainer : colorScheme.surfaceContainerHighest,
    ));

    // 3. Reliability
    if (viewModel.score != null && viewModel.score!.reliabilityScore > 0) {
      badges.add(_MiniBadge(
        icon: Icons.shield_outlined,
        text: '${viewModel.score!.reliabilityScore.toInt()}%',
        color: colorScheme.onSecondaryContainer,
        backgroundColor: colorScheme.secondaryContainer,
      ));
    }

    // 4. Capability
    final capLabel = _getCapabilityLabel(viewModel.capabilityEvidence);
    final capColor = _getCapabilityColor(viewModel.capabilityEvidence, colorScheme);
    badges.add(_MiniBadge(
      icon: capLabel == 'Compatible' ? Icons.check_circle_outline : (capLabel == 'Incompatible' ? Icons.block : Icons.help_outline),
      text: capLabel,
      color: capColor,
      backgroundColor: capColor.withValues(alpha: 0.1),
    ));

    // 5. Failover Candidate
    if (viewModel.isFailoverCandidate) {
      badges.add(_MiniBadge(
        icon: Icons.health_and_safety_outlined,
        text: 'Backup',
        color: colorScheme.onPrimaryContainer,
        backgroundColor: colorScheme.primaryContainer,
      ));
    }

    // 6. Exploration
    if (viewModel.isExploration) {
      badges.add(_MiniBadge(
        icon: Icons.explore_outlined,
        text: 'Exploring',
        color: colorScheme.onSurfaceVariant,
        backgroundColor: colorScheme.surfaceContainerHighest,
      ));
    }

    final descriptionWidget = Wrap(
      spacing: 6,
      runSpacing: 4,
      children: badges,
    );

    Widget? trailingWidget;
    if (isLocked) {
      trailingWidget = Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.secondaryContainer,
        ),
        child: Icon(
          Icons.lock_outline,
          size: 18,
          color: colorScheme.onSecondaryContainer,
          semanticLabel: 'Locked',
        ),
      );
    }

    Widget? latencySlot;
    if (viewModel.latencyMs != null) {
      latencySlot = FluxoraLatencyBadge(
        delay: viewModel.latencyMs!,
        dense: true,
      );
    } else {
      latencySlot = SizedBox(
        height: 12.0,
        child: Text(
          '--',
          style: FluxoraTypography.label.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    Widget tile = FluxoraProxyTile(
      name: viewModel.nodeName,
      protocol: viewModel.proxy.type,
      status: status,
      selected: isSelected,
      onTap: onTap,
      description: descriptionWidget,
      trailing: trailingWidget,
      latencySlot: latencySlot,
      padding: const EdgeInsets.symmetric(horizontal: FluxoraSpacing.md, vertical: FluxoraSpacing.md),
      compact: false,
    );

    if (isDisabled) {
      tile = IgnorePointer(
        child: Opacity(
          opacity: 0.5,
          child: tile,
        ),
      );
    }

    return tile;
  }
}

class _MiniBadge extends StatelessWidget {
  final IconData? icon;
  final String text;
  final Color? color;
  final Color? backgroundColor;

  const _MiniBadge({
    this.icon,
    required this.text,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 2),
          ],
          Text(
            text,
            style: TextStyle(fontSize: 10, color: color, height: 1.1),
          ),
        ],
      ),
    );
  }
}
