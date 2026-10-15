import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_failover.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/providers/chain_proxy.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/latency_freshness.dart';
import 'package:fluxora/services/chain_probe_service.dart';
import 'package:fluxora/views/proxies/intelligent_node_picker_sheet.dart';


Set<String>? chainNodeUniverse(Set<String> nodeNames) {
  if (nodeNames.isEmpty) {
    return null;
  }
  return nodeNames;
}

bool isFallbackCandidateStale(Set<String>? universe, String nodeName) {
  if (universe == null) {
    return false;
  }
  return !universe.contains(nodeName);
}

/// P3 — the visual state of one topology node, derived from the **real** probe
/// report (`chainProbeReportProvider`) rather than from "is the chain enabled".
///
/// A small enum plus pure resolvers below, so the mapping is unit-testable
/// without a widget harness.
enum TopologySegmentState {
  /// The report says this node's own hop probed healthy.
  healthy,

  /// The report says this node's hop failed / timed out, or `failureHop` names
  /// it. Always a **confirmed** per-hop signal — a whole-chain failure alone
  /// never marks a specific hop.
  failed,

  /// A probe is in flight.
  checking,

  /// A report exists but carries no usable result for this node.
  unknown,

  /// No usable report at all: never probed, chain disabled, or report stale.
  notProbed,
}

/// P3 — resolves one topology node's state from the real probe report.
///
/// Matching is by **node name first**: the report's hop order and the card's
/// visual order are separate concerns, and an incomplete chain can leave a node
/// unprobed. Only when the report carries **no hop list at all** (a
/// topology-level rejection) does the resolver fall back to [hopIndex], which
/// the caller derives from the **current** hop mode.
///
/// `failureHop` is the authoritative failure signal — `chain_probe_service.dart`
/// sets it to the index of the hop whose own probe failed — so it outranks a
/// per-hop status.
///
/// Staleness reuses the project's frozen freshness bound
/// ([LatencyFreshness.degradedMaxAge], 30 min) instead of inventing a second
/// policy: an older report is no longer evidence of anything.
TopologySegmentState resolveTopologySegmentState({
  required String nodeName,
  required int hopIndex,
  required ChainProbeReport? report,
  DateTime? now,
}) {
  if (report == null) return TopologySegmentState.notProbed;

  final DateTime effectiveNow = now ?? DateTime.now();
  if (effectiveNow.difference(report.timestamp) >
      LatencyFreshness.degradedMaxAge) {
    return TopologySegmentState.notProbed;
  }

  if (report.isCancelled ||
      report.healthStatus == ChainHealthStatus.cancelled) {
    return TopologySegmentState.unknown;
  }

  final int? failureHop = report.failureHop;
  final String trimmed = nodeName.trim();

  if (trimmed.isNotEmpty) {
    for (final HopProbeState hop in report.hops) {
      if (hop.nodeName.trim() != trimmed) continue;
      if (failureHop != null && hop.hopIndex == failureHop) {
        return TopologySegmentState.failed;
      }
      if (hop.status == HopProbeStatus.checking) {
        return TopologySegmentState.checking;
      }
      if (hop.healthStatus == ChainHealthStatus.failed ||
          hop.healthStatus == ChainHealthStatus.unavailable) {
        return TopologySegmentState.failed;
      }
      // `degraded` means the transport is established (only the exit-IP lookup
      // failed — see `chain_probe_service.dart`), so the hop itself is usable.
      if (hop.healthStatus == ChainHealthStatus.healthy ||
          hop.healthStatus == ChainHealthStatus.degraded) {
        return TopologySegmentState.healthy;
      }
      return TopologySegmentState.unknown;
    }
  }

  // No hop entry matched by name. Only a **topology-level rejection** (an empty
  // hop list) still names the offending hop through `failureHop`; with a
  // populated list an unmatched name simply means "no evidence for this node",
  // which must not be turned into a fabricated failure.
  if (report.hops.isEmpty) {
    if (failureHop != null && failureHop == hopIndex) {
      return TopologySegmentState.failed;
    }
    if (report.healthStatus == ChainHealthStatus.checking) {
      return TopologySegmentState.checking;
    }
  }
  return TopologySegmentState.unknown;
}

/// P3 — the flow state of the segment between two topology nodes.
///
/// A segment is as bad as its worst probed end: error wins, then "checking",
/// then "healthy". When neither end has evidence the segment stays neutral
/// (`idle`) — it is never green.
FluxoraFlowState topologySegmentFlow(
  TopologySegmentState a,
  TopologySegmentState b,
) {
  final Set<TopologySegmentState> states = {a, b};
  if (states.contains(TopologySegmentState.failed)) {
    return FluxoraFlowState.error;
  }
  if (states.contains(TopologySegmentState.checking)) {
    return FluxoraFlowState.connecting;
  }
  if (states.contains(TopologySegmentState.healthy)) {
    return FluxoraFlowState.connected;
  }
  return FluxoraFlowState.idle;
}

/// B3 — whether [config] is driven by the `hop1Node`/`hop2Node`/`hop3Node`
/// fields, and so has to pass [ChainTopologyValidator] before it is written.
///
/// A two-hop config with no `hop2Node` is the landing-proxy chain, which the
/// validator does not model: it requires `hop2` to be non-empty, so validating
/// it would report `EMPTY_HOP` for the working production configuration.
bool usesHopFieldChain(ChainProxyConfig config) =>
    config.hopMode == ChainHopMode.threeHop ||
    config.hop2Node.trim().isNotEmpty;

/// B3 — whether the config claims three hops but has not had both of them
/// chosen yet.
///
/// This drives the topology card's "三跳链路未完整" warning, and it is why an
/// `EMPTY_HOP` from the validator is treated as work in progress rather than a
/// rejected node (see [hopChainValidationError]).
bool isThreeHopIncomplete(ChainProxyConfig config) =>
    config.hopMode == ChainHopMode.threeHop &&
    (config.hop2Node.trim().isEmpty || config.hop3Node.trim().isEmpty);

/// B3 — the validator errors that mean `ChainProxyConfig.applyToClashConfig`
/// would drop the chain instead of generating it.
///
/// `EMPTY_HOP` is deliberately absent: the two hop rows are filled one at a
/// time, so the first pick always leaves the other hop empty, and blocking that
/// would deadlock the pickers. An incomplete chain is surfaced by
/// [isThreeHopIncomplete] instead, so it is never read as a finished three-hop.
const Set<String> _blockingHopErrorCodes = {
  'DUPLICATE_HOP',
  'SELF_REFERENCE',
  'NODE_NOT_FOUND',
  'CIRCULAR_DEPENDENCY',
};

