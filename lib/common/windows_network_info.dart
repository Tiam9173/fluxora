import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:fluxora/models/network_info.dart';
import 'package:win32/win32.dart';

/// Reads the address, gateway and resolvers from the same Windows adapter.
NetworkInfo readWindowsNetworkInfo() => using((arena) {
  const afUnspec = 0;
  const flags =
      GAA_FLAG_INCLUDE_GATEWAYS |
      GAA_FLAG_SKIP_ANYCAST |
      GAA_FLAG_SKIP_MULTICAST;
  final size = arena<Uint32>()..value = 15 * 1024;
  final virtualName = RegExp(
    'tun|tap|vpn|clash|mihomo|wireguard',
    caseSensitive: false,
  );
  for (var attempt = 0; attempt < 3; attempt++) {
    final adapters = arena<Uint8>(size.value).cast<IP_ADAPTER_ADDRESSES_LH>();
    final result = GetAdaptersAddresses(
      afUnspec,
      flags,
      nullptr,
      adapters,
      size,
    );
    if (result == ERROR_BUFFER_OVERFLOW) continue;
    if (result != NO_ERROR) break;

    ({NetworkInfo info, int metric})? best;
    NetworkInfo? localOnly;
    // Windows 10+ returns adapters ordered by the system's route metrics.
    for (var cursor = adapters; cursor != nullptr; cursor = cursor.ref.Next) {
      final adapter = cursor.ref;
      if (adapter.OperStatus != IfOperStatusUp ||
          adapter.IfType == 24 || // Software loopback.
          adapter.IfType == 131) {
        // Tunnel.
        continue;
      }
      final name = adapter.FriendlyName == nullptr
          ? ''
          : adapter.FriendlyName.toDartString();
      if (virtualName.hasMatch(name)) continue;

      InternetAddress? ip;
      for (
        var item = adapter.FirstUnicastAddress;
        item != nullptr;
        item = item.ref.Next
      ) {
        final address = _readAddress(item.ref.Address);
        if (address == null || address.isLinkLocal) continue;
        ip ??= address;
        if (address.type == InternetAddressType.IPv4) {
          ip = address;
          break;
        }
      }
      if (ip == null) continue;

      InternetAddress? gateway;
      for (
        var item = adapter.FirstGatewayAddress;
        item != nullptr;
        item = item.ref.Next
      ) {
        final address = _readAddress(item.ref.Address);
        if (address == null) continue;
        gateway ??= address;
        if (address.type == ip.type) {
          gateway = address;
          break;
        }
      }
      final dns = <String>{};
      for (
        var item = adapter.FirstDnsServerAddress;
        item != nullptr;
        item = item.ref.Next
      ) {
        final address = _readAddress(item.ref.Address);
        if (address != null) dns.add(address.address);
      }
      final info = NetworkInfo(
        type: switch (adapter.IfType) {
          6 => 'Ethernet',
          71 => 'Wi-Fi',
          243 || 244 => 'Cellular',
          _ => '',
        },
        interfaceName: name,
        ip: ip.address,
        gateway: gateway?.address ?? '',
        dns: dns.toList(),
      );
      final routeMetric = ip.type == InternetAddressType.IPv4
          ? adapter.Ipv4Metric
          : adapter.Ipv6Metric;
      if (gateway != null && (best == null || routeMetric < best.metric)) {
        best = (info: info, metric: routeMetric);
      }
      localOnly ??= info;
    }
    return best?.info ?? localOnly ?? const NetworkInfo();
  }
  return const NetworkInfo();
});

InternetAddress? _readAddress(SOCKET_ADDRESS socket) {
  final pointer = socket.lpSockaddr;
  if (pointer == nullptr || socket.iSockaddrLength < 2) return null;
  // Offsets of sin_addr and sin6_addr in the WinSock structures.
  final (offset, length) = switch (pointer.ref.sa_family) {
    2 => (4, 4),
    23 => (8, 16),
    _ => (0, 0),
  };
  if (length == 0 || socket.iSockaddrLength < offset + length) return null;
  final bytes = (pointer.cast<Uint8>() + offset).asTypedList(length);
  if (bytes.every((byte) => byte == 0)) return null;
  final address = InternetAddress.fromRawAddress(bytes);
  if (address.isLoopback ||
      (length == 4 && bytes[0] == 198 && (bytes[1] == 18 || bytes[1] == 19))) {
    return null;
  }
  return address;
}
