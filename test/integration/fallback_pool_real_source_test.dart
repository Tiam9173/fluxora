import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/common.dart';
import 'package:path/path.dart' as p;

/// P1.1-E — real-source → Fallback Pool → persistence → restore.
///
/// This test intentionally does NOT certify the production path by
/// constructing `ChainFallbackCandidate`/`ChainFallbackPool` directly. Instead
/// it starts from a **Mihomo-shaped** `List<Group>` fixture (the same shape the
/// real `groupsProvider` exposes), derives the candidate **node names from that
/// source**, feeds them through the real `ChainProxyManager` CRUD methods, and
/// then exercises the persisted file exactly as `ChainProxyManager.init()`
/// would on startup.
///
/// NOT covered here (requires the running Flutter UI): the
/// `IntelligentNodePickerSheet` → `addFallbackCandidate` tap path. That is
/// listed as a manual verification item — it is NOT claimed as verified.
///
/// Persistence uses [ChainProxyManager.fallbackPoolFilePathOverride] so the
/// test never touches the real application data directory.
List<Group> _mihomoShapedGroups() {
  return [
    Group(
      type: GroupType.Selector,
      name: 'GLOBAL',
      all: [
        Proxy(name: 'DIRECT', type: 'Direct'),
        Proxy(name: 'PROXY', type: 'Selector'),
      ],
    ),
    Group(
      type: GroupType.URLTest,
      name: 'PROXY',
      all: [
        Proxy(name: 'DIRECT', type: 'Direct'),
        Proxy(name: 'HK-01', type: 'Hysteria2'),
        Proxy(name: 'JP-02', type: 'Vless'),
        Proxy(name: 'US-03', type: 'Shadowsocks'),
        Proxy(name: 'REJECT', type: 'Reject'),
      ],
    ),
    Group(
      type: GroupType.Selector,
      name: 'CHAIN-GROUP',
      all: [
        Proxy(name: 'SG-04', type: 'Trojan'),
      ],
    ),
  ];
}

/// Mirrors `_ChainProxyViewState._realProxyNames()` in
/// `lib/views/proxies/chain_proxy_view.dart` (skip GLOBAL, collect `p.name`).
Set<String> _realProxyNamesFrom(List<Group> groups) {
  final names = <String>{};
  for (final g in groups) {
    if (g.name != 'GLOBAL') {
      for (final p in g.all) {
        names.add(p.name);
      }
    }
  }
  return names;
}

void main() {
  late Directory tmp;
  late String poolPath;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fluxora_pool_integration_');
    poolPath = p.join(tmp.path, 'chain_fallback_pool.json');
    ChainProxyManager.fallbackPoolFilePathOverride = poolPath;
  });

  tearDown(() {
    ChainProxyManager.fallbackPoolFilePathOverride = null;
    if (tmp.existsSync()) {
      tmp.deleteSync(recursive: true);
    }
  });

  test('source-derived node names flow into the pool and survive persistence',
      () async {
    final manager = ChainProxyManager();
    await manager.updateFallbackPool((_) => const ChainFallbackPool());

    final groups = _mihomoShapedGroups();
    final realNames = _realProxyNamesFrom(groups);
    expect(realNames, containsAll(<String>['HK-01', 'JP-02', 'US-03', 'SG-04']));
    expect(realNames, isNot(contains('PROXY'))); // GLOBAL-only group member

    // Candidate names are taken from the source, never invented.
    final entryName = realNames.firstWhere((n) => n == 'HK-01');
    final relayName = realNames.firstWhere((n) => n == 'JP-02');
    final exitName = realNames.firstWhere((n) => n == 'US-03');

    await manager.addFallbackCandidate(
      nodeName: entryName,
      role: FallbackCandidateRole.entry,
    );
    await manager.addFallbackCandidate(
      nodeName: relayName,
      role: FallbackCandidateRole.relay,
    );
    await manager.addFallbackCandidate(
      nodeName: exitName,
      role: FallbackCandidateRole.exit,
    );

    final pooled = <String>{
      ...manager.fallbackPool.entryCandidates.map((c) => c.nodeName),
      ...manager.fallbackPool.relayCandidates.map((c) => c.nodeName),
      ...manager.fallbackPool.exitCandidates.map((c) => c.nodeName),
    };
    expect(pooled, {entryName, relayName, exitName});
    // Every pooled name really came from the source universe.
    expect(realNames.containsAll(pooled), isTrue);

    // Persisted file is config-only.
    final file = File(poolPath);
    expect(file.existsSync(), isTrue);
    final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final persistedEntry =
        (raw['entryCandidates'] as List).first as Map<String, dynamic>;
    expect(persistedEntry['nodeName'], entryName);
    expect(persistedEntry.containsKey('statsByContext'), isFalse);
    expect(persistedEntry.containsKey('health'), isFalse);

    // Startup restore (identical decode to ChainProxyManager.init()).
    final restored = ChainFallbackPool.fromJson(raw);
    expect(restored.entryCandidates.single.nodeName, entryName);
    expect(restored.relayCandidates.single.nodeName, relayName);
    expect(restored.exitCandidates.single.nodeName, exitName);
  });

  test('candidate removed from the source is preserved and flagged stale',
      () async {
    final manager = ChainProxyManager();
    await manager.updateFallbackPool((_) => const ChainFallbackPool());

    // Source v1 contains HK-01.
    final sourceV1 = _mihomoShapedGroups();
    final namesV1 = _realProxyNamesFrom(sourceV1);
    expect(namesV1, contains('HK-01'));
    await manager.addFallbackCandidate(
      nodeName: 'HK-01',
      role: FallbackCandidateRole.entry,
    );

    // Subscription changes: HK-01 disappears from the source.
    final sourceV2 = [
      Group(
        type: GroupType.URLTest,
        name: 'PROXY',
        all: [Proxy(name: 'JP-02', type: 'Vless')],
      ),
    ];
    final namesV2 = _realProxyNamesFrom(sourceV2);
    expect(namesV2, isNot(contains('HK-01')));

    // Restore from disk: the stale candidate MUST survive (never auto-deleted).
    final raw = jsonDecode(File(poolPath).readAsStringSync())
        as Map<String, dynamic>;
    final restored = ChainFallbackPool.fromJson(raw);
    expect(restored.entryCandidates.single.nodeName, 'HK-01');

    // The pool card flags it via the same predicate.
    expect(namesV2.contains(restored.entryCandidates.single.nodeName), isFalse);
  });
}
