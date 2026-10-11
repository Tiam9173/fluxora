import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';
import 'package:fluxora/models/chain_proxy.dart';
import 'package:fluxora/services/chain_fallback_service.dart';
import 'package:fluxora/services/chain_probe_service.dart';

/// P2.8-A — user-visible mojibake in the Chain-Fallback explanation.
///
/// `CandidateSelectionResult.explanation` is rendered verbatim:
///
///   chain_fallback_service.dart  (explanationBuffer)
///     → CandidateSelectionResult.explanation
///       → chain_failover_service.dart:393  `ChainFailoverProgress.message`
///       → chain_failover_service.dart:412  `ChainFailoverResult.rootCause`
///         → chain_proxy_view.dart:1429 (progress text) / :162 / :165 (SnackBar)
///
/// Three writes into that buffer carried mojibake and are repaired by P2.8-A.
/// The behavioural tests below drive the **real** `ChainFallbackService` (no
/// mock / no fake executor) so they assert the production call chain, not a
/// source-string approximation.
///
/// NOT covered on purpose (verified non-rendered, left untouched):
///   * `ChainTelemetryEvent.message` — `ChainTelemetryEvent.displayTitle` has no
///     call site, and the diagnostic export writes `ev.type.name` only;
///   * `CandidateExclusionRecord.message` — every `.excluded` consumer reads
///     `.reasonCode` only, and the explanation buffer uses
///     `e.candidate.nodeName` + `e.reasonCode`, never `e.message`.

/// Strips `//` line comments so the structural guards test *code*, not prose.
String _codeOnly(String source) => source
    .split('\n')
    .map((line) {
      final idx = line.indexOf('//');
      return idx < 0 ? line : line.substring(0, idx);
    })
    .join('\n');

/// A PUA codepoint is the fingerprint of the original corruption; the GBK
/// mojibake alphabet catches the lossy (non-PUA) variants too.
bool _hasMojibake(String s) {
  const fingerprint = [
    '鍘',
    '鍊',
    '鏁',
    '殰',
    '杞',
    '鎵',
    '搴',
    '旂',
    '鐢',
    '閫',
    '妭',
    '鐐',
    '缃',
    '闄',
    '鍒',
    '囨',
    '崲',
    '澶',
    '敤',
    '鑺',
    '偣',
    '鏈',
    '夊',
    '鎭',
    '姝',
    '锛',
    '屾',
    '棤',
    '闇',
    '娴',
    '嬪',
    '紓',
    '甯',
    '革',
    '紝',
    '杩',
    '炴',
    '帴',
    '瓒',
    '呮',
    '椂',
    '楠',
    '岃',
    '瘉',
    '氳',
    '繃',
  ];
  if (s.runes.any((r) => r >= 0xE000 && r <= 0xF8FF)) return true;
  if (s.contains('\uFFFD')) return true;
  return fingerprint.any(s.contains);
}

void main() {
  const config = ChainProxyConfig(
    enable: true,
    hopMode: ChainHopMode.twoHop,
    defaultDialerProxy: 'HK-01',
    hop1Node: 'HK-01',
    hop2Node: 'US-Resi',
  );

  // ── Behavioural: the two branches that fill the explanation buffer ────────

  group('CandidateSelectionResult.explanation is correct Chinese', () {
    test('selected branch (the byte-verified fix)', () {
      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'US-02',
            role: FallbackCandidateRole.exit,
            health: ChainHealthStatus.healthy,
            latencyMs: 42,
          ),
        ],
      );

      final result = chainFallbackService.selectCandidates(
        currentConfig: config,
        role: FallbackCandidateRole.exit,
        pool: pool,
      );

      expect(result.selected, isNotNull);
      expect(result.explanation, contains('已成功从备用池中为'));
      expect(result.explanation, contains('优选候选节点'));
      expect(result.explanation, contains('延迟 42ms'));
      expect(
        _hasMojibake(result.explanation),
        isFalse,
        reason: 'the selected-branch explanation must be clean UTF-8 Chinese',
      );
    });

    test('all-excluded branch', () {
      final pool = ChainFallbackPool(
        exitCandidates: [
          ChainFallbackCandidate(
            nodeName: 'US-02',
            role: FallbackCandidateRole.exit,
            enabled: false,
          ),
        ],
      );

      final result = chainFallbackService.selectCandidates(
        currentConfig: config,
        role: FallbackCandidateRole.exit,
        pool: pool,
      );

      expect(result.selected, isNull);
      expect(result.excluded, isNotEmpty);
      expect(result.explanation, contains('排除原因摘要'));
      expect(
        result.explanation,
        contains('DISABLED_NODE'),
        reason: 'the label must introduce the reasonCode list it prefixes',
      );
      expect(_hasMojibake(result.explanation), isFalse);
    });

    test('empty-pool branch stays correct', () {
      final result = chainFallbackService.selectCandidates(
        currentConfig: config,
        role: FallbackCandidateRole.exit,
        pool: const ChainFallbackPool(),
      );

      expect(result.explanation, contains('未配置任何备选节点'));
      expect(_hasMojibake(result.explanation), isFalse);
    });
  });

  // ── Rendering path: explanation really reaches a user-visible field ───────

  group('rendering path is intact (no source-only reassurance)', () {
    test(
      'chain_failover_service interpolates explanation into rendered fields',
      () {
        final src = File(
          'lib/services/chain_failover_service.dart',
        ).readAsStringSync();

        // progress message (rendered at chain_proxy_view.dart:1429)
        expect(src.contains(r'(${selectionResult.explanation})'), isTrue);
        // and the failed-result rootCause (rendered at :162/:165)
        expect(
          src.contains('rootCause:') &&
              src.contains(r'${selectionResult.explanation}'),
          isTrue,
        );
      },
    );

    test('chain_proxy_view renders progress.message and result.rootCause', () {
      final src = File(
        'lib/views/proxies/chain_proxy_view.dart',
      ).readAsStringSync();

      expect(src.contains('progress.message'), isTrue);
      expect(src.contains('result.rootCause'), isTrue);
    });
  });

  // ── Negative: the repaired sentinels must not come back ──────────────────

  group('mojibake sentinels must not reappear', () {
    test('the explanation writes carry no mojibake fingerprint', () {
      final src = _codeOnly(
        File('lib/services/chain_fallback_service.dart').readAsStringSync(),
      );

      for (final sentinel in const [
        '宸叉垚鍔熶粠澶囩敤姹犱腑', // the selected-branch prefix
        '寤惰', // the latency suffix
        '鎺掗櫎鍘熷洜鎽樿', // the exclusion-summary label
      ]) {
        expect(
          src.contains(sentinel),
          isFalse,
          reason: 'repaired mojibake sentinel returned: $sentinel',
        );
      }
      expect(src.contains('\uFFFD'), isFalse);
    });

    test('the repaired strings are present verbatim', () {
      final src = File(
        'lib/services/chain_fallback_service.dart',
      ).readAsStringSync();

      for (final expected in const ['已成功从备用池中为', '排除原因摘要']) {
        expect(src.contains(expected), isTrue, reason: 'missing: $expected');
      }
      // Asserted outside the const list, as a raw string: the `$` here is
      // source text (an interpolation inside the production literal), not an
      // interpolation of this test.
      expect(
        src.contains(r'延迟 ${selected.latencyMs}ms'),
        isTrue,
        reason: 'missing the repaired latency suffix',
      );
    });
  });
}
