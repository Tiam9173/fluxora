import 'package:flutter/foundation.dart';
import 'package:fluxora/models/chain_diagnostic_report.dart';

enum ChainSupportSection {
  summary,
  telemetry,
  intelligence,
  insight,
  decision,
  recoveryHistory,
}

@immutable
class ChainSupportPackage {
  final String id;
  final DateTime createdAt;
  final String appVersion;
  final String platform;
  final ChainDiagnosticReport diagnostic;
  final List<ChainSupportSection> includedSections;
  final int sizeEstimate;
  final String? zipFilePath;

  const ChainSupportPackage({
    required this.id,
    required this.createdAt,
    required this.appVersion,
    required this.platform,
    required this.diagnostic,
    required this.includedSections,
    required this.sizeEstimate,
    this.zipFilePath,
  });

  ChainSupportPackage copyWith({String? zipFilePath}) {
    return ChainSupportPackage(
      id: id,
      createdAt: createdAt,
      appVersion: appVersion,
      platform: platform,
      diagnostic: diagnostic,
      includedSections: includedSections,
      sizeEstimate: sizeEstimate,
      zipFilePath: zipFilePath ?? this.zipFilePath,
    );
  }
}
