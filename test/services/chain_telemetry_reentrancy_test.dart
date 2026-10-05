import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/services/chain_telemetry_service.dart';
import 'package:fluxora/models/chain_telemetry.dart';

void main() {
  group('ChainTelemetryService Re-entrancy & Control Flow Proofs', () {
    test('Case A: listener does not call record (Baseline)', () {
      final service = ChainTelemetryService();
      int notifyCount = 0;
      service.addListener(() {
        notifyCount++;
      });
      service.record(
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeStarted,
          role: 'entry',
          message: 'A',
        ),
      );
      expect(notifyCount, 1);
    });

    test('Case B: listener synchronously calls record ONCE', () {
      final service = ChainTelemetryService();
      int notifyCount = 0;
      bool hasReentered = false;

      service.addListener(() {
        notifyCount++;
        if (!hasReentered) {
          hasReentered = true;
          service.record(
            ChainTelemetryEvent(
              type: ChainTelemetryEventType.probeCompleted,
              role: 'entry',
              message: 'B_reentry',
            ),
          );
        }
      });

      service.record(
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeStarted,
          role: 'entry',
          message: 'B_initial',
        ),
      );

      // Expected behavior:
      // 1. Initial record calls notifyListeners.
      // 2. notifyCount becomes 1. Listener calls record.
      // 3. Inner record processes event, sets _hasPendingNotifications = true, returns.
      // 4. Outer notifyListeners loop repeats.
      // 5. notifyCount becomes 2. hasReentered is true, no more records.
      // 6. Loop terminates.
      expect(notifyCount, 2);
      expect(service.getSnapshot().totalEvents, 2);
    });

    test(
      'Case C: listener unconditionally calls record EVERY TIME (Simulated Infinite)',
      () {
        final service = ChainTelemetryService();
        int notifyCount = 0;

        service.addListener(() {
          notifyCount++;
          // To prevent actual infinite loop hanging the test suite, we cap it at 10.
          // But mathematically, if we didn't cap it, it would run forever.
          if (notifyCount < 10) {
            service.record(
              ChainTelemetryEvent(
                type: ChainTelemetryEventType.probeStarted,
                role: 'entry',
                message: 'C_infinite_$notifyCount',
              ),
            );
          }
        });

        service.record(
          ChainTelemetryEvent(
            type: ChainTelemetryEventType.probeStarted,
            role: 'entry',
            message: 'C_initial',
          ),
        );

        expect(notifyCount, 10);
        expect(service.getSnapshot().totalEvents, 10);
      },
    );

    test('Case D: listener batch records 10 events synchronously', () {
      final service = ChainTelemetryService();
      int notifyCount = 0;
      bool hasBatched = false;

      service.addListener(() {
        notifyCount++;
        if (!hasBatched) {
          hasBatched = true;
          for (int i = 0; i < 10; i++) {
            service.record(
              ChainTelemetryEvent(
                type: ChainTelemetryEventType.probeCompleted,
                role: 'entry',
                message: 'D_batch_$i',
              ),
            );
          }
        }
      });

      service.record(
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeStarted,
          role: 'entry',
          message: 'D_initial',
        ),
      );

      // Expected:
      // Loop 1: notifyCount=1, batches 10 records.
      // Each inner record sets _hasPendingNotifications=true.
      // Loop 1 finishes, sees pending=true, repeats.
      // Loop 2: notifyCount=2, no more batches.
      // Finishes.
      expect(notifyCount, 2);
      expect(service.getSnapshot().totalEvents, 11);
    });

    test('Case E: two listeners triggering each other (ping-pong)', () {
      final service = ChainTelemetryService();
      int pingCount = 0;
      int pongCount = 0;

      service.addListener(() {
        // Ping
        if (pingCount < 5) {
          pingCount++;
          service.record(
            ChainTelemetryEvent(
              type: ChainTelemetryEventType.probeStarted,
              role: 'entry',
              message: 'Ping_$pingCount',
            ),
          );
        }
      });

      service.addListener(() {
        // Pong
        if (pongCount < 5) {
          pongCount++;
          service.record(
            ChainTelemetryEvent(
              type: ChainTelemetryEventType.probeCompleted,
              role: 'entry',
              message: 'Pong_$pongCount',
            ),
          );
        }
      });

      service.record(
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeStarted,
          role: 'entry',
          message: 'Initial',
        ),
      );

      expect(pingCount, 5);
      expect(pongCount, 5);
      expect(
        service.getSnapshot().totalEvents,
        11,
      ); // Initial + 5 Pings + 5 Pongs
    });

    test('Case F: 1000 event burst from single source', () {
      final service = ChainTelemetryService();
      int notifyCount = 0;

      service.addListener(() {
        notifyCount++;
      });

      for (int i = 0; i < 1000; i++) {
        service.record(
          ChainTelemetryEvent(
            type: ChainTelemetryEventType.probeStarted,
            role: 'entry',
            message: 'Burst_$i',
          ),
        );
      }

      // Each top-level record() call completes notifyListeners fully.
      expect(notifyCount, 1000);
      expect(service.getSnapshot().totalEvents, 1000);
      expect(
        service.getSnapshot().recentEvents.length,
        ChainTelemetryService.maxEvents,
      );
    });

    test('Exception Safety: Listener throws exception', () {
      final service = ChainTelemetryService();
      int listener1Count = 0;
      int listener3Count = 0;

      service.addListener(() {
        listener1Count++;
      });

      service.addListener(() {
        throw Exception('Listener 2 died');
      });

      service.addListener(() {
        listener3Count++;
      });

      service.record(
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeStarted,
          role: 'entry',
          message: 'Exception_Test',
        ),
      );

      // The exception in listener 2 should be caught, and listener 3 should still fire.
      expect(listener1Count, 1);
      expect(listener3Count, 1);

      // The service should still be functional.
      service.record(
        ChainTelemetryEvent(
          type: ChainTelemetryEventType.probeCompleted,
          role: 'entry',
          message: 'Exception_Test_2',
        ),
      );

      expect(listener1Count, 2);
      expect(listener3Count, 2);
      expect(service.getSnapshot().totalEvents, 2);
    });
  });
}
