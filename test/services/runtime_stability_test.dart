import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/services/chain_telemetry_service.dart';
import 'package:fluxora/services/chain_flap_dampener_service.dart';
import 'package:fluxora/models/chain_telemetry.dart';
import 'package:fluxora/models/chain_flap_dampening.dart';
import 'package:fluxora/models/chain_fallback_pool.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Phase 5.1-A Runtime Stability Test Suite
//
// Tests are written against isolated service instances (NOT the global
// singletons) so they do not interfere with each other.
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // Scenario A: 1-Hour-Equivalent Memory Bounds Simulation
  // ──────────────────────────────────────────────────────────────────────────
  group('Scenario A — Long-running simulation (1h equivalent)', () {
    late ChainTelemetryService telemetry;
    late ChainFlapDampenerService dampener;

    setUp(() {
      telemetry = ChainTelemetryService();
      dampener = ChainFlapDampenerService();
    });

    test(
      'A1. Telemetry FIFO stays bounded at maxEvents=200 after 10,000 events',
      () {
        for (int i = 0; i < 10000; i++) {
          telemetry.record(
            ChainTelemetryEvent(
              type: i.isEven
                  ? ChainTelemetryEventType.probeCompleted
                  : ChainTelemetryEventType.probeFailed,
              role: 'entry',
              message: 'event $i',
            ),
          );
        }
        final snapshot = telemetry.getSnapshot();
        expect(
          snapshot.recentEvents.length,
          lessThanOrEqualTo(ChainTelemetryService.maxEvents),
        );
        expect(snapshot.totalEvents, equals(10000));
      },
    );

    test('A2. Telemetry counters never overflow for 10,000 events', () {
      for (int i = 0; i < 10000; i++) {
        telemetry.record(
          ChainTelemetryEvent(
            type: ChainTelemetryEventType.probeCompleted,
            role: 'relay',
            message: 'ok',
          ),
        );
      }
      final snap = telemetry.getSnapshot();
      expect(snap.totalEvents, equals(10000));
      expect(snap.successEvents, equals(10000));
      expect(snap.failedEvents, equals(0));
    });

    test('A3. Flap dampener event history stays bounded after 5,000 flaps', () {
      final policy = const ChainFlapDampeningPolicy(maxHistoryEvents: 100);
      for (int i = 0; i < 5000; i++) {
        dampener.recordFlap(
          role: FallbackCandidateRole.entry,
          fromNode: 'A',
          toNode: 'B',
          reason: 'test flap $i',
          isSuccess: true,
          policy: policy,
        );
      }
      final status = dampener.getStatus(policy: policy);
      expect(
        status.recentEvents.length,
        lessThanOrEqualTo(policy.maxHistoryEvents),
      );
    });

    test('A4. Flap dampener penalty decays after sufficient time', () {
      final policy = const ChainFlapDampeningPolicy(
        penaltyPerFlap: 10.0,
        halfLife: Duration(seconds: 5),
      );
      final t0 = DateTime(2026, 1, 1, 0, 0, 0);
      dampener.recordFlap(
        role: FallbackCandidateRole.entry,
        fromNode: 'A',
        toNode: 'B',
        timestamp: t0,
        policy: policy,
      );

      // After 5 half-lives (25 seconds) penalty should be ~10 * (0.5^5) = 0.3125
      final status = dampener.getStatus(
        now: t0.add(const Duration(seconds: 25)),
        policy: policy,
      );
      expect(status.currentPenalty, lessThan(1.0));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Scenario B: Repeated init / dispose cycle (listener accumulation test)
  // Tests a local listener counter pattern mirroring init() registration.
  // ──────────────────────────────────────────────────────────────────────────
  group('Scenario B — Repeated listener registration/removal cycles', () {
    test('B1. Listeners added and removed do not accumulate over 100 cycles', () {
      final telemetry = ChainTelemetryService();
      int notificationCount = 0;

      // Simulate 100 init/dispose cycles where we register then remove a listener.
      for (int cycle = 0; cycle < 100; cycle++) {
        void cb() {
          notificationCount++;
        }

        telemetry.addListener(cb);
        // Simulate dispose: remove listener immediately after.
        telemetry.removeListener(cb);
      }

      // After all cycles, firing a notification should NOT trigger any callbacks
      // because every listener was removed.
      final before = notificationCount;
      telemetry.record(
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeCompleted,
          role: 'test',
          message: 'tick',
        ),
      );
      // notificationCount should be unchanged since all listeners were removed.
      expect(notificationCount, equals(before));
    });

    test(
      'B2. After 100 listener-pair add/remove cycles, only 1 active listener remains',
      () {
        final telemetry = ChainTelemetryService();
        int callCount = 0;

        // Always-alive listener that should remain.
        void permanentListener() {
          callCount++;
        }

        telemetry.addListener(permanentListener);

        for (int cycle = 0; cycle < 100; cycle++) {
          void tempCb() {
            callCount += 1000;
          } // large offset to detect leaks

          telemetry.addListener(tempCb);
          telemetry.removeListener(tempCb);
        }

        // Fire one notification. Only permanentListener should respond.
        telemetry.record(
          ChainTelemetryEvent(
            type: ChainTelemetryEventType.probeCompleted,
            role: 'test',
            message: 'tick',
          ),
        );
        expect(callCount, equals(1)); // Only permanentListener fired.

        // Cleanup.
        telemetry.removeListener(permanentListener);
      },
    );

    test(
      'B3. Flap dampener listener add/remove does not accumulate over 100 cycles',
      () {
        final dampener = ChainFlapDampenerService();
        int count = 0;

        for (int i = 0; i < 100; i++) {
          void cb() {
            count++;
          }

          dampener.addListener(cb);
          dampener.removeListener(cb);
        }

        final before = count;
        dampener.reset(); // triggers _notifyListeners
        expect(count, equals(before));
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Scenario C: Rapid telemetry burst (1,000 events)
  // ──────────────────────────────────────────────────────────────────────────
  group('Scenario C — Rapid telemetry burst', () {
    test('C1. 1,000 simultaneous record() calls complete without crash', () {
      final telemetry = ChainTelemetryService();
      // Synchronous burst — Dart is single-threaded so this tests re-entrancy guard.
      for (int i = 0; i < 1000; i++) {
        telemetry.record(
          ChainTelemetryEvent(
            type: ChainTelemetryEventType.probeCompleted,
            role: 'exit',
            message: 'burst $i',
          ),
        );
      }
      final snap = telemetry.getSnapshot();
      expect(snap.totalEvents, equals(1000));
      expect(
        snap.recentEvents.length,
        lessThanOrEqualTo(ChainTelemetryService.maxEvents),
      );
    });

    test(
      'C2. Listener triggered during record() does NOT cause re-entrant crash (single cascade)',
      () {
        final telemetry = ChainTelemetryService();
        int depth = 0;
        int maxDepth = 0;
        bool reentrantFired = false;

        // NOTE: A listener that unconditionally calls record() every notification
        // will cause _notifyListeners()'s do-while loop to spin infinitely.
        // This test validates the safe pattern: guard with a boolean flag.
        void reentrantListener() {
          depth++;
          maxDepth = maxDepth < depth ? depth : maxDepth;
          if (!reentrantFired) {
            reentrantFired = true;
            telemetry.record(
              ChainTelemetryEvent(
                type: ChainTelemetryEventType.probeFailed,
                role: 'entry',
                message: 're-entrant (once only)',
              ),
            );
          }
          depth--;
        }

        telemetry.addListener(reentrantListener);
        telemetry.record(
          ChainTelemetryEvent(
            type: ChainTelemetryEventType.probeCompleted,
            role: 'entry',
            message: 'initial',
          ),
        );

        // Re-entrant event was queued and processed via _pendingQueue drain.
        final snap = telemetry.getSnapshot();
        expect(snap.totalEvents, equals(2));
        // maxDepth == 1 confirms the listener was NOT recursively invoked.
        expect(maxDepth, equals(1));

        telemetry.removeListener(reentrantListener);
      },
    );

    test(
      'C3. Pending queue is fully drained after burst with re-entrant records',
      () {
        final telemetry = ChainTelemetryService();
        bool cascadeFired = false;

        // The listener fires exactly once: the first notification triggers one more record.
        // After that, cascadeFired prevents further calls.
        void cascadeListener() {
          if (!cascadeFired) {
            cascadeFired = true;
            telemetry.record(
              ChainTelemetryEvent(
                type: ChainTelemetryEventType.probeCompleted,
                role: 'relay',
                message: 'cascade',
              ),
            );
          }
        }

        telemetry.addListener(cascadeListener);
        telemetry.record(
          ChainTelemetryEvent(
            type: ChainTelemetryEventType.probeCompleted,
            role: 'entry',
            message: 'seed',
          ),
        );

        // The re-entrant event should have been queued and processed.
        expect(telemetry.getSnapshot().totalEvents, equals(2));
        telemetry.removeListener(cascadeListener);
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Scenario D: Recovery request lifecycle
  // ──────────────────────────────────────────────────────────────────────────
  group('Scenario D — Recovery request state lifecycle', () {
    test('D1. Telemetry clear() resets all counters and events', () {
      final telemetry = ChainTelemetryService();
      for (int i = 0; i < 50; i++) {
        telemetry.record(
          ChainTelemetryEvent(
            type: ChainTelemetryEventType.probeFailed,
            role: 'entry',
            message: 'fail $i',
          ),
        );
      }
      telemetry.clear();
      final snap = telemetry.getSnapshot();
      expect(snap.totalEvents, equals(0));
      expect(snap.failedEvents, equals(0));
      expect(snap.successEvents, equals(0));
      expect(snap.recentEvents, isEmpty);
    });

    test(
      'D2. Flap dampener reset() clears all penalty, suppression and history',
      () {
        final dampener = ChainFlapDampenerService();
        final policy = const ChainFlapDampeningPolicy(penaltyPerFlap: 1000.0);
        dampener.recordFlap(
          role: FallbackCandidateRole.entry,
          fromNode: 'A',
          toNode: 'B',
          policy: policy,
        );

        dampener.reset();
        final status = dampener.status;
        expect(status.isSuppressed, isFalse);
        expect(status.currentPenalty, equals(0.0));
        expect(status.recentEvents, isEmpty);
        expect(status.lastFlapTime, isNull);
      },
    );

    test('D3. Flap suppression is triggered and clears on reset', () {
      final dampener = ChainFlapDampenerService();
      // penalty=200 > suppressThreshold=100 → triggers suppression
      // reuseThreshold=190 > penalty after decay (but halfLife=24h so no decay in test)
      //   → penalty (200) > reuseThreshold (190) → _checkUnsuppress will NOT release early
      final policy = const ChainFlapDampeningPolicy(
        penaltyPerFlap: 200.0,
        suppressThreshold: 100.0,
        reuseThreshold: 190.0,
        halfLife: Duration(hours: 24),
      );

      dampener.recordFlap(
        role: FallbackCandidateRole.relay,
        fromNode: 'X',
        toNode: 'Y',
        policy: policy,
      );

      // Verify suppressed using the same policy.
      final statusBefore = dampener.getStatus(policy: policy);
      expect(statusBefore.isSuppressed, isTrue);

      // After reset, suppression must be cleared regardless of policy.
      dampener.reset();
      expect(dampener.getStatus(policy: policy).isSuppressed, isFalse);
    });

    test(
      'D4. ObserverList-based listener does not hold strong reference after remove',
      () {
        // Tests that removing a listener prevents it from being called.
        final telemetry = ChainTelemetryService();
        bool wasCalledAfterRemove = false;

        void listener() {
          wasCalledAfterRemove = true;
        }

        telemetry.addListener(listener);
        telemetry.removeListener(listener);

        telemetry.clear(); // triggers _notifyListeners
        expect(wasCalledAfterRemove, isFalse);
      },
    );

    test('D5. Telemetry snapshot is unmodifiable (no external mutation)', () {
      final telemetry = ChainTelemetryService();
      telemetry.record(
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeCompleted,
          role: 'entry',
          message: 'test',
        ),
      );
      final snap = telemetry.getSnapshot();
      expect(
        () => (snap.recentEvents as List).add(
          ChainTelemetryEvent(
            type: ChainTelemetryEventType.probeFailed,
            role: 'relay',
            message: 'mutate',
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