/// B3 — the pre-write gate for a hop configuration.
///
/// Returns the message to show the user, or `null` when [candidate] may be
/// applied. Pure on purpose (no manager, no `BuildContext`) so the decision can
/// be pinned by tests, like [isFallbackCandidateStale] above.
///
/// `ChainProxyConfig.applyToClashConfig` silently injects nothing when a hop
/// node is missing from the proxy map, and it is never handed an
/// `availableProxyNames` list, so it cannot report that itself. Checking here,
/// against the same node set the picker offers, is what stops the UI from
/// saving a chain that never got generated.
///
/// [availableProxyNames] `null` means the node set could not be read: the
/// structural checks still run, but availability is left unverified, so a
/// `null` result must not be read as "verified".
String? hopChainValidationError(
  ChainProxyConfig candidate,
  List<String>? availableProxyNames,
) {
  if (!usesHopFieldChain(candidate)) return null;

  final result = ChainTopologyValidator.validate(
    mode: candidate.hopMode,
    hop1: candidate.effectiveHop1,
    hop2: candidate.hop2Node,
    hop3: candidate.hopMode == ChainHopMode.threeHop
        ? candidate.hop3Node
        : null,
    availableProxyNames: availableProxyNames,
    dedicatedGroupName: candidate.dedicatedGroupName,
  );
  if (result.isValid) return null;

  return _blockingHopErrorCodes.contains(result.errorCode)
      ? result.message
      : null;
}

class ChainProxyView extends ConsumerStatefulWidget {
  const ChainProxyView({super.key});

  @override
  ConsumerState<ChainProxyView> createState() => _ChainProxyViewState();
}

class _ChainProxyViewState extends ConsumerState<ChainProxyView> {
  bool _isGuideExpanded = false;

  @override
  void initState() {
    super.initState();
    chainProxyManager.init();
  }

  void _showIntelligentHopPicker({
    required String title,
    required String currentHop,
    required Set<String> excludedHops,
    required Function(String) onSelect,
    required FallbackCandidateRole role,
    bool allowDirect = true,
    bool allowFollowMain = false,
  }) {
    showSheet(
      context: context,
      props: SheetProps(isScrollControlled: true),
      builder: (ctx, type) {
        return IntelligentNodePickerSheet(
          title: title,
          currentHop: currentHop,
          excludedHops: excludedHops,
          allowDirect: allowDirect,
          allowFollowMain: allowFollowMain,
          onSelect: onSelect,
          role: role,
          sheetType: type,
        );
      },
    );
  }

