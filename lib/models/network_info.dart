import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/network_info.freezed.dart';
part 'generated/network_info.g.dart';

/// item 6 (Bettbox 1.19.4 alignment) — the device's local (LAN) network details.
///
/// Filled by `utils.getNetworkInfo()`:
/// * **desktop** — pure Dart: the default route is parsed from the routing
///   table (`/proc/net/route` on Linux, `route -n get default` on macOS,
///   `Get-NetRoute` on Windows), the address comes from `NetworkInterface.list`
///   and the resolvers from the existing `_getSystemDns()`;
/// * **Android** — a `MethodChannel('service')` call, because neither
///   `NetworkInterface.list` nor `connectivity_plus` exposes a gateway there.
///
/// Every field is a defaulted `String` / `List`, so a failed lookup yields an
/// **empty** report rather than throwing — the UI shows "-" for anything missing
/// and never claims a value it does not have.
@freezed
abstract class NetworkInfo with _$NetworkInfo {
  const factory NetworkInfo({
    /// `Wi-Fi` · `Ethernet` · `Cellular`, or `''` when unknown.
    @Default('') String type,
    @Default('') String interfaceName,
    @Default('') String ip,
    @Default('') String gateway,
    @Default([]) List<String> dns,
  }) = _NetworkInfo;

  factory NetworkInfo.fromJson(Map<String, Object?> json) =>
      _$NetworkInfoFromJson(json);
}
