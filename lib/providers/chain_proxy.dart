import 'package:bett_box/manager/chain_proxy_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final chainProxyConfigProvider =
    ChangeNotifierProvider<ChainProxyManager>((ref) {
  return chainProxyManager;
});

final chainProxyDelaysProvider = Provider<Map<String, int?>>((ref) {
  final manager = ref.watch(chainProxyConfigProvider);
  return manager.delays;
});

final chainProxyDelayProvider =
    Provider.family<int?, String>((ref, proxyId) {
  final delays = ref.watch(chainProxyDelaysProvider);
  return delays[proxyId];
});
