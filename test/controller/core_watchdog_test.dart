import 'package:fluxora/controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('core watchdog', () {
    test('one dead tick is not enough', () {
      // 内核启动/重启的瞬间 hasLiveProcess 会短暂为 false，一拍就动手会
      // 变成自己打断自己。
      expect(
        AppController.coreWatchdogWantsRestart(deadTicks: 1, attempts: 0),
        isFalse,
      );
    });

    test('two dead ticks trigger the first restart', () {
      expect(
        AppController.coreWatchdogWantsRestart(deadTicks: 2, attempts: 0),
        isTrue,
      );
    });

    test('it keeps retrying up to the backoff length', () {
      expect(
        AppController.coreWatchdogWantsRestart(deadTicks: 2, attempts: 2),
        isTrue,
      );
    });

    test('it gives up after the backoff is exhausted', () {
      // 三档退避用完之后不再无限重启，交给用户处理。
      expect(
        AppController.coreWatchdogWantsRestart(deadTicks: 2, attempts: 3),
        isFalse,
      );
      expect(
        AppController.coreWatchdogWantsRestart(deadTicks: 2, attempts: 9),
        isFalse,
      );
    });
  });
}
