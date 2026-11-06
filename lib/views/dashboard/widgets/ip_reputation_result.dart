import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/ip_reputation.dart';
import 'package:fluxora/widgets/fluxora/fluxora_card.dart';
import 'package:flutter/material.dart';

/// Displays the source report without starting a lookup or deriving a verdict.
class IpReputationResult extends StatelessWidget {
  const IpReputationResult({
    super.key,
    required this.report,
    required this.fields,
    this.onOpenReport,
  });

  final IpReputation report;
  final Set<String> fields;
  final VoidCallback? onOpenReport;

  static String _markerLabel(String id) => switch (id) {
    'vpn' => appLocalizations.ipRiskVpn,
    'proxy' => appLocalizations.ipRiskProxy,
    'tor' => appLocalizations.ipRiskTor,
    'hosting' => appLocalizations.ipRiskHosting,
    'relay' => appLocalizations.ipRiskRelay,
    'mobile' => appLocalizations.ipRiskMobile,
    'bogon' => appLocalizations.ipRiskBogon,
    'searchEngineBot' => appLocalizations.ipRiskSearchEngineBot,
    _ => id,
  };

  static String _scenarioLabel(String id) => switch (id) {
    'ai' => appLocalizations.scenarioAi,
    'social' => appLocalizations.scenarioSocial,
    'streaming' => appLocalizations.scenarioStreaming,
    'gaming' => appLocalizations.scenarioGaming,
    'ecommerce' => appLocalizations.scenarioEcommerce,
    'email' => appLocalizations.scenarioEmail,
    _ => id,
  };

  static Color _scoreColor(BuildContext context, int? score) {
    if (score == null) return context.colorScheme.onSurfaceVariant;
    if (score < 40) return context.colorScheme.error;
    if (score < 75) {
      return FluxoraColorSet.of(Theme.of(context).brightness).warning;
    }
    return context.colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    if (!report.isOk) {
      return _ResultCard(
        title: appLocalizations.ipRiskFailed,
        icon: Icons.cloud_off_outlined,
        child: SelectableText(switch (report.failureReason) {
          IpReputationFailure.timeout => appLocalizations.timeoutLabel,
          IpReputationFailure.network =>
            appLocalizations.networkErrorRetryLater,
          _ => report.failureReason ?? appLocalizations.unknown,
        }, style: context.textTheme.bodyMedium),
      );
    }
    final risk = report.risk;
    final facts = <(String, String)>[
      if (fields.contains(IpReputationFieldIds.asn) &&
          (report.asn != null || report.asnOrg != null))
        ('ASN', [report.asn, report.asnOrg].whereType<String>().join(' · ')),
      if (fields.contains(IpReputationFieldIds.usageType) &&
          report.usageType != null)
        (appLocalizations.ipRiskHosting, report.usageType!),
      if (fields.contains(IpReputationFieldIds.nativeType) &&
          report.nativeType != null)
        (appLocalizations.ipRiskNativeType, report.nativeType!),
      if (fields.contains(IpReputationFieldIds.abuse) &&
          report.abuseScore != null)
        (
          appLocalizations.ipRiskAbuse,
          '${report.abuseScore}${report.abuseReports == null ? '' : ' (${report.abuseReports})'}',
        ),
      if (fields.contains(IpReputationFieldIds.blocklists) &&
          report.blocklistsHit.isNotEmpty)
        (appLocalizations.ipRiskBlocklists, report.blocklistsHit.join(' · ')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: FluxoraSpacing.md,
      children: [
        if (fields.contains(IpReputationFieldIds.score) &&
            risk != null &&
            risk.hasScore)
          _ResultCard(
            title: appLocalizations.ipRiskScore,
            icon: Icons.shield_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: FluxoraSpacing.lg,
                  runSpacing: FluxoraSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: '${risk.purity}',
                        style: context.textTheme.displayMedium?.copyWith(
                          color: _scoreColor(context, risk.purity),
                          fontWeight: FontWeight.w600,
                        ),
                        children: [
                          TextSpan(
                            text: ' / 100',
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (risk.label != null)
                      Text(risk.label!, style: context.textTheme.titleMedium),
                  ],
                ),
                if (risk.verdict != null)
                  Padding(
                    padding: const EdgeInsets.only(top: FluxoraSpacing.sm),
                    child: Text(
                      risk.verdict!,
                      style: context.textTheme.bodyMedium,
                    ),
                  ),
                if (risk.factors.isNotEmpty) ...[
                  const Divider(height: FluxoraSpacing.xl),
                  Text(
                    appLocalizations.ipRiskFactors,
                    style: context.textTheme.labelLarge,
                  ),
                  const SizedBox(height: FluxoraSpacing.sm),
                  for (final factor in risk.factors)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: FluxoraSpacing.xs,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              factor.label,
                              style: context.textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: FluxoraSpacing.md),
                          Text(
                            factor.points < 0
                                ? '+${-factor.points}'
                                : '-${factor.points}',
                            style: context.textTheme.labelLarge?.copyWith(
                              color: factor.points < 0
                                  ? context.colorScheme.primary
                                  : context.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        if (fields.contains(IpReputationFieldIds.scenarios) &&
            report.scenarios.isNotEmpty)
          _ResultCard(
            title: appLocalizations.ipRiskScenarios,
            icon: Icons.apps_rounded,
            child: _ResultGrid(
              children: [
                for (final scenario in report.scenarios)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _scenarioLabel(scenario.id),
                              style: context.textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: FluxoraSpacing.sm),
                          Text(
                            scenario.score?.toString() ?? '—',
                            style: context.textTheme.titleMedium?.copyWith(
                              color: _scoreColor(context, scenario.score),
                            ),
                          ),
                        ],
                      ),
                      if (scenario.levelLabel != null || scenario.score == null)
                        Text(
                          scenario.levelLabel ?? appLocalizations.unknown,
                          style: context.textTheme.bodySmall,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        if (fields.contains(IpReputationFieldIds.markers) &&
            report.markers.isNotEmpty)
          _ResultCard(
            title: appLocalizations.fieldMarkers,
            icon: Icons.fact_check_outlined,
            child: _ResultGrid(
              children: [
                for (final marker in report.markers)
                  _MarkerTile(marker: marker),
              ],
            ),
          ),
        if (facts.isNotEmpty)
          _ResultCard(
            child: Column(
              spacing: FluxoraSpacing.md,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (label, value) in facts)
                  _ResultFact(label: label, value: value),
              ],
            ),
          ),
        // Source limitations remain visible even when optional fields are hidden.
        if (report.unknownNotes.isNotEmpty)
          _ResultCard(
            title: appLocalizations.ipRiskLimits,
            icon: Icons.info_outline_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: FluxoraSpacing.sm,
              children: [
                for (final note in report.unknownNotes)
                  Text(note, style: context.textTheme.bodyMedium),
              ],
            ),
          ),
        _ResultCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: FluxoraSpacing.sm,
            children: [
              _ResultFact(
                label: appLocalizations.source,
                value: report.source ?? appLocalizations.unknown,
              ),
              if (report.queriedAt case final time?)
                _ResultFact(
                  label: appLocalizations.time,
                  value: _formatTime(time),
                ),
              if (report.stale)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 18,
                      color: context.colorScheme.error,
                    ),
                    const SizedBox(width: FluxoraSpacing.sm),
                    Expanded(
                      child: Text(
                        appLocalizations.ipRiskStale,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              if (onOpenReport != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: onOpenReport,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(appLocalizations.ipRiskOpenReport),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatTime(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({this.title, this.icon, required this.child});
  final String? title;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => FluxoraCard(
    filled: true,
    padding: const EdgeInsets.all(FluxoraSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: context.colorScheme.primary),
                const SizedBox(width: FluxoraSpacing.sm),
              ],
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title!, style: context.textTheme.titleSmall),
                ),
              ),
            ],
          ),
          const SizedBox(height: FluxoraSpacing.md),
        ],
        child,
      ],
    ),
  );
}

