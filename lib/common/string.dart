import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'app_localizations.dart';
import 'print.dart';

extension StringExtension on String {
  bool get isUrl {
    return RegExp(r'^(http|https|ftp)://').hasMatch(this);
  }

  /// A user-facing web link: http/https only, no embedded credentials, and
  /// bounded so a pasted blob cannot reach the launcher.
  bool get isSafeWebUrl {
    final value = trim();
    if (value.isEmpty || value.length > 2048 || value.contains(RegExp(r'\s'))) {
      return false;
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return false;
    }
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  String? get webUrlHost {
    if (!isSafeWebUrl) return null;
    return Uri.tryParse(trim())?.host.toLowerCase();
  }

  String? get webUrlOrigin {
    if (!isSafeWebUrl) return null;
    return Uri.tryParse(trim())?.origin;
  }

  dynamic get splitByMultipleSeparators {
    final parts = split(
      RegExp(r'[, ;]+'),
    ).where((part) => part.isNotEmpty).toList();

    return parts.length > 1 ? parts : this;
  }

  int compareToLower(String other) {
    return toLowerCase().compareTo(other.toLowerCase());
  }

  List<int> get encodeUtf16LeWithBom {
    final byteData = ByteData(length * 2);
    final bom = [0xFF, 0xFE];
    for (int i = 0; i < length; i++) {
      int charCode = codeUnitAt(i);
      byteData.setUint16(i * 2, charCode, Endian.little);
    }
    return bom + byteData.buffer.asUint8List();
  }

  Uint8List? get getBase64 {
    final regExp = RegExp(r'base64,(.*)');
    final match = regExp.firstMatch(this);
    final realValue = match?.group(1) ?? '';
    if (realValue.isEmpty) {
      return null;
    }
    try {
      return base64.decode(realValue);
    } catch (e) {
      return null;
    }
  }

  bool get isSvg {
    return endsWith('.svg');
  }

  bool get isRegex {
    try {
      RegExp(this);
      return true;
    } catch (e) {
      commonPrint.log(e.toString());
      return false;
    }
  }

  String toMd5() {
    final bytes = utf8.encode(this);
    return md5.convert(bytes).toString();
  }
}

extension StringExtensionSafe on String? {
  String getSafeValue(String defaultValue) {
    return this?.isEmpty != false ? defaultValue : this!;
  }
}

extension ObjectExtension on Object {
  String get formatError => _format(isLog: false);

  String get formatErrorLog => _format(isLog: true);

  String _format({required bool isLog}) {
    final errorStr = toString();
    if (errorStr.contains('DioException [bad response]') ||
        errorStr.contains('status code of')) {
      final match = RegExp(r'status code of (\d+)').firstMatch(errorStr);
      final statusCode = match?.group(1);
      if (statusCode != null) {
        return isLog
            ? 'Failed to import profile. Please check your network status or try resetting the subscription link ( HTTP error code: $statusCode )'
            : appLocalizations.profileImportFailed(statusCode);
      }
    }
    return errorStr;
  }
}
