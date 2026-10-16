// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../network_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NetworkInfo {

/// `Wi-Fi` · `Ethernet` · `Cellular`, or `''` when unknown.
 String get type; String get interfaceName; String get ip; String get gateway; List<String> get dns;
/// Create a copy of NetworkInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NetworkInfoCopyWith<NetworkInfo> get copyWith => _$NetworkInfoCopyWithImpl<NetworkInfo>(this as NetworkInfo, _$identity);

  /// Serializes this NetworkInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as NetworkInfo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NetworkInfo&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.interfaceName, _this.interfaceName) || other.interfaceName == _this.interfaceName)&&(identical(other.ip, _this.ip) || other.ip == _this.ip)&&(identical(other.gateway, _this.gateway) || other.gateway == _this.gateway)&&const DeepCollectionEquality().equals(other.dns, _this.dns));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as NetworkInfo;
  return Object.hash(runtimeType,_this.type,_this.interfaceName,_this.ip,_this.gateway,const DeepCollectionEquality().hash(_this.dns));
}

@override
String toString() {
  final _this = this as NetworkInfo;
  return 'NetworkInfo(type: ${_this.type}, interfaceName: ${_this.interfaceName}, ip: ${_this.ip}, gateway: ${_this.gateway}, dns: ${_this.dns})';
}


}

/// @nodoc
abstract mixin class $NetworkInfoCopyWith<$Res>  {
  factory $NetworkInfoCopyWith(NetworkInfo value, $Res Function(NetworkInfo) _then) = _$NetworkInfoCopyWithImpl;
@useResult
$Res call({
 String type, String interfaceName, String ip, String gateway, List<String> dns
});




}
/// @nodoc
class _$NetworkInfoCopyWithImpl<$Res>
    implements $NetworkInfoCopyWith<$Res> {
  _$NetworkInfoCopyWithImpl(this._self, this._then);

  final NetworkInfo _self;
  final $Res Function(NetworkInfo) _then;

/// Create a copy of NetworkInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? interfaceName = null,Object? ip = null,Object? gateway = null,Object? dns = null,}) {
  return _then(NetworkInfo(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,interfaceName: null == interfaceName ? _self.interfaceName : interfaceName // ignore: cast_nullable_to_non_nullable
as String,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,gateway: null == gateway ? _self.gateway : gateway // ignore: cast_nullable_to_non_nullable
as String,dns: null == dns ? _self.dns : dns // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [NetworkInfo].
extension NetworkInfoPatterns on NetworkInfo {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NetworkInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NetworkInfo() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NetworkInfo value)  $default,){
final _that = this;
switch (_that) {
case _NetworkInfo():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NetworkInfo value)?  $default,){
final _that = this;
switch (_that) {
case _NetworkInfo() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  String interfaceName,  String ip,  String gateway,  List<String> dns)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NetworkInfo() when $default != null:
return $default(_that.type,_that.interfaceName,_that.ip,_that.gateway,_that.dns);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  String interfaceName,  String ip,  String gateway,  List<String> dns)  $default,) {final _that = this;
switch (_that) {
case _NetworkInfo():
return $default(_that.type,_that.interfaceName,_that.ip,_that.gateway,_that.dns);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  String interfaceName,  String ip,  String gateway,  List<String> dns)?  $default,) {final _that = this;
switch (_that) {
case _NetworkInfo() when $default != null:
return $default(_that.type,_that.interfaceName,_that.ip,_that.gateway,_that.dns);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NetworkInfo implements NetworkInfo {
  const _NetworkInfo({this.type = '', this.interfaceName = '', this.ip = '', this.gateway = '',  List<String> dns = const []}): _dns = dns;
  factory _NetworkInfo.fromJson(Map<String, dynamic> json) => _$NetworkInfoFromJson(json);

/// `Wi-Fi` · `Ethernet` · `Cellular`, or `''` when unknown.
@override@JsonKey() final  String type;
@override@JsonKey() final  String interfaceName;
@override@JsonKey() final  String ip;
@override@JsonKey() final  String gateway;
 final  List<String> _dns;
@override@JsonKey() List<String> get dns {
  if (_dns is EqualUnmodifiableListView) return _dns;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_dns);
}


/// Create a copy of NetworkInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NetworkInfoCopyWith<_NetworkInfo> get copyWith => __$NetworkInfoCopyWithImpl<_NetworkInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NetworkInfoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _NetworkInfo&&(identical(other.type, type) || other.type == type)&&(identical(other.interfaceName, interfaceName) || other.interfaceName == interfaceName)&&(identical(other.ip, ip) || other.ip == ip)&&(identical(other.gateway, gateway) || other.gateway == gateway)&&const DeepCollectionEquality().equals(other.dns, _dns));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,type,interfaceName,ip,gateway,const DeepCollectionEquality().hash(_dns));
}

@override
String toString() {
    return 'NetworkInfo(type: $type, interfaceName: $interfaceName, ip: $ip, gateway: $gateway, dns: $dns)';
}


}

/// @nodoc
abstract mixin class _$NetworkInfoCopyWith<$Res> implements $NetworkInfoCopyWith<$Res> {
  factory _$NetworkInfoCopyWith(_NetworkInfo value, $Res Function(_NetworkInfo) _then) = __$NetworkInfoCopyWithImpl;
@override @useResult
$Res call({
 String type, String interfaceName, String ip, String gateway, List<String> dns
});




}
/// @nodoc
class __$NetworkInfoCopyWithImpl<$Res>
    implements _$NetworkInfoCopyWith<$Res> {
  __$NetworkInfoCopyWithImpl(this._self, this._then);

  final _NetworkInfo _self;
  final $Res Function(_NetworkInfo) _then;

/// Create a copy of NetworkInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? interfaceName = null,Object? ip = null,Object? gateway = null,Object? dns = null,}) {
  return _then(_NetworkInfo(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,interfaceName: null == interfaceName ? _self.interfaceName : interfaceName // ignore: cast_nullable_to_non_nullable
as String,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,gateway: null == gateway ? _self.gateway : gateway // ignore: cast_nullable_to_non_nullable
as String,dns: null == dns ? _self._dns : dns // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
