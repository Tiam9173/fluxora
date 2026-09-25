import 'package:fluxora/manager/warp_manager.dart';
import 'package:fluxora/models/warp_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final warpProvider = ChangeNotifierProvider<WarpManager>((ref) {
  return warpManager;
});

final warpConfigProvider = Provider<WarpConfig>((ref) {
  final manager = ref.watch(warpProvider);
  return manager.config;
});

final warpReportProvider = Provider<WarpStatusReport?>((ref) {
  final manager = ref.watch(warpProvider);
  return manager.latestReport;
});
