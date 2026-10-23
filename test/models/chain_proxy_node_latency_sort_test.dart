import 'package:flutter_test/flutter_test.dart';

/// P1.3-C4-Step5 — the 「延迟」 sort rule (`ChainProxyNodeViewModel.compareByLatency`).
///
/// Decision Q1 + Q7: the rule is extracted so it is independently testable (no
/// provider harness needed), and it must:
///   · rank nodes that have a valid latency first, ascending;
///   · sink unknowns (`latencyMs == null`) to the end;
///   · keep unknowns — and equal values — in a deterministic name order, since
///     `List.sort` is not stable;
///   · never treat `null` as `0 ms`.
///
/// P2 (option 3) adds the no-data contract on top: with nothing measured the
/// fallback must stay the documented name order (never a fabricated value, never
/// a silent switch to the Smart order), and the sort mode must be part of the
/// cache identity so one mode can never serve another mode's cached list.
void main() {


  group('ChainProxyNodeViewModel.compareByLatency — Step5 latency sort', () {



  });

  // ── P2 (option 3): the no-data case must be honest ────────────────────────
  group('P2 — latency sort with missing data', () {



  });

}
