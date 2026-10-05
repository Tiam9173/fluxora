import 'package:fluxora/manager/chain_proxy_manager.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/models/chain_recovery.dart';
import 'package:fluxora/models/chain_support_package.dart';
import 'package:fluxora/services/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final chainProxyConfigProvider = ChangeNotifierProvider<ChainProxyManager>((
  ref,
) {
  return chainProxyManager;
});

final chainProxyDelaysProvider = Provider<Map<String, int?>>((ref) {
  final manager = ref.watch(chainProxyConfigProvider);
  return manager.delays;
});

final chainProxyDelayProvider = Provider.family<int?, String>((ref, proxyId) {
  final delays = ref.watch(chainProxyDelaysProvider);
  return delays[proxyId];
});

final chainProbeReportProvider = Provider<ChainProbeReport?>((ref) {
  final manager = ref.watch(chainProxyConfigProvider);
  return manager.lastProbeReport;
});

final isProbingChainProvider = Provider<bool>((ref) {
  final manager = ref.watch(chainProxyConfigProvider);
  return manager.isProbingChain;
});

final chainFailoverProgressProvider = Provider<ChainFailoverProgress?>((ref) {
  final manager = ref.watch(chainProxyConfigProvider);
  return manager.failoverProgress;
});

final isFailingOverProvider = Provider<bool>((ref) {
  final manager = ref.watch(chainProxyConfigProvider);
  return manager.isFailingOver;
});

final chainFlapDampenerStatusProvider = Provider<ChainFlapDampenerStatus>((
  ref,
) {
  final manager = ref.watch(chainProxyConfigProvider);
  return manager.flapDampenerStatus;
});

final chainTelemetryProvider = Provider<ChainTelemetrySnapshot>((ref) {
  final manager = ref.watch(chainProxyConfigProvider);
  return manager.telemetrySnapshot;
});

final chainRecoveryProvider = Provider<ChainRecoveryPlan?>((ref) {
  final manager = ref.watch(chainProxyConfigProvider);
  return manager.pendingRecoveryPlan;
});

final chainDiagnosticExporterProvider = Provider<ChainProxyManager>((ref) {
  return ref.watch(chainProxyConfigProvider);
});

final chainSupportPackageProvider = Provider<ChainSupportPackage?>((ref) {
  return ref.watch(chainProxyConfigProvider).lastGeneratedPackage;
});
