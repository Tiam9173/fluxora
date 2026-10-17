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
    final rawIpInfo = detectionState.rawIpInfo;
    if (rawIpInfo == null) return;

    final flagEmoji = rawIpInfo.countryCode.isNotEmpty
        ? _countryCodeToEmoji(rawIpInfo.countryCode)
        : '';

    final countryName =
        (rawIpInfo.country != null && rawIpInfo.country!.isNotEmpty)
        ? rawIpInfo.country!
        : (rawIpInfo.countryCode.isNotEmpty ? rawIpInfo.countryCode : '');

    final countryContinent = [
      if (countryName.isNotEmpty) countryName,
      if (rawIpInfo.continent != null && rawIpInfo.continent!.isNotEmpty)
        rawIpInfo.continent,
    ].join(' · ');

    final provinceCity = [
      if (rawIpInfo.province != null && rawIpInfo.province!.isNotEmpty)
        rawIpInfo.province,
      if (rawIpInfo.city != null &&
          rawIpInfo.city!.isNotEmpty &&
          rawIpInfo.city != rawIpInfo.province)
        rawIpInfo.city,
    ].join(' · ');

    final ispText = (rawIpInfo.isp != null && rawIpInfo.isp!.isNotEmpty)
        ? rawIpInfo.isp!
        : '';

    final operatorText = [
      if (rawIpInfo.asName != null &&
          rawIpInfo.asName!.isNotEmpty &&
          rawIpInfo.asName != rawIpInfo.isp &&
          rawIpInfo.asName != rawIpInfo.asDomain)
        rawIpInfo.asName,
      if (rawIpInfo.asn != null && rawIpInfo.asn!.isNotEmpty)
        rawIpInfo.asn,
    ].join(' · ');

    globalState.showCommonDialog(
      child: CommonDialog(
        title: appLocalizations.moreIpInfo,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
            },
            child: Text(appLocalizations.confirm),
          ),
        ],
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. IP 地址（附带查看详细 IP 数据外链与 Tooltip 提示）
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_outlined),
                title: Text(appLocalizations.ipAddress),
                subtitle: SelectableText(
                  rawIpInfo.ip,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  tooltip: appLocalizations.viewDetailedIpData,
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    globalState.openUrl('https://www.ip2location.com/demo');
                  },
                ),
              ),
              // 2. 国家与大洲合并（Emoji 统一使用 twEmoji，精准间距）
              if (countryContinent.isNotEmpty || flagEmoji.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(appLocalizations.countryOrRegion),
                  subtitle: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (flagEmoji.isNotEmpty) ...[
                        Text(
                          flagEmoji,
                          style: TextStyle(
                            fontFamily: FontFamily.twEmoji.value,
                            fontFamilyFallback: [
                              FontFamily.twEmoji.value,
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          countryContinent,
                          style: context.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              // 3. 省份 / 城市 (独立行，非空才展示)
              if (provinceCity.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_city_outlined),
                  title: Text(appLocalizations.provinceAndCity),
                  subtitle: Text(provinceCity),
                ),
              // 4. 归属 / ASN (非空才展示)
              if (operatorText.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.business_outlined),
                  title: Text(appLocalizations.operatorOrAsn),
                  subtitle: Text(operatorText),
                ),
              // 5. 运营商 (非空才展示)
              if (ispText.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.router_outlined),
                  title: Text(appLocalizations.isp),
                  subtitle: Text(ispText),
                ),
              // 6. 组织 / 域名 (非空才展示)
              if (rawIpInfo.asDomain != null && rawIpInfo.asDomain!.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.link_outlined),
                  title: Text(appLocalizations.domain),
                  subtitle: Text(rawIpInfo.asDomain!),
                ),
              // 7. P4 — IP 风险情报。
              //
              // E-5: a **separate** section, never merged into the `IpInfo`
              // fields above; default OFF, so nothing is sent anywhere until the
              // user turns it on.
              if (rawIpInfo.ip.isNotEmpty) ...[
                const Divider(height: 24),
                _IpRiskSection(ip: rawIpInfo.ip),
              ],
            ],
          ),
        ),
      ),
    );
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
                                      state.errorMessage ?? 'timeout',
                                      style: context.textTheme.bodyMedium
                                          ?.copyWith(color: Colors.red)
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
                                          child: SpinKitThreeBounce(
                                            color: context.colorScheme.primary,
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
                      .updateState((state) => state.copyWith(networkDetectionUrl: url));
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

/// P4 — the "IP risk intel" section.
///
/// Contract (E-4 / E-5):
/// * **Separate** from the `IpInfo` rows above — it never reads or writes
///   `IpInfo`, and `networkDetectionUrl` is untouched.
/// * **Default OFF.** Nothing leaves the device until the user flips the switch;
///   every lookup is gated on that switch. Opening this dialog is a user action,
///   and a node switch never reaches this widget.
/// * Shows the source, the source's own query time and a stale warning, so a
///   cached report is never presented as real-time.
/// * A failed lookup renders as a failure with its reason — **never** as a clean
///   result.
/// * **No composite score**: only the independent markers (E-4).
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

  String _markerLabel(IpRiskMarker marker) => switch (marker.id) {
    'vpn' => appLocalizations.ipRiskVpn,
    'proxy' => appLocalizations.ipRiskProxy,
    'tor' => appLocalizations.ipRiskTor,
    'hosting' => appLocalizations.ipRiskHosting,
    'relay' => appLocalizations.ipRiskRelay,
    'mobile' => appLocalizations.ipRiskMobile,
    'bogon' => appLocalizations.ipRiskBogon,
    'searchEngineBot' => appLocalizations.ipRiskSearchEngineBot,
    _ => marker.id,
  };

  String _stateLabel(IpRiskMarkerState state) => switch (state) {
    IpRiskMarkerState.flagged => appLocalizations.flagged,
    IpRiskMarkerState.clear => appLocalizations.ipRiskNotFlagged,
    IpRiskMarkerState.unknown => appLocalizations.unknown,
  };

  String _formatQueriedAt(DateTime t) {
    final l = t.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} '
        '${two(l.hour)}:${two(l.minute)}';
  }

  Widget _markerChip(IpRiskMarker marker) {
    final scheme = Theme.of(context).colorScheme;
    final (IconData icon, Color color) = switch (marker.state) {
      IpRiskMarkerState.flagged => (Icons.error_outline, scheme.error),
      IpRiskMarkerState.clear => (Icons.check_circle_outline, scheme.outline),
      IpRiskMarkerState.unknown => (Icons.help_outline, scheme.outlineVariant),
    };
    return SizedBox(
      width: 150,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '${_markerLabel(marker)} · ${_stateLabel(marker.state)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(
      appSettingProvider.select((s) => s.ipReputationEnabled),
    );
    final report = _report;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.shield_outlined),
          title: Text(appLocalizations.ipRiskIntel),
          subtitle: Text(appLocalizations.ipRiskPrivacyNote),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(appLocalizations.ipRiskEnable),
          value: enabled,
          onChanged: _setLoadingGuard(_setEnabled),
        ),
        if (enabled) ...[
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (report == null)
            const SizedBox.shrink()
          else if (!report.isOk)
            // E-5: a failure is shown as a failure — it is never a clean result.
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.cloud_off_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(appLocalizations.ipRiskFailed),
              subtitle: Text(report.failureReason ?? ''),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final marker in report.markers) _markerChip(marker),
                ],
              ),
            ),
            _kv(appLocalizations.source, report.source ?? ''),
            if (report.queriedAt != null)
              _kv(appLocalizations.time, _formatQueriedAt(report.queriedAt!)),
            if (report.stale)
              // E-5: a stale report must not masquerade as real-time.
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 14,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        appLocalizations.ipRiskStale,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (report.asn != null || report.asnOrg != null)
              _kv(
                'ASN',
                [report.asn, report.asnOrg].whereType<String>().join(' · '),
              ),
            if (report.usageType != null)
              _kv(appLocalizations.ipRiskHosting, report.usageType!),
            if (report.abuseScore != null)
              _kv(
                appLocalizations.ipRiskAbuse,
                '${report.abuseScore}'
                    '${report.abuseReports == null ? '' : ' (${report.abuseReports})'}',
              ),
            if (report.blocklistsHit.isNotEmpty)
              _kv(appLocalizations.ipRiskBlocklists, report.blocklistsHit.join(', ')),
            // The source's own limits, surfaced so a high score is never read as
            // a safety guarantee (E-4).
            if (report.unknownNotes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                appLocalizations.ipRiskLimits,
                style: context.textTheme.labelMedium,
              ),
              for (final note in report.unknownNotes)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('• $note', style: context.textTheme.bodySmall),
                ),
            ],
            if (report.reportUrl != null)
              TextButton(
                onPressed: () => globalState.openUrl(report.reportUrl!),
                child: Text(appLocalizations.ipRiskOpenReport),
              ),
          ],
        ],
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

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: context.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
