// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../network_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NetworkInfo _$NetworkInfoFromJson(Map<String, dynamic> json) => _NetworkInfo(
  type: json['type'] as String? ?? '',
  interfaceName: json['interfaceName'] as String? ?? '',
  ip: json['ip'] as String? ?? '',
  gateway: json['gateway'] as String? ?? '',
  dns:
      (json['dns'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$NetworkInfoToJson(_NetworkInfo instance) =>
    <String, dynamic>{
      'type': instance.type,
      'interfaceName': instance.interfaceName,
      'ip': instance.ip,
      'gateway': instance.gateway,
      'dns': instance.dns,
    };
