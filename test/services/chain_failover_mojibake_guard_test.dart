import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// P2.6-C — regression guard for **user-visible** failover copy.
///
/// `lib/services/chain_failover_service.dart` carried mojibake (its UTF-8
/// Chinese had been re-decoded as GBK) in exactly the strings that reach the
/// user:
///
///   * `ChainFailoverProgress.message`  → rendered at chain_proxy_view.dart:1429
///   * `ChainFailoverResult.rootCause`  → rendered at chain_proxy_view.dart:162/165
///   * `ChainProbeReport.rootCauseAnalysis` → interpolated into the message above
///
/// plus three literal `'garbled'` placeholders used as stand-ins for lost text.
///
/// This is deliberately a **source-level** guard: it is fully deterministic, it
/// needs no Flutter binding, no timer, no network and no service wiring, so it
/// cannot become flaky. A behavioural test of the same copy lives in the
/// failover suites; this one only exists to make the encoding regression
/// impossible to reintroduce silently.
///
/// Comments and telemetry-only messages (`ChainTelemetryEvent.message`, which is
/// never rendered — `ChainTelemetryEvent.displayTitle` has no call site) are
/// intentionally *not* covered.
void main() {
  final File file = File('lib/services/chain_failover_service.dart');
  final String source = file.readAsStringSync();

  /// Every user-visible string that P2.6-C repaired, as a distinctive substring.
  const List<String> userVisibleCopy = <String>[
    '执行前已取消',
    '原链路检测异常，正在执行有限重试...',
    '重试阶段已被取消',
    '原链路重试后恢复正常，无需切换备用节点',
    '故障转移在抖动抑制检查前被取消',
    '触发高频链路抖动抑制保护',
    '原链路重试耗尽，正在优选 [',
    '未找到可用的 [',
    '候选优选后已被取消',
    '尝试候选节点前已被取消',
    '正在构建候选链路拓扑 [',
    '正在校验候选链路拓扑 [',
    '应用候选前已被取消',
    '正在热重载候选配置 [',
    '候选应用后、探测前被取消',
    '正在验证新候选链路 [',
    '候选探测执行异常: ',
    '候选探测期间被取消',
    '验证通过，正在提交故障转移...',
    '故障转移成功，已平滑切换至 [',
    '验证未通过 (',
    '正在回滚原链路配置...',
    '回滚原链路严重失败: ',
    '失败且回滚原配置遭遇异常: ',
    '所有备用候选节点均尝试完毕且不可用，故障转移失败',
  ];

  test('the file no longer contains any `garbled` sentinel', () {
    expect(
      source.contains("'garbled'"),
      isFalse,
      reason:
          'the three `reason: \'garbled\'` placeholders must carry real copy',
    );
  });

  test('the repaired user-visible copy is present verbatim', () {
    for (final String s in userVisibleCopy) {
      expect(
        source.contains(s),
        isTrue,
        reason: 'missing user-visible failover copy: $s',
      );
    }
  });

  test('no user-visible line carries a PUA mojibake codepoint', () {
    // PUA (U+E000..U+F8FF) is the fingerprint of the original corruption: every
    // UTF-8 byte GBK could not map was emitted as U+E000+.
    // NOTE: `RegExp(r'[\u{E000}-\u{F8FF}]')` throws "Range out of order in
    // character class" on the Dart VM, so the check is done on runes.
    bool hasPua(String s) =>
        s.runes.any((int r) => r >= 0xE000 && r <= 0xF8FF);
    final List<String> lines = source.split('\n');
    for (final String line in lines) {
      final bool isUserVisible = userVisibleCopy.any(line.contains);
      if (!isUserVisible) continue;
      expect(
        hasPua(line),
        isFalse,
        reason: 'PUA mojibake left in user-visible copy: ${line.trim()}',
      );
    }
  });

  test('the file is not double-encoded (no U+FFFD replacement char)', () {
    expect(
      source.contains('\uFFFD'),
      isFalse,
      reason: 'the source must stay valid UTF-8 with no lossy replacement char',
    );
  });
}