class _ResultGrid extends StatelessWidget {
  const _ResultGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final columns =
          constraints.maxWidth >= 260 &&
              MediaQuery.textScalerOf(context).scale(14) <= 18
          ? 2
          : 1;
      return Wrap(
        spacing: FluxoraSpacing.lg,
        runSpacing: FluxoraSpacing.lg,
        children: [
          for (final child in children)
            SizedBox(
              width:
                  (constraints.maxWidth - FluxoraSpacing.lg * (columns - 1)) /
                  columns,
              child: child,
            ),
        ],
      );
    },
  );
}

class _MarkerTile extends StatelessWidget {
  const _MarkerTile({required this.marker});
  final IpRiskMarker marker;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (marker.state) {
      IpRiskMarkerState.flagged => (
        Icons.error_outline_rounded,
        appLocalizations.flagged,
      ),
      IpRiskMarkerState.clear => (
        Icons.check_circle_outline_rounded,
        appLocalizations.ipRiskNotFlagged,
      ),
      IpRiskMarkerState.unknown => (
        Icons.help_outline_rounded,
        appLocalizations.unknown,
      ),
    };
    final color = marker.state == IpRiskMarkerState.flagged
        ? context.colorScheme.error
        : context.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: FluxoraSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                IpReputationResult._markerLabel(marker.id),
                style: context.textTheme.bodyMedium,
              ),
              Text(
                label,
                style: context.textTheme.bodySmall?.copyWith(color: color),
              ),
              if (marker.detail != null)
                Text(marker.detail!, style: context.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultFact extends StatelessWidget {
  const _ResultFact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: context.textTheme.labelMedium?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: FluxoraSpacing.xs),
      SelectableText(value, style: context.textTheme.bodyMedium),
    ],
  );
}
