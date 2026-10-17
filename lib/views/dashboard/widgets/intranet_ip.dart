import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/app.dart';
import 'package:fluxora/providers/config.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// item 6 — the "intranet IP" dashboard card, plus the LAN detail it opens.
///
/// The card itself is unchanged apart from the tap target, which used to be an
/// empty `() {}`. The detail sheet reports what the desktop route table and
/// Android `LinkProperties` actually say: connection type, interface, address,
/// **default gateway** and **system DNS**. Anything unavailable renders as "-" —
/// never as a fabricated value.
class IntranetIP extends ConsumerWidget {
  const IntranetIP({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: getWidgetHeight(1),
      child: FluxoraCard(
        info: Info(label: appLocalizations.intranetIP, iconData: Icons.devices),
        onTap: () => _openLanSettings(context, ref),
        child: Padding(
          padding: baseInfoEdgeInsets.copyWith(top: 0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: globalState.measure.bodyMediumHeight + 2,
                child: Consumer(
                  builder: (_, ref, _) {
                    final localIp = ref.watch(localIpProvider);
                    return FadeThroughBox(
                      child: localIp != null
                          ? TooltipText(
                              text: Text(
                                localIp.isNotEmpty
                                    ? localIp
                                    : appLocalizations.noNetwork,
                                style: FluxoraTypography.body.copyWith(
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(2),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openLanSettings(BuildContext context, WidgetRef ref) {
    showSheet(
      context: context,
      builder: (_, type) {
        return AdaptiveSheetScaffold(
          type: type,
          title: appLocalizations.intranetAndGateway,
          body: const _LanSettingsBody(),
        );
      },
    );
  }
}

/// Whether the gateway is worth opening in a browser.
///
/// A cellular interface has no reachable router page, and link-local /
/// carrier-grade-NAT / benchmark ranges are not real LAN gateways either.
/// Only RFC 1918 private ranges qualify.
bool canOpenGateway(String gateway, String networkType) {
  if (gateway.isEmpty || gateway == '0.0.0.0') return false;
  if (networkType.toLowerCase().contains('cellular')) return false;

  final parts = gateway.split('.');
  if (parts.length != 4) return false;
  final octets = parts.map(int.tryParse).toList();
  if (octets.any((o) => o == null || o < 0 || o > 255)) return false;

  final o1 = octets[0]!;
  final o2 = octets[1]!;
  // Loopback and link-local.
  if (o1 == 127 || (o1 == 169 && o2 == 254)) return false;
  // Carrier-grade NAT (RFC 6598) and benchmark (RFC 2544).
  if (o1 == 100 && o2 >= 64 && o2 <= 127) return false;
  if (o1 == 198 && (o2 == 18 || o2 == 19)) return false;

  return (o1 == 192 && o2 == 168) || o1 == 10 || (o1 == 172 && o2 >= 16 && o2 <= 31);
}

class _LanSettingsBody extends ConsumerStatefulWidget {
  const _LanSettingsBody();

  @override
  ConsumerState<_LanSettingsBody> createState() => _LanSettingsBodyState();
}

class _LanSettingsBodyState extends ConsumerState<_LanSettingsBody> {
  NetworkInfo? _fresh;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Reads fresh values, then mirrors them into `AppState` so the next open
  /// shows the cached report instantly instead of a spinner.
  ///
  /// The write only happens while this sheet is still mounted, which keeps it
  /// off the auto-disposed notifier after the route is gone.
  Future<void> _load() async {
    final info = await utils.getNetworkInfo();
    if (!mounted) return;
    setState(() {
      _fresh = info;
      _loading = false;
    });
    ref.read(localNetworkProvider.notifier).value = info;
  }

  @override
  Widget build(BuildContext context) {
    final network = _fresh ?? ref.watch(localNetworkProvider);
    final clashConfig = ref.watch(
      patchClashConfigProvider.select(
        (state) => (allowLan: state.allowLan, mixedPort: state.mixedPort),
      ),
    );

    if (_loading && network == null) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final info = network ?? const NetworkInfo();
    final colorScheme = context.colorScheme;
    // `null` means the lookup has not landed yet; an empty report means it
    // landed and found nothing. The two read differently on purpose.
    final placeholder = network == null ? '...' : '-';
    final sharedAddress = '${info.ip}:${clashConfig.mixedPort}';

    return ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      children: [
        // Header: the active transport as a status strip. Deliberately our own
        // shape (tinted rounded strip + pill) rather than the upstream dialog's
        // bracketed sections and boxed tiles.
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                _networkIcon(info.type),
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  info.type.isEmpty
                      ? (network == null ? '...' : appLocalizations.noNetwork)
                      : info.type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              if (info.ip.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    appLocalizations.coreConnected,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        _buildSectionLabel(appLocalizations.intranetAndGateway),
        _buildRow(
          icon: Icons.wifi_rounded,
          label: appLocalizations.networkType,
          value: info.type.isEmpty ? placeholder : info.type,
        ),
        _buildRow(
          icon: Icons.lan_rounded,
          label: appLocalizations.networkInterface,
          value: info.interfaceName.isEmpty ? placeholder : info.interfaceName,
        ),
        _buildRow(
          icon: Icons.devices_rounded,
          label: appLocalizations.intranetIP,
          value: info.ip.isEmpty ? placeholder : info.ip,
          action: info.ip.isEmpty
              ? null
              : IconButton(
                  iconSize: 15,
                  visualDensity: VisualDensity.compact,
                  tooltip: appLocalizations.copy,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: info.ip));
                    if (context.mounted) {
                      context.showNotifier(appLocalizations.copySuccess);
                    }
                  },
                  icon: Icon(
                    Icons.copy_rounded,
                    size: 15,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
        _buildRow(
          icon: Icons.router_rounded,
          label: appLocalizations.defaultGateway,
          value: info.gateway.isEmpty ? placeholder : info.gateway,
          action: info.gateway.isEmpty ||
                  !canOpenGateway(info.gateway, info.type)
              ? null
              : IconButton(
                  iconSize: 15,
                  visualDensity: VisualDensity.compact,
                  tooltip: appLocalizations.openGateway,
                  onPressed: () => globalState.openUrl('http://${info.gateway}'),
                  icon: Icon(
                    Icons.open_in_new_rounded,
                    size: 15,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
        _buildRow(
          icon: Icons.dns_rounded,
          label: appLocalizations.systemDns,
          value: info.dns.isEmpty ? placeholder : info.dns.join(', '),
        ),
        _buildSectionLabel(appLocalizations.allowLan),
        _buildLanTile(clashConfig.allowLan),
        if (clashConfig.allowLan && info.ip.isNotEmpty)
          _buildRow(
            icon: Icons.share_rounded,
            label: appLocalizations.lanShareAddress,
            value: sharedAddress,
            action: IconButton(
              iconSize: 15,
              visualDensity: VisualDensity.compact,
              tooltip: appLocalizations.copy,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: sharedAddress));
                if (context.mounted) {
                  context.showNotifier(appLocalizations.copySuccess);
                }
              },
              icon: Icon(
                Icons.copy_rounded,
                size: 15,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  /// Our own section marker: small caps label with a hairline rule. The
  /// upstream dialog used bracketed headers; this reads as one panel instead of
  /// a stack of separate ones.
  Widget _buildSectionLabel(String title) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  /// LAN sharing is a switch here rather than a status pill that navigates away:
  /// the address right below it is the reason to turn it on, so the two belong
  /// in one place.
  Widget _buildLanTile(bool allowLan) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            Icons.lan_rounded,
            size: 18,
            color: context.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              appLocalizations.allowLan,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Switch(
            value: allowLan,
            onChanged: (value) {
              ref
                  .read(patchClashConfigProvider.notifier)
                  .updateState((state) => state.copyWith(allowLan: value));
              globalState.appController.updateClashConfigDebounce();
            },
          ),
        ],
      ),
    );
  }

  /// Transport icon for the header strip; unknown types keep the generic one.
  IconData _networkIcon(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('wifi') || lower.contains('wi-fi')) {
      return Icons.wifi_rounded;
    }
    if (lower.contains('ethernet')) return Icons.lan_rounded;
    if (lower.contains('cellular') || lower.contains('mobile')) {
      return Icons.signal_cellular_alt_rounded;
    }
    return Icons.devices_rounded;
  }
  Widget _buildRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? action,
  }) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