  void _showQuickImportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _QuickImportDialog(
        onImport: (proxies) {
          chainProxyManager.addLandingProxies(proxies);
          context.showSnackBar(
            appLocalizations.importSuccessCount(proxies.length),
          );
        },
      ),
    );
  }

  void _showEditProxyDialog([LandingProxy? existing]) {
    showDialog(
      context: context,
      builder: (ctx) => _EditLandingProxyDialog(
        proxy: existing,
        onSave: (proxy) {
          if (existing == null) {
            chainProxyManager.addLandingProxies([proxy]);
          } else {
            chainProxyManager.updateLandingProxy(proxy);
          }
        },
      ),
    );
  }

  int _selectedFilter = 0; // 0: 全部, 1: 仅可用, 2: 异常/未测

  void _testAll() {
    final testUrl = globalState.config.appSetting.testUrl;
    chainProxyManager.testAllDelays(testUrl);
  }

  void _checkAllHealth() {
    chainProxyManager.checkAllProxiesHealth();
  }

  void _clearInvalidProxies() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(appLocalizations.clearInvalidProxies),
        content: Text(appLocalizations.confirmClearInvalid),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(appLocalizations.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(appLocalizations.confirm),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final count = await chainProxyManager.clearInvalidProxies();
      if (!mounted) return;
      if (count > 0) {
        context.showSnackBar(appLocalizations.clearedInvalidCount(count));
      } else {
        context.showSnackBar(appLocalizations.noInvalidProxies);
      }
    }
  }

  void _showHealthReportDialog(LandingProxy proxy) {
    showDialog(
      context: context,
      builder: (ctx) => _ProxyHealthReportDialog(
        proxy: proxy,
        defaultHop: ref.read(chainProxyConfigProvider).config.defaultDialerProxy,
      ),
    );
  }

  List<LandingProxy> _filterProxies(List<LandingProxy> list) {
    if (_selectedFilter == 1) {
      return list.where((p) {
        final report = chainProxyManager.getHealthReport(p.id);
        return report != null && report.status == HealthStatus.healthy;
      }).toList();
    } else if (_selectedFilter == 2) {
      return list.where((p) {
        final report = chainProxyManager.getHealthReport(p.id);
        return report == null ||
            report.status == HealthStatus.error ||
            report.status == HealthStatus.untested;
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(chainProxyConfigProvider);
    final config = manager.config;
    final landingProxies = config.landingProxies;
    final filteredProxies = _filterProxies(landingProxies);

    final healthyCount = landingProxies.where((p) {
      final r = chainProxyManager.getHealthReport(p.id);
      return r != null && r.status == HealthStatus.healthy;
    }).length;

    final errorCount = landingProxies.where((p) {
      final r = chainProxyManager.getHealthReport(p.id);
      return r == null ||
          r.status == HealthStatus.error ||
          r.status == HealthStatus.untested;
    }).length;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 0. Dynamic Topology Visualization Card
          _buildTopologyCard(context, config, landingProxies),
          const SizedBox(height: 12),

          // 1. Master enable card
          CommonCard(
            type: CommonCardType.filled,
            child: Column(
              children: [
                ListItem(
                  leading: const Icon(Icons.alt_route_rounded, size: 28),
                  title: Text(
                    appLocalizations.enableChainProxy,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(appLocalizations.enableChainProxyDesc),
                  trailing: Switch(
                    value: config.enable,
                    onChanged: (val) async {
                      if (val) {
                        final hasActive = landingProxies.any((p) => p.enable);
                        if (!hasActive) {
                          HapticFeedback.heavyImpact();
                          context.showSnackBar('请先添加并启用至少一个落地代理节点');
                          return;
                        }
                        HapticFeedback.lightImpact();
                        await chainProxyManager.setEnable(true);
                        // RC.10-A — probe once right after the chain turns on.
                        // Fire-and-forget on purpose: a failed probe must not
                        // roll the enable state back, and the UI must not block
                        // on a multi-second probe before confirming. The
                        // manager has no re-entrancy guard of its own, so skip
                        // when a probe is already running.
                        if (!chainProxyManager.isProbingChain) {
                          chainProxyManager.probeCurrentChain().then(
                            (_) {},
                            onError: (Object error) {
                              commonPrint.log(
                                'ChainProxyView: probe after enable failed: $error',
                              );
                            },
                          );
                        }
                        if (context.mounted) {
                          context.showSnackBar('已成功启用链式代理模式');
                        }
                      } else {
                        HapticFeedback.lightImpact();
                        await chainProxyManager.setEnable(false);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 1b. Manual failover card (P1.1-F)
          _buildFailoverCard(context, config),
          const SizedBox(height: 12),

          // 2. Default Hop & Integration settings
          CommonCard(
            type: CommonCardType.filled,
            child: Column(
              children: [
                // RC.10-A: the hop-count selector is gone — the chain is
                // two-hop only (dialer -> landing), matching the original UI.
                ListItem(
                  leading: const Icon(Icons.hub_outlined),
                  title: Text(appLocalizations.defaultDialerProxy),
                  subtitle: Text(
                    config.defaultDialerProxy.isEmpty
                        ? appLocalizations.followMainSelector
                        : config.defaultDialerProxy,
                    style: TextStyle(
                      color: context.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showIntelligentHopPicker(
                        title: appLocalizations.defaultDialerProxy,
                        currentHop: config.defaultDialerProxy,
                        excludedHops: const {},
                        role: FallbackCandidateRole.entry,
                        allowDirect: true,
                        allowFollowMain: true,
                        // RC.10-A.3 — `effectiveHop1` prefers `hop1Node`, so
                        // updating only `defaultDialerProxy` left the probe (and
                        // the topology failure label) pointing at the previous
                        // entry node. `setHop1Node` writes both fields, keeping
                        // node / '' (follow main) / DIRECT semantics intact.
                        onSelect: (hop) => chainProxyManager.setHop1Node(hop),
                      );
                  },
                ),
                // RC.10-A: the three-hop relay/exit rows are removed with the
                // hop-count selector; the landing-proxy chain manages the exit.
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListItem(
                  leading: const Icon(Icons.layers_outlined),
                  title: Text(appLocalizations.dedicatedGroup),
                  subtitle: Text(appLocalizations.dedicatedGroupDesc),
                  trailing: Switch(
                    value: config.createDedicatedGroup,
                    onChanged: (val) =>
                        chainProxyManager.setCreateDedicatedGroup(val),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListItem(
                  leading: const Icon(Icons.input_outlined),
                  title: Text(appLocalizations.autoInjectGroups),
                  subtitle: Text(appLocalizations.autoInjectGroupsDesc),
                  trailing: Switch(
                    value: config.autoInjectGroups,
                    onChanged: (val) =>
                        chainProxyManager.setAutoInjectGroups(val),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListItem(
                  leading: const Icon(Icons.security, color: Colors.blueAccent),
                  title: Text(appLocalizations.preventWebRtcLeak),
                  subtitle: Text(appLocalizations.preventWebRtcLeakDesc),
                  trailing: Switch(
                    value: config.preventWebRtcLeak,
                    onChanged: (val) =>
                        chainProxyManager.setPreventWebRtcLeak(val),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildFingerprintGuideCard(context),
          const SizedBox(height: 16),

          // 3. Section Header for Landing Proxies with Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // P1: Expanded so a long localized title ellipsises instead of
              // pushing the trailing action buttons off-screen on a narrow phone.
              Expanded(
                child: Text(
                  '${appLocalizations.landingProxies} (${landingProxies.length})',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (landingProxies.isNotEmpty) ...[
                    IconButton(
                      icon: manager.isBatchHealthChecking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.health_and_safety, color: Colors.green),
                      tooltip: appLocalizations.healthCheckAll,
                      onPressed: manager.isBatchHealthChecking ? null : _checkAllHealth,
                    ),
                    IconButton(
                      icon: const Icon(Icons.cleaning_services_outlined),
                      tooltip: appLocalizations.clearInvalidProxies,
                      onPressed: _clearInvalidProxies,
                    ),
                    IconButton(
                      icon: const Icon(Icons.bolt, color: Colors.amber),
                      tooltip: appLocalizations.testAll,
                      onPressed: _testAll,
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.content_paste_go),
                    tooltip: appLocalizations.quickImport,
                    onPressed: _showQuickImportDialog,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: appLocalizations.addLandingProxy,
                    onPressed: () => _showEditProxyDialog(),
                  ),
                ],
              ),
            ],
          ),

          // Batch Checking Progress Banner
          if (manager.isBatchHealthChecking) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: manager.batchCheckTotal > 0
                    ? manager.batchCheckCompleted / manager.batchCheckTotal
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              appLocalizations.batchCheckingProgress(
                manager.batchCheckCompleted,
                manager.batchCheckTotal,
              ),
              style: TextStyle(fontSize: 12, color: context.colorScheme.primary),
            ),
          ],

          // Filter Segmented Chips (All / Healthy / Error)
          if (landingProxies.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: Text('${appLocalizations.filterAll} (${landingProxies.length})'),
                    selected: _selectedFilter == 0,
                    onSelected: (_) => setState(() => _selectedFilter = 0),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    avatar: const Icon(Icons.check_circle, size: 14, color: Colors.green),
                    label: Text('${appLocalizations.filterHealthy} ($healthyCount)'),
                    selected: _selectedFilter == 1,
                    onSelected: (_) => setState(() => _selectedFilter = 1),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    avatar: const Icon(Icons.error_outline, size: 14, color: Colors.redAccent),
                    label: Text('${appLocalizations.filterError} ($errorCount)'),
                    selected: _selectedFilter == 2,
                    onSelected: (_) => setState(() => _selectedFilter = 2),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),

          // 4. Landing Proxies List or Empty State
          if (landingProxies.isEmpty)
            CommonCard(
              type: CommonCardType.filled,
              child: FluxoraEmptyState(
                icon: Icons.alt_route_rounded,
                title: '尚未配置落地住宅节点',
                description: appLocalizations.emptyLandingTip,
                action: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.content_paste_go, size: 18),
                      label: Text(appLocalizations.quickImport),
                      onPressed: _showQuickImportDialog,
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(appLocalizations.addLandingProxy),
                      onPressed: () => _showEditProxyDialog(),
                    ),
                  ],
                ),
              ),
            )
          else if (filteredProxies.isEmpty)
            CommonCard(
              type: CommonCardType.filled,
              child: FluxoraEmptyState(
                compact: true,
                icon: Icons.filter_list_off_outlined,
                title: '当前筛选条件下没有节点',
                action: TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('重置筛选'),
                  onPressed: () => setState(() => _selectedFilter = 0),
                ),
              ),
            )
          else
            for (final proxy in filteredProxies)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _LandingProxyCard(
                  proxy: proxy,
                  defaultHop: config.defaultDialerProxy,
                  onEdit: () => _showEditProxyDialog(proxy),
                  onDelete: () => chainProxyManager.deleteLandingProxy(proxy.id),
                  onToggle: (val) =>
                      chainProxyManager.toggleLandingProxy(proxy.id, val),
                  onTest: () {
                    final testUrl = globalState.config.appSetting.testUrl;
                    chainProxyManager.testProxyDelay(proxy, testUrl);
                  },
                  onCheckHealth: () => chainProxyManager.checkProxyHealth(proxy),
                  onShowReport: () => _showHealthReportDialog(proxy),
                ),
              ),
        ],
      ),
    );
  }

  /// P1.1-F — manual failover entry point.
  ///
  /// There is deliberately **no automatic trigger** here: the health-check
  /// timer owns that (P1.1-F2). The button is enabled only when the chain is
  /// enabled, at least one usable fallback candidate exists, and no session is
  /// already running. While a session runs it is disabled and shows the live
  /// `progress.message`; the outcome is surfaced through `result.rootCause`.
  Widget _buildFailoverCard(BuildContext context, ChainProxyConfig config) {
    final ChainFailoverProgress? progress = ref.watch(
      chainFailoverProgressProvider,
    );
    final isFailingOver = ref.watch(isFailingOverProvider);
    final pool = ref.watch(chainProxyConfigProvider).fallbackPool;

    final hasCandidate = <ChainFallbackCandidate>[
      ...pool.entryCandidates,
      ...pool.relayCandidates,
      ...pool.exitCandidates,
    ].any((c) => c.enabled);

    final canTrigger = config.enable && hasCandidate && !isFailingOver;

    final String subtitle;
    if (isFailingOver && progress != null) {
      subtitle = progress.message;
    } else if (!config.enable) {
      subtitle = appLocalizations.failoverEnableFirst;
    } else if (!hasCandidate) {
      subtitle = appLocalizations.failoverNoCandidates;
    } else {
      subtitle = appLocalizations.failoverManualHint;
    }

    // P1.3-B: the pool is the failover input, so it is managed here. Only the
    // roles the current hop mode actually uses are offered.
    // RC.10-A: three-hop is no longer offered, so only the two-hop roles remain.
    final roles = const [
      FallbackCandidateRole.entry,
      FallbackCandidateRole.exit,
    ];

    return CommonCard(
      type: CommonCardType.filled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListItem(
            leading: const Icon(Icons.swap_horiz_rounded, size: 28),
            title: Text(
              appLocalizations.failover,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(subtitle),
          ),
          const SizedBox(height: 8),
          // P0: the automatic failover loop previously had no user-facing
          // control, so the feature could never be turned on at all. This switch
          // is the only writer of `config.autoFailover`; toggling it persists the
          // flag and starts / stops the health-check loop (see
          // `ChainProxyManager.setAutoFailover`).
          ListItem(
            leading: Icon(
              config.autoFailover
                  ? Icons.autorenew
                  : Icons.pause_circle_outline,
            ),
            title: Text(appLocalizations.autoFailover),
            subtitle: Text(
              config.autoFailover
                  ? appLocalizations.autoFailoverOnDesc
                  : appLocalizations.autoFailoverOffDesc,
            ),
            trailing: Switch(
              value: config.autoFailover,
              onChanged: (val) => chainProxyManager.setAutoFailover(val),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          const SizedBox(height: 8),
          // Without candidates the chain probe has no pool candidate to credit
          // and failover has nothing to switch to, so the pool is editable here.
          for (final role in roles)
            _buildPoolRoleRow(context, role, pool.getCandidatesByRole(role)),
          // RC.8: with an empty pool the button below can only fail, so say what
          // to do about it. The advice points at the `+` controls directly above
          // — the real UI — rather than inventing a navigation entry.
          if (config.enable && !hasCandidate)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      appLocalizations.failoverNoCandidatesAdvice,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: canTrigger ? _triggerFailover : null,
            icon: isFailingOver
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(
              isFailingOver
                  ? appLocalizations.failoverInProgress
                  : appLocalizations.failoverTrigger,
            ),
          ),
        ],
      ),
    );
  }

  /// Localized label of a fallback-pool role.
  ///
  /// `FallbackCandidateRole.label` is a hard-coded Chinese string baked into the
  /// enum, so the view maps the role to an l10n key instead of showing it
  /// verbatim. The enum itself is left untouched.
  String _roleLabel(FallbackCandidateRole role) {
    return switch (role) {
      FallbackCandidateRole.entry => appLocalizations.roleEntry,
      FallbackCandidateRole.relay => appLocalizations.roleRelay,
      FallbackCandidateRole.exit => appLocalizations.roleExit,
    };
  }

  /// One editable role bucket of the fallback pool. Adding reuses the existing
  /// node picker; the manager keeps it idempotent and persists it.
  Widget _buildPoolRoleRow(
    BuildContext context,
    FallbackCandidateRole role,
    List<ChainFallbackCandidate> candidates,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              _roleLabel(role),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in candidates)
                  InputChip(
                    label: Text(c.nodeName),
                    onDeleted: () => chainProxyManager.removeFallbackCandidate(
                      nodeName: c.nodeName,
                      role: role,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: appLocalizations.addRoleCandidate(_roleLabel(role)),
            onPressed: () => _showIntelligentHopPicker(
              title: appLocalizations.addRoleFallbackCandidate(_roleLabel(role)),
              currentHop: '',
              excludedHops: candidates.map((c) => c.nodeName).toSet(),
              role: role,
              allowDirect: false,
              onSelect: (name) => chainProxyManager.addFallbackCandidate(
                nodeName: name,
                role: role,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerFailover() async {
    final manager = ref.read(chainProxyConfigProvider);
    final result = await manager.triggerAutoFailover(
      triggerReason: appLocalizations.failoverTriggerReason,
      bypassDampening: true,
    );
    if (!mounted) return;
    // The message is built from the REAL result — never from an assumed one.
    // `rootCause` is kept verbatim so a failure still says what actually
    // happened instead of a generic apology.
    final message = result.isSuccess
        ? appLocalizations.failoverSuccess(result.switchedNodeName ?? '')
        : appLocalizations.failoverFailed(result.rootCause ?? '');
    context.showSnackBar(message);
  }

  Widget _buildTopologyCard(
    BuildContext context,
    ChainProxyConfig config,
    List<LandingProxy> landingProxies,
  ) {
    final isReady = config.enable && landingProxies.any((p) => p.enable);
    final hopLabel = config.defaultDialerProxy.isEmpty
        ? appLocalizations.followMainSelector
        : config.defaultDialerProxy;

    // B3: three hops insert a relay between the dialer and the exit. The exit
    // node is `ChainProxyConfig.effectiveExitNode` — hop3Node in three-hop mode,
    // hop2Node / the active landing proxy in two-hop mode. That is the node the
    // probe actually measured, so label and probed status agree.
    final isThreeHop = config.hopMode == ChainHopMode.threeHop;
    final hasRelay = config.hop2Node.trim().isNotEmpty;
    final relayLabel = hasRelay
        ? config.hop2Node
        : appLocalizations.chainHopNotSelected;
    final exitName = config.effectiveExitNode.trim();
    final exitLabel = exitName.isEmpty
        ? appLocalizations.chainHopNotSelected
        : exitName;

    // P3: per-node state comes from the REAL probe report — never from "the
    // chain is enabled". When the chain is off nothing is probed, so every
    // segment is forced to `notProbed` instead of showing a stale green.
    final ChainProbeReport? probeReport = ref.watch(chainProbeReportProvider);

    TopologySegmentState probedState(String name, int hopIndex) {
      if (!config.enable) return TopologySegmentState.notProbed;
      if (name.trim().isEmpty) return TopologySegmentState.notProbed;
      return resolveTopologySegmentState(
        nodeName: name,
        hopIndex: hopIndex,
        report: probeReport,
      );
    }

    final TopologySegmentState entryState = probedState(
      config.effectiveHop1,
      1,
    );
    final TopologySegmentState relayState = probedState(config.hop2Node, 2);
    final TopologySegmentState exitState = probedState(
      exitName,
      isThreeHop ? 3 : 2,
    );
    // The client and the target are not chain hops, so nothing ever probes
    // them: they stay neutral and can never turn the card green on their own.
    const TopologySegmentState edgeState = TopologySegmentState.notProbed;

    // P3: an explicit per-hop summary, so a coloured row is never read as an
    // end-to-end availability proof — the probe measures each hop on its own.
    final List<({String label, String name, TopologySegmentState state})>
    probedSegments = [
      (
        label: appLocalizations.topologyHop,
        name: config.effectiveHop1,
        state: entryState,
      ),
      if (isThreeHop)
        (
          label: appLocalizations.topologyRelay,
          name: config.hop2Node,
          state: relayState,
        ),
      (
        label: appLocalizations.topologyLanding,
        name: exitName,
        state: exitState,
      ),
    ];

    ({String label, String name, TopologySegmentState state})? failedSegment;
    for (final segment in probedSegments) {
      if (segment.state == TopologySegmentState.failed) {
        failedSegment = segment;
        break;
      }
    }
    final bool anyChecking = probedSegments.any(
      (s) => s.state == TopologySegmentState.checking,
    );
    final bool allHealthy = probedSegments.every(
      (s) => s.state == TopologySegmentState.healthy,
    );
    final bool noEvidence = probedSegments.every(
      (s) =>
          s.state == TopologySegmentState.notProbed ||
          s.state == TopologySegmentState.unknown,
    );

    String? probeNoticeText;
    IconData probeNoticeIcon = Icons.info_outline;
    Color probeNoticeColor = context.colorScheme.onSurfaceVariant;
    if (config.enable) {
      if (failedSegment != null) {
        probeNoticeText =
            '${failedSegment.label}（${failedSegment.name}）探测失败，该段链路不可用';
        probeNoticeIcon = Icons.error_outline;
        probeNoticeColor = context.colorScheme.error;
      } else if (anyChecking) {
        probeNoticeText = '链路探测中…';
        probeNoticeIcon = Icons.sync;
        probeNoticeColor = context.colorScheme.primary;
      } else if (noEvidence) {
        probeNoticeText = '尚未探测：颜色仅表示配置，不代表链路健康';
      } else if (allHealthy) {
        probeNoticeText = '逐跳探测通过；端到端出口可用性请以实际访问为准';
        probeNoticeIcon = Icons.check_circle_outline;
        probeNoticeColor = context.colorScheme.primary;
      } else {
        probeNoticeText = '部分链路缺少探测结果：未探测的节点保持中性色';
      }
    }

    return CommonCard(
      type: CommonCardType.filled,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // P1: the title sub-row is wrapped in Expanded (and the title in
                // Flexible) so the trailing probe button / status chip keep their
                // intrinsic width on a narrow phone instead of overflowing.
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.hub_rounded,
                        size: 20,
                        color: context.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          '动态链路拓扑',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildChainProbeButton(context),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isReady
                        ? Colors.green.withValues(alpha: 0.15)
                        : context.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isReady
                          ? Colors.green.withValues(alpha: 0.5)
                          : context.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isReady ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isReady ? '已就绪' : '未启用',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isReady ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTopologyNode(
                      icon: Icons.devices_rounded,
                      title: appLocalizations.topologyClient,
                      subtitle: '设备端',
                      state: edgeState,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FluxoraFlowIndicator(
                        state: topologySegmentFlow(edgeState, entryState),
                        width: 36,
                        height: 12,
                      ),
                    ),
                    _buildTopologyNode(
                      icon: Icons.alt_route_rounded,
                      title: appLocalizations.topologyHop,
                      subtitle: hopLabel,
                      state: entryState,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FluxoraFlowIndicator(
                        state: topologySegmentFlow(
                          entryState,
                          isThreeHop ? relayState : exitState,
                        ),
                        width: 36,
                        height: 12,
                      ),
                    ),
                    if (isThreeHop) ...[
                      _buildTopologyNode(
                        icon: Icons.swap_horiz_rounded,
                        title: appLocalizations.topologyRelay,
                        subtitle: relayLabel,
                        state: relayState,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FluxoraFlowIndicator(
                          state: topologySegmentFlow(relayState, exitState),
                          width: 36,
                          height: 12,
                        ),
                      ),
                    ],
                    _buildTopologyNode(
                      icon: Icons.flight_land_rounded,
                      title: appLocalizations.topologyLanding,
                      subtitle: exitLabel,
                      state: exitState,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FluxoraFlowIndicator(
                        state: topologySegmentFlow(exitState, edgeState),
                        width: 36,
                        height: 12,
                      ),
                    ),
                    _buildTopologyNode(
                      icon: Icons.public_rounded,
                      title: appLocalizations.topologyTarget,
                      subtitle: '目标网络',
                      state: edgeState,
                    ),
                  ],
                ),
              ),
            ),
            // P3: the real per-hop probe outcome, stated in words. The colours
            // above carry the same information, but a legend keeps "probed
            // healthy" from being read as "the whole chain is proven usable".
            if (probeNoticeText != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(probeNoticeIcon, size: 14, color: probeNoticeColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      probeNoticeText,
                      style: TextStyle(fontSize: 11, color: probeNoticeColor),
                    ),
                  ),
                ],
              ),
            ],
            // B3: an incomplete three-hop chain generates no shadow nodes at
            // all, so say so here rather than letting the card read as ready.
            if (isThreeHopIncomplete(config)) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: context.colorScheme.errorContainer.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: context.colorScheme.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: context.colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        appLocalizations.chainHopIncomplete,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: false,
                tilePadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: const Icon(Icons.info_outline, size: 16),
                title: const Text(
                  '什么是前置跳板与落地节点？',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          '• 前置跳板 (Hop)：由本机连接的首级中继节点，负责第一级网络中转。',
                          style: TextStyle(fontSize: 11, height: 1.4),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '• 落地节点 (Landing)：经由跳板中继后发起网络连接的出口节点，向目标端呈现该出口节点网络特征。',
                          style: TextStyle(fontSize: 11, height: 1.4),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '• 多跳链路传输：通过前置跳板与落地节点分级路由，实现流量分层转发与网络拓扑解耦。',
                          style: TextStyle(fontSize: 11, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// P3 — one topology node, coloured by its **real** probed state.
  ///
  /// `healthy` / `checking` keep the card's existing accent (「正常：保持现有配色」),
  /// a confirmed failure is red, and `unknown` / `notProbed` stay neutral — an
  /// unproven segment must never read as green.
  /// RC.10-A — the manual chain probe button, placed just left of the
  /// "已就绪" badge inside the topology card header.
  ///
  /// Reuses the existing probe state ([isProbingChainProvider]) so the button
  /// can never drift from what the card renders, and calls the real
  /// [ChainProxyManager.probeCurrentChain]. The manager has no re-entrancy
  /// guard, so the button is disabled while a probe runs.
  Widget _buildChainProbeButton(BuildContext context) {
    final isProbing = ref.watch(isProbingChainProvider);
    return IconButton(
      icon: isProbing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.radar_rounded, size: 20),
      tooltip: appLocalizations.chainProbeNow,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: isProbing
          ? null
          : () {
              chainProxyManager.probeCurrentChain().then(
                (_) {},
                onError: (Object error) {
                  commonPrint.log(
                    'ChainProxyView: manual chain probe failed: $error',
                  );
                },
              );
            },
    );
  }

  Widget _buildTopologyNode({
    required IconData icon,
    required String title,
    required String subtitle,
    required TopologySegmentState state,
  }) {
    final colorScheme = context.colorScheme;
    final bool isFailed = state == TopologySegmentState.failed;
    final bool isEvidence =
        state == TopologySegmentState.healthy ||
        state == TopologySegmentState.checking;
    final bool isEmphasised = isFailed || isEvidence;

    final Color background = isFailed
        ? colorScheme.errorContainer.withValues(alpha: 0.3)
        : isEvidence
        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
        : colorScheme.surfaceContainer;
    final Color borderColor = isFailed
        ? colorScheme.error.withValues(alpha: 0.6)
        : isEvidence
        ? colorScheme.primary.withValues(alpha: 0.4)
        : colorScheme.outlineVariant.withValues(alpha: 0.3);
    final Color accentColor = isFailed
        ? colorScheme.error
        : isEvidence
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Container(
      constraints: const BoxConstraints(minWidth: 64, maxWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: accentColor),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isEmphasised
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFingerprintGuideCard(BuildContext context) {
    final now = DateTime.now();
    final offsetHours = now.timeZoneOffset.inHours;
    final offsetMinutes = (now.timeZoneOffset.inMinutes % 60).abs();
    final offsetStr = 'UTC${offsetHours >= 0 ? '+$offsetHours' : '$offsetHours'}'
        '${offsetMinutes > 0 ? ':${offsetMinutes.toString().padLeft(2, '0')}' : ''}';
    final tzName = now.timeZoneName.isNotEmpty ? ' (${now.timeZoneName})' : '';

    return CommonCard(
      type: CommonCardType.filled,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isGuideExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _isGuideExpanded = expanded;
            });
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: const Icon(
            Icons.fingerprint,
            color: Colors.teal,
            size: 28,
          ),
          title: const Text(
            '🎯 跨境养号与指纹防关联环境指南',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: Text(
            '针对 ToDetect / Whoer / IPpure 检测的时区与风控排查建议',
            style: TextStyle(
              fontSize: 12,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 16, color: Colors.blueAccent),
                            const SizedBox(width: 8),
                            const Text(
                              '当前设备系统时区：',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            Expanded(
                              child: Text(
                                '$offsetStr$tzName',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined, size: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            const Text(
                              'WebRTC 泄露防护：',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const Expanded(
                              child: Text(
                                '已硬核拦截 STUN/TURN (0泄露)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '⚠️ 针对 ToDetect 检测到“IP地址时区”异常标红的原因与方案：',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '1. 产生原因：网页端（如 ToDetect/Pixelscan）通过前端 JavaScript 读取操作系统的实际时区并与住宅 IP 地理时区对比。若住宅 IP 在美国加州 (America/Los_Angeles, UTC-8)，而手机设置为北京时间 (UTC+8)，网页端将标红提示“时区不一致”。\n'
                    '2. 手机端养号建议：前往手机「设置 -> 日期与时间」，关闭“自动设置”，将时区修改为落地 IP 对应时区（如「美国/洛杉矶」），系统语言设为 en-US。\n'
                    '3. 电脑端养号最佳实践：强烈建议在电脑端搭配专业指纹浏览器（如 AdsPower、比特、Hubstudio），指纹浏览器将基于住宅代理 IP 自动伪装匹配系统时区、Canvas 指纹与语言，实现 100% 满分纯净养号防关联！\n'
                    '4. 适用场景：亚马逊/eBay 店铺运营、TikTok 本土小店、Facebook/Instagram 矩阵、ChatGPT/Claude/Gemini 账号防风控封禁。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandingProxyCard extends ConsumerWidget {
  final LandingProxy proxy;
  final String defaultHop;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTest;
  final VoidCallback onCheckHealth;
  final VoidCallback onShowReport;

  const _LandingProxyCard({
    required this.proxy,
    required this.defaultHop,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    required this.onTest,
    required this.onCheckHealth,
    required this.onShowReport,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delay = ref.watch(chainProxyDelayProvider(proxy.id));
    final report = chainProxyManager.getHealthReport(proxy.id);
    final effectiveHop = (proxy.dialerProxy != null && proxy.dialerProxy!.isNotEmpty)
        ? proxy.dialerProxy!
        : (defaultHop.isEmpty ? '跟随主选择' : defaultHop);

    return CommonCard(
      type: CommonCardType.filled,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Protocol Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    proxy.protocol.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: context.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Proxy Name
                Expanded(
                  child: Text(
                    proxy.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                // Health status badge
                _buildHealthStatusBadge(context, report, delay),
                const SizedBox(width: 4),
                // Enable Switch
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: proxy.enable,
                    onChanged: onToggle,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Server address, port, username & service capability tags
            Row(
              children: [
                Icon(
                  Icons.dns_outlined,
                  size: 14,
                  color: context.colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    proxy.username.isNotEmpty
                        ? '${proxy.server}:${proxy.port} (${proxy.username})'
                        : '${proxy.server}:${proxy.port}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colorScheme.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (report != null &&
                    (report.status == HealthStatus.healthy ||
                        report.status == HealthStatus.warning)) ...[
                  const SizedBox(width: 6),
                  Wrap(
                    spacing: 4,
                    children: [
                      if (report.isTargetAvailable(TargetService.openai))
                        _buildServiceMiniTag('ChatGPT', Colors.green),
                      if (report.isTargetAvailable(TargetService.tiktok))
                        _buildServiceMiniTag('TikTok', Colors.green),
                      if (report.isTargetAvailable(TargetService.google))
                        _buildServiceMiniTag('Google', Colors.blue),
                      if (report.isTargetAvailable(TargetService.amazon))
                        _buildServiceMiniTag('Amazon', Colors.orange),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // Hop info, Delay badge & Action buttons
            Row(
              children: [
                // Hop chip
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.link, size: 13, color: Colors.blue),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '跳板: $effectiveHop',
                            style: const TextStyle(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _buildDelayBadge(context, delay),
                const SizedBox(width: 4),
                _buildActionButton(
                  icon: Icons.health_and_safety_outlined,
                  color: Colors.green,
                  tooltip: appLocalizations.healthCheck,
                  onPressed: onCheckHealth,
                ),
                _buildActionButton(
                  icon: Icons.analytics_outlined,
                  color: Colors.blue,
                  tooltip: appLocalizations.healthReport,
                  onPressed: onShowReport,
                ),
                _buildActionButton(
                  icon: Icons.edit_outlined,
                  color: null,
                  tooltip: '编辑',
                  onPressed: onEdit,
                ),
                _buildActionButton(
                  icon: Icons.delete_outline,
                  color: Colors.redAccent,
                  tooltip: '删除',
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color? color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 18, color: color),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildServiceMiniTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildHealthStatusBadge(BuildContext context, ProxyHealthReport? report, int? delay) {
    if (report == null) {
      return InkWell(
        onTap: onCheckHealth,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.health_and_safety_outlined, size: 12, color: Colors.grey),
              const SizedBox(width: 3),
              Text(
                appLocalizations.healthCheck,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (report.isTesting) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
            const SizedBox(width: 4),
            Text(
              appLocalizations.testingHealth,
              style: const TextStyle(fontSize: 10, color: Colors.blue),
            ),
          ],
        ),
      );
    }

    final (color, text) = switch (report.status) {
      HealthStatus.healthy => (Colors.green, '${appLocalizations.healthHealthy} ${report.minDelay ?? delay ?? ''}ms'.trim()),
      HealthStatus.warning => (Colors.orange, appLocalizations.healthWarning),
      HealthStatus.error => (Colors.red, appLocalizations.healthError),
      HealthStatus.testing => (Colors.blue, appLocalizations.testingHealth),
      HealthStatus.untested => (Colors.grey, appLocalizations.healthUntested),
    };

    return InkWell(
      onTap: onShowReport,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              report.status == HealthStatus.healthy
                  ? Icons.check_circle
                  : (report.status == HealthStatus.warning
                      ? Icons.warning_amber
                      : Icons.cancel),
              size: 12,
              color: color,
            ),
            const SizedBox(width: 3),
            Text(
              text,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDelayBadge(BuildContext context, int? delay) {
    if (delay == 0) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (delay == null) {
      return InkWell(
        onTap: onTest,
        borderRadius: BorderRadius.circular(4),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt, size: 14, color: Colors.grey),
              SizedBox(width: 2),
              Text('测速', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final Color color = switch (delay) {
      > 0 && < 300 => Colors.green,
      >= 300 && < 800 => Colors.orange,
      _ => Colors.red,
    };

    final text = delay > 0 ? '$delay ms' : '超时';

    return InkWell(
      onTap: onTest,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _QuickImportDialog extends StatefulWidget {
  final Function(List<LandingProxy>) onImport;

  const _QuickImportDialog({required this.onImport});

  @override
  State<_QuickImportDialog> createState() => _QuickImportDialogState();
}

class _QuickImportDialogState extends State<_QuickImportDialog> {
  final TextEditingController _controller = TextEditingController();
  List<LandingProxy> _parsed = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
    _checkClipboardAutoPaste();
  }

  Future<void> _checkClipboardAutoPaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty && mounted) {
      final list = LandingProxyParser.parseText(text);
      if (list.isNotEmpty) {
        _controller.text = text;
      }
    }
  }

  void _handleTextChanged() {
    final list = LandingProxyParser.parseText(_controller.text);
    setState(() {
      _parsed = list;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      _controller.text = text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(appLocalizations.quickImport),
      content: SizedBox(
        width: MediaQuery.of(context).size.width.clamp(0.0, 480.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    appLocalizations.quickImportDesc,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colorScheme.outline,
                    ),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.paste, size: 16),
                  label: Text(appLocalizations.pasteFromClipboard),
                  onPressed: _pasteFromClipboard,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: 6,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: appLocalizations.inputProxyTextHint,
                hintStyle: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            if (_parsed.isNotEmpty)
              Text(
                '已识别 ${_parsed.length} 个节点：${_parsed.map((e) => e.name).take(3).join(', ')}${_parsed.length > 3 ? ' 等' : ''}',
                style: const TextStyle(fontSize: 12, color: Colors.green),
              )
            else if (_controller.text.trim().isNotEmpty)
              Text(
                appLocalizations.parseNoValidNode,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.cancel),
        ),
        FilledButton(
          onPressed: _parsed.isEmpty
              ? null
              : () {
                  widget.onImport(_parsed);
                  Navigator.of(context).pop();
                },
          child: Text(appLocalizations.confirm),
        ),
      ],
    );
  }
}

class _EditLandingProxyDialog extends StatefulWidget {
  final LandingProxy? proxy;
  final Function(LandingProxy) onSave;

  const _EditLandingProxyDialog({this.proxy, required this.onSave});

  @override
  State<_EditLandingProxyDialog> createState() =>
      _EditLandingProxyDialogState();
}

class _EditLandingProxyDialogState extends State<_EditLandingProxyDialog> {
  late TextEditingController _nameController;
  late TextEditingController _serverController;
  late TextEditingController _portController;
  late TextEditingController _userController;
  late TextEditingController _passController;
  late TextEditingController _dialerController;
  ChainProxyProtocol _protocol = ChainProxyProtocol.socks5;
  bool _udp = true;
  bool _showPassword = false;
  bool _isTesting = false;
  DirectCheckResult? _testResult;

  @override
  void initState() {
    super.initState();
    final p = widget.proxy;
    _nameController = TextEditingController(text: p?.name ?? '');
    _serverController = TextEditingController(text: p?.server ?? '');
    _portController = TextEditingController(
      text: p?.port != null ? p!.port.toString() : '1080',
    );
    _userController = TextEditingController(text: p?.username ?? '');
    _passController = TextEditingController(text: p?.password ?? '');
    _dialerController = TextEditingController(text: p?.dialerProxy ?? '');
    _protocol = p?.protocol ?? ChainProxyProtocol.socks5;
    _udp = p?.udp ?? true;
  }

  void _testCurrentProxy() async {
    final server = _serverController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? _protocol.defaultPort;
    if (server.isEmpty) {
      context.showSnackBar('请先输入服务器地址');
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final res = await chainProxyManager.directCheckProxy(
      server: server,
      port: port,
      protocol: _protocol,
      username: _userController.text.trim(),
      password: _passController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _testResult = res;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _serverController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passController.dispose();
    _dialerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.proxy == null
            ? appLocalizations.addLandingProxy
            : '编辑落地代理',
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width.clamp(0.0, 480.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: appLocalizations.nodeName,
                  hintText: '例：美国家庭住宅IP 01',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ChainProxyProtocol>(
                initialValue: _protocol,
                decoration: InputDecoration(
                  labelText: appLocalizations.protocol,
                ),
                items: ChainProxyProtocol.values.map((proto) {
                  return DropdownMenuItem(
                    value: proto,
                    child: Text(proto.displayName),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _protocol = val;
                      if (_portController.text.isEmpty ||
                          _portController.text == '1080' ||
                          _portController.text == '8080' ||
                          _portController.text == '8388') {
                        _portController.text = val.defaultPort.toString();
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _serverController,
                      decoration: InputDecoration(
                        labelText: appLocalizations.serverAddress,
                        hintText: 'IP 或域名',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: appLocalizations.port,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _userController,
                decoration: InputDecoration(
                  labelText: appLocalizations.username,
                  hintText: '可选',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passController,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: appLocalizations.password,
                  hintText: '可选',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _showPassword = !_showPassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dialerController,
                decoration: InputDecoration(
                  labelText: appLocalizations.specificDialerProxy,
                  hintText: '留空则继承全局默认跳板',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(appLocalizations.udpForwarding),
                subtitle: Text(appLocalizations.udpForwardingDesc),
                value: _udp,
                onChanged: (val) => setState(() => _udp = val),
              ),
              if (_isTesting) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(appLocalizations.testing, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ] else if (_testResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: (_testResult!.isSuccess
                            ? Colors.green
                            : (_testResult!.isAuthError ? Colors.red : Colors.orange))
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (_testResult!.isSuccess
                              ? Colors.green
                              : (_testResult!.isAuthError ? Colors.red : Colors.orange))
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _testResult!.isSuccess
                            ? Icons.check_circle
                            : (_testResult!.isAuthError
                                ? Icons.lock_clock
                                : Icons.error_outline),
                        size: 16,
                        color: _testResult!.isSuccess
                            ? Colors.green
                            : (_testResult!.isAuthError ? Colors.red : Colors.orange),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _testResult!.isSuccess
                              ? '${_testResult!.message} (${_testResult!.delay}ms)'
                              : _testResult!.message,
                          style: TextStyle(
                            fontSize: 12,
                            color: _testResult!.isSuccess
                                ? Colors.green.shade800
                                : (_testResult!.isAuthError
                                    ? Colors.red.shade800
                                    : Colors.orange.shade800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.network_check, size: 16),
          label: Text(appLocalizations.testCurrentProxy),
          onPressed: _isTesting ? null : _testCurrentProxy,
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.cancel),
        ),
        FilledButton(
          onPressed: () {
            final server = _serverController.text.trim();
            final port = int.tryParse(_portController.text.trim()) ?? 1080;
            if (server.isEmpty) {
              context.showSnackBar('请输入服务器地址');
              return;
            }

            final name = _nameController.text.trim().isNotEmpty
                ? _nameController.text.trim()
                : '住宅IP-$server:$port';

            final updated = LandingProxy(
              id: widget.proxy?.id ?? utils.uuidV4,
              name: name,
              protocol: _protocol,
              server: server,
              port: port,
              username: _userController.text.trim(),
              password: _passController.text.trim(),
              dialerProxy: _dialerController.text.trim(),
              udp: _udp,
              enable: widget.proxy?.enable ?? true,
            );

            widget.onSave(updated);
            Navigator.of(context).pop();
          },
          child: Text(appLocalizations.confirm),
        ),
      ],
    );
  }
}

class _ProxyHealthReportDialog extends ConsumerWidget {
  final LandingProxy proxy;
  final String defaultHop;

  const _ProxyHealthReportDialog({
    required this.proxy,
    required this.defaultHop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(chainProxyConfigProvider);
    final report = chainProxyManager.getHealthReport(proxy.id);
    final effectiveHop = (proxy.dialerProxy != null && proxy.dialerProxy!.isNotEmpty)
        ? proxy.dialerProxy!
        : (defaultHop.isEmpty ? '主选择组' : defaultHop);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.verified_user_outlined, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              appLocalizations.healthReport,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width.clamp(0.0, 480.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Topology link diagram
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTopologyNode(Icons.computer, appLocalizations.topologyClient, context),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                      ),
                      _buildTopologyNode(Icons.alt_route, '$effectiveHop\n(${appLocalizations.topologyHop})', context, color: Colors.blue),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                      ),
                      _buildTopologyNode(Icons.home_outlined, '${proxy.name}\n(${appLocalizations.topologyLanding})', context, color: Colors.teal),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                      ),
                      _buildTopologyNode(Icons.public, appLocalizations.topologyTarget, context, color: Colors.orange),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Health status card
              _buildOverallStatusCard(context, report),
              const SizedBox(height: 12),

              // 3. Targets test results
              Text(
                '主流目标服务连通性',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: context.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 6),
              if (report == null || report.targets.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  child: Text(
                    '点击下方「${appLocalizations.retest}」开始体检',
                    style: TextStyle(color: context.colorScheme.outline),
                  ),
                )
              else
                ...report.targets.map((target) => _buildTargetRow(context, target)),

              // 4. Diagnostic advice
              if (report != null && report.diagnosticTips.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (report.status == HealthStatus.error
                            ? Colors.red
                            : (report.status == HealthStatus.warning ? Colors.orange : Colors.blue))
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (report.status == HealthStatus.error
                              ? Colors.red
                              : (report.status == HealthStatus.warning ? Colors.orange : Colors.blue))
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 16,
                        color: report.status == HealthStatus.error
                            ? Colors.red
                            : (report.status == HealthStatus.warning ? Colors.orange : Colors.blue),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          report.diagnosticTips,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton.tonalIcon(
          icon: report?.isTesting == true
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 16),
          label: Text(report?.isTesting == true
              ? appLocalizations.testingHealth
              : appLocalizations.retest),
          onPressed: report?.isTesting == true
              ? null
              : () => chainProxyManager.checkProxyHealth(proxy),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(appLocalizations.confirm),
        ),
      ],
    );
  }

  Widget _buildTopologyNode(IconData icon, String text, BuildContext context, {Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color ?? context.colorScheme.primary),
        const SizedBox(height: 2),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildOverallStatusCard(BuildContext context, ProxyHealthReport? report) {
    if (report == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.help_outline, color: Colors.grey),
            const SizedBox(width: 8),
            // P1: Expanded so a long localized label ellipsises rather than
            // overflowing this full-width status container.
            Expanded(
              child: Text(
                appLocalizations.healthUntested,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    final (color, icon, title) = switch (report.status) {
      HealthStatus.healthy => (Colors.green, Icons.check_circle_outline, appLocalizations.healthHealthy),
      HealthStatus.warning => (Colors.orange, Icons.warning_amber_outlined, appLocalizations.healthWarning),
      HealthStatus.error => (Colors.red, Icons.error_outline, appLocalizations.healthError),
      HealthStatus.testing => (Colors.blue, Icons.sync, appLocalizations.testingHealth),
      HealthStatus.untested => (Colors.grey, Icons.help_outline, appLocalizations.healthUntested),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (report.minDelay != null && report.minDelay! > 0)
                  Text(
                    '响应延迟: 最优 ${report.minDelay}ms | 平均 ${report.avgDelay ?? report.minDelay}ms',
                    style: TextStyle(fontSize: 11, color: context.colorScheme.outline),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetRow(BuildContext context, TargetHealthResult target) {
    final isOk = target.isSuccess;
    final color = isOk ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            isOk ? Icons.check_circle : Icons.cancel,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  target.service.label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  target.service.desc,
                  style: TextStyle(fontSize: 10, color: context.colorScheme.outline),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isOk ? '${target.delay} ms' : (target.error ?? '失败'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
