import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/services/services.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'ip_reputation_result.dart';

class NetworkDetection extends ConsumerStatefulWidget {
  const NetworkDetection({super.key});

  @override
  ConsumerState<NetworkDetection> createState() => _NetworkDetectionState();
}

class _NetworkDetectionState extends ConsumerState<NetworkDetection> {
  String _countryCodeToEmoji(String countryCode) {
    final String code = countryCode.toUpperCase();
    if (code.length != 2) {
      return countryCode;
    }
    final int firstLetter = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  void _showIpClickBehaviorSettings() {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    globalState.showCommonDialog<IpClickBehavior>(
      child: CommonDialog(
        title: appLocalizations.ipClickBehavior,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.sync),
              title: Text(appLocalizations.manualRefreshIp),
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                detectionState.manualRefresh();
              },
            ),
            if (isZh)
              ListTile(
                leading: Icon(Icons.public),
                title: Text(appLocalizations.switchToDomesticIp),
                onTap: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  detectionState.switchToDomesticIp();
                },
              ),
            ListTile(
              leading: Icon(Icons.security),
              title: Text(appLocalizations.ipPrivacyProtection),
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                detectionState.toggleIpPrivacy();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(appLocalizations.networkDetectionUrl),
              subtitle: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  ref.watch(
                    appSettingProvider.select(
                      (state) => state.networkDetectionUrl,
                    ),
                  ),
                ),
              ),
              onTap: () async {
                Navigator.of(context, rootNavigator: true).pop();
                await globalState.showCommonDialog(
                  child: const _NetworkDetectionUrlDialog(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreIpInfoDialog() {
    final info = detectionState.rawIpInfo;
    if (info == null) return;
    globalState.showCommonDialog(child: NetworkIpInfoDialog(info: info));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: getWidgetHeight(1),
      child: ValueListenableBuilder<NetworkDetectionState>(
        valueListenable: detectionState.state,
        builder: (_, state, _) {
          final ipInfo = state.ipInfo;
          final isLoading = state.isLoading;
          return CommonCard(
            onPressed: ipInfo != null
                ? _showMoreIpInfoDialog
                : () {
                    if (isLoading == false) {
                      detectionState.manualRefresh();
                    }
                  },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  height: globalState.measure.titleMediumHeight + 16,
                  padding: baseInfoEdgeInsets.copyWith(bottom: 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      ipInfo != null
                          ? Text(
                              _countryCodeToEmoji(ipInfo.countryCode),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.toLight
                                  .copyWith(
                                    fontFamily: FontFamily.twEmoji.value,
                                    fontFamilyFallback: [
                                      FontFamily.twEmoji.value,
                                    ],
                                  ),
                            )
                          : Icon(
                              Icons.network_check,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      const SizedBox(width: 8),
                      Flexible(
                        flex: 1,
                        child: TooltipText(
                          text: Text(
                            appLocalizations.networkDetection,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ),
                      SizedBox(width: 2),
                      AspectRatio(
                        aspectRatio: 1,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: _showIpClickBehaviorSettings,
                          icon: Icon(
                            size: 16.ap,
                            Icons.settings_outlined,
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: baseInfoEdgeInsets.copyWith(top: 0),
                  child: SizedBox(
                    height: globalState.measure.bodyMediumHeight + 2,
                    child: FadeThroughBox(
                      child: ipInfo != null
                          ? TooltipText(
                              key: ValueKey(ipInfo.ip),
                              text: Text(
                                ipInfo.ip,
                                style: context.textTheme.bodyMedium?.toLight
                                    .adjustSize(1),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          : FadeThroughBox(
                              child: isLoading == false && ipInfo == null
                                  ? Text(
                                      key: ValueKey(state.errorMessage),
                                      state.errorMessage ?? 'timeout',
                                      style: context.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: context.colorScheme.error,
                                          )
                                          .adjustSize(1),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : Container(
                                      padding: const EdgeInsets.all(2),
                                      child: Center(
                                        child: OverflowBox(
                                          maxWidth: 30,
                                          maxHeight: 16,
                                          child:
                                              FluxoraMotion.ofContext(
                                                context,
                                              ).reduceMotion
                                              ? Icon(
                                                  Icons.hourglass_top_rounded,
                                                  size: 16,
                                                  color: context
                                                      .colorScheme
                                                      .primary,
                                                )
                                              : SpinKitThreeBounce(
                                                  color: context
                                                      .colorScheme
                                                      .primary,
                                                  size: 16,
                                                ),
                                        ),
                                      ),
                                    ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class NetworkIpInfoDialog extends StatelessWidget {
  const NetworkIpInfoDialog({super.key, required this.info});
  final IpInfo info;

  @override
  Widget build(BuildContext context) {
    final country = (info.country?.isNotEmpty ?? false)
        ? info.country!
        : info.countryCode;
    final facts = <(String, String)>[
      if (country.isNotEmpty || (info.continent?.isNotEmpty ?? false))
        (
          appLocalizations.countryOrRegion,
          [
            country,
            info.continent,
          ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
        ),
      if ((info.province?.isNotEmpty ?? false) ||
          (info.city?.isNotEmpty ?? false))
        (
          appLocalizations.provinceAndCity,
          [
            info.province,
            if (info.city != info.province) info.city,
          ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
        ),
      if (info.isp?.isNotEmpty ?? false) (appLocalizations.isp, info.isp!),
      if ((info.asn?.isNotEmpty ?? false) ||
          ((info.asName?.isNotEmpty ?? false) &&
              info.asName != info.isp &&
              info.asName != info.asDomain))
        (
          appLocalizations.operatorOrAsn,
          [
            if (info.asName != info.isp && info.asName != info.asDomain)
              info.asName,
            info.asn,
          ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
        ),
      if (info.asDomain?.isNotEmpty ?? false)
        (appLocalizations.domain, info.asDomain!),
    ];
    return CommonDialog(
      title: appLocalizations.moreIpInfo,
      maxWidth: 600,
      padding: const EdgeInsets.symmetric(
        horizontal: FluxoraSpacing.xl,
        vertical: FluxoraSpacing.lg,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: FluxoraSpacing.md,
        children: [
          FluxoraCard(
            filled: true,
            padding: const EdgeInsets.all(FluxoraSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        appLocalizations.ipAddress,
                        style: context.textTheme.labelMedium?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: appLocalizations.viewDetailedIpData,
                      icon: const Icon(Icons.open_in_new_rounded, size: 20),
                      onPressed: () {
                        Navigator.of(context).pop();
                        globalState.openUrl('https://www.ip2location.com/demo');
                      },
                    ),
                  ],
                ),
                SelectableText(
                  info.ip,
                  style: context.textTheme.bodyLarge?.toJetBrainsMono,
                ),
              ],
            ),
          ),
          if (facts.isNotEmpty)
            FluxoraCard(
              filled: true,
              padding: const EdgeInsets.all(FluxoraSpacing.lg),
              child: LayoutBuilder(
                builder: (_, constraints) {
                  final columns =
                      constraints.maxWidth >= 420 &&
                          MediaQuery.textScalerOf(context).scale(14) <= 18
                      ? 2
                      : 1;
                  return Wrap(
                    spacing: FluxoraSpacing.lg,
                    runSpacing: FluxoraSpacing.lg,
                    children: [
                      for (final (label, value) in facts)
                        SizedBox(
                          width:
                              (constraints.maxWidth -
                                  FluxoraSpacing.lg * (columns - 1)) /
                              columns,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: context.textTheme.labelMedium?.copyWith(
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: FluxoraSpacing.xs),
                              SelectableText(
                                value,
                                style: context.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          if (info.ip.isNotEmpty) _IpRiskSection(ip: info.ip),
        ],
      ),
    );
  }
}

class _NetworkDetectionUrlDialog extends ConsumerWidget {
  const _NetworkDetectionUrlDialog();

  @override
  Widget build(BuildContext context, ref) {
    final currentUrl = ref.watch(
      appSettingProvider.select((state) => state.networkDetectionUrl),
    );
    final isPresetUrl = presetNetworkDetectionUrls.contains(currentUrl);

    return CommonDialog(
      title: appLocalizations.networkDetectionUrl,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...presetNetworkDetectionUrls.map((url) {
            final isSelected = currentUrl == url;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  ref
                      .read(appSettingProvider.notifier)
                      .updateState(
                        (state) => state.copyWith(networkDetectionUrl: url),
                      );
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 21,
                        color: isSelected
                            ? context.colorScheme.primary
                            : context.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.6,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: isSelected
                            ? SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Text(
                                  url,
                                  style: context.textTheme.bodyMedium,
                                ),
                              )
                            : Text(
                                url,
                                style: context.textTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          // Custom URL option
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                final notifier = ref.read(appSettingProvider.notifier);
                Navigator.of(context, rootNavigator: true).pop();
                final customUrl = await globalState.showCommonDialog<String>(
                  child: InputDialog(
                    title: appLocalizations.customUrl,
                    value: isPresetUrl ? '' : currentUrl,
                    resetValue: defaultNetworkDetectionUrl,
                    validator: (String? inputValue) {
                      if (inputValue == null || inputValue.isEmpty) {
                        return appLocalizations.emptyTip(
                          appLocalizations.networkDetectionUrl,
                        );
                      }
                      if (!inputValue.isUrl) {
                        return appLocalizations.urlTip(
                          appLocalizations.networkDetectionUrl,
                        );
                      }
                      return null;
                    },
                  ),
                );

                if (customUrl != null) {
                  notifier.updateState(
                    (state) => state.copyWith(networkDetectionUrl: customUrl),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      !isPresetUrl
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 21,
                      color: !isPresetUrl
                          ? context.colorScheme.primary
                          : context.colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        appLocalizations.customUrl,
                        style: context.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// item 6 — pick which IP-reputation rows the detail view shows.
///
/// A flat checkbox list rather than the shared `OptionsDialog`, which is
/// single-select and would need a different return contract. Saving an empty
/// selection preserves the existing default of showing all fields.
class _IpRiskFieldsDialog extends StatefulWidget {
  const _IpRiskFieldsDialog({required this.selected});

  final Set<String> selected;

  @override
  State<_IpRiskFieldsDialog> createState() => _IpRiskFieldsDialogState();
}

class _IpRiskFieldsDialogState extends State<_IpRiskFieldsDialog> {
  late final Set<String> _selected = Set<String>.of(widget.selected);

  static String _label(String id) => switch (id) {
    IpReputationFieldIds.markers => appLocalizations.fieldMarkers,
    IpReputationFieldIds.score => appLocalizations.fieldScore,
    IpReputationFieldIds.scenarios => appLocalizations.fieldScenarios,
    IpReputationFieldIds.nativeType => appLocalizations.fieldNativeType,
    IpReputationFieldIds.usageType => appLocalizations.fieldUsageType,
    IpReputationFieldIds.asn => appLocalizations.fieldAsn,
    IpReputationFieldIds.abuse => appLocalizations.fieldAbuse,
    IpReputationFieldIds.blocklists => appLocalizations.fieldBlocklists,
    IpReputationFieldIds.unknownNotes => appLocalizations.fieldUnknownNotes,
    _ => id,
  };

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: appLocalizations.ipRiskFieldsTitle,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: Text(appLocalizations.save),
        ),
      ],
      child: Column(
        children: [
          for (final id in IpReputationFieldIds.all)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _selected.contains(id),
              title: Text(_label(id)),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selected.add(id);
                  } else {
                    _selected.remove(id);
                  }
                });
              },
            ),
        ],
      ),
    );
  }
}

class _IpRiskSection extends ConsumerStatefulWidget {
  const _IpRiskSection({required this.ip});

  final String ip;

  @override
  ConsumerState<_IpRiskSection> createState() => _IpRiskSectionState();
}

class _IpRiskSectionState extends ConsumerState<_IpRiskSection> {
  final IpReputationService _service = IpReputationService();
  IpReputation? _report;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Only fires for users who already opted in.
    if (ref.read(appSettingProvider).ipReputationEnabled) {
      _query();
    }
  }

  Future<void> _query() async {
    setState(() => _loading = true);
    final report = await _service.lookup(widget.ip);
    if (!mounted) return;
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  void _setEnabled(bool value) {
    ref
        .read(appSettingProvider.notifier)
        .updateState((state) => state.copyWith(ipReputationEnabled: value));
    if (value) {
      _query();
    } else {
      // Turning it off drops the result rather than leaving it on screen.
      setState(() => _report = null);
    }
  }

  /// Cancel keeps the saved selection; an empty set retains the existing default.
  Future<void> _pickFields() async {
    final current = resolveIpReputationFields(
      ref.read(appSettingProvider).ipReputationFields,
    );
    final next = await globalState.showCommonDialog<Set<String>>(
      child: _IpRiskFieldsDialog(selected: current),
    );
    if (next == null) return;
    ref
        .read(appSettingProvider.notifier)
        .updateState((state) => state.copyWith(ipReputationFields: next));
  }

  @override
  Widget build(BuildContext context) {
    final fields = resolveIpReputationFields(
      ref.watch(appSettingProvider.select((s) => s.ipReputationFields)),
    );
    final enabled = ref.watch(
      appSettingProvider.select((s) => s.ipReputationEnabled),
    );
    final report = _report;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: FluxoraSpacing.md,
      children: [
        FluxoraCard(
          filled: true,
          padding: const EdgeInsets.all(FluxoraSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: context.colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: FluxoraSpacing.sm),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        appLocalizations.ipRiskIntel,
                        style: context.textTheme.titleSmall,
                      ),
                    ),
                  ),
                  if (enabled)
                    IconButton(
                      onPressed: _pickFields,
                      tooltip: appLocalizations.ipRiskFieldsTitle,
                      icon: const Icon(Icons.tune_rounded, size: 20),
                    ),
                  Semantics(
                    label: appLocalizations.ipRiskEnable,
                    child: Switch.adaptive(
                      value: enabled,
                      onChanged: _loading
                          ? null
                          : _setLoadingGuard(_setEnabled),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FluxoraSpacing.sm),
              Text(
                appLocalizations.ipRiskPrivacyNote,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (enabled && _loading)
          Padding(
            padding: const EdgeInsets.all(FluxoraSpacing.lg),
            child: Center(
              child: FluxoraMotion.ofContext(context).reduceMotion
                  ? const Icon(Icons.hourglass_top_rounded)
                  : const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
            ),
          )
        else if (enabled && report != null)
          IpReputationResult(
            report: report,
            fields: fields,
            onOpenReport: report.reportUrl == null
                ? null
                : () => globalState.openUrl(report.reportUrl!),
          ),
      ],
    );
  }

  /// Blocks a second toggle while a lookup is in flight.
  ValueChanged<bool> _setLoadingGuard(ValueChanged<bool> inner) {
    return (value) {
      if (_loading) return;
      inner(value);
    };
  }
}
