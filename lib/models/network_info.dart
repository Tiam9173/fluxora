import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/network_info.freezed.dart';
part 'generated/network_info.g.dart';

/// item 6 (Bettbox 1.19.4 alignment) — the device's local (LAN) network details.
///
/// Filled by `utils.getNetworkInfo()`:
/// * **Windows** — IP Helper returns the local address, gateway and resolvers
///   from the same network adapter.
/// * **Linux/macOS** — the default route, local interfaces and system resolver
///   supply the details.
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
