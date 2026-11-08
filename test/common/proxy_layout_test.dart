import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'node columns adapt to width while retaining the density preference',
    () {
      expect(utils.getProxiesColumns(320, ProxiesLayout.tight), 2);
      expect(utils.getProxiesColumns(390, ProxiesLayout.tight), 3);
      expect(utils.getProxiesColumns(390, ProxiesLayout.standard), 2);
      expect(utils.getProxiesColumns(390, ProxiesLayout.loose), 1);
      for (var width = 80.0; width <= 1600; width += 16) {
        final columns = utils.getProxiesColumns(width, ProxiesLayout.tight);
        expect(columns, greaterThanOrEqualTo(1));
        if (columns > 1) {
          expect(
            (width - 32 - 8 * (columns - 1)) / columns,
            greaterThanOrEqualTo(104),
          );
        }
      }
    },
  );
}
