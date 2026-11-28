import 'dart:io';

import 'package:fluxora/common/windows_network_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows adapter information contains only valid addresses', () {
    if (!Platform.isWindows) return;

    final info = readWindowsNetworkInfo();
    expect(
      info.ip.isEmpty || InternetAddress.tryParse(info.ip) != null,
      isTrue,
    );
    expect(
      info.gateway.isEmpty || InternetAddress.tryParse(info.gateway) != null,
      isTrue,
    );
    expect(
      info.dns.every((address) => InternetAddress.tryParse(address) != null),
      isTrue,
    );
  });
}
