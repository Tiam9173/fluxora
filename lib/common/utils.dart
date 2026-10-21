import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluxora/widgets/fluxora/fluxora_latency_badge.dart';
import 'package:lpinyin/lpinyin.dart';

enum IpCategory {
  tun,
  lan,
  public,
}

class Utils {
  /// Legacy latency colour helper.
  ///
  /// D4.7: delegates to the Fluxora latency semantics
  /// ([FluxoraLatencyBadge.tierOf] + [FluxoraLatencyBadge.colorFor]) so there is
  /// **one** set of thresholds (300 / 800) instead of the old 600 — and so
  /// `delay == 0` (testing) is no longer painted green.
  ///
  /// The signature is unchanged apart from the added optional [brightness], so
  /// existing callers keep compiling. New UI should use
  /// [FluxoraLatencyBadge] directly; the previous sole caller
  /// (`views/proxies/card.dart`) now does.
  Color? getDelayColor(int? delay, {Brightness brightness = Brightness.light}) {
    final tier = FluxoraLatencyBadge.tierOf(delay);
    // Preserve the original "no colour when never tested" behaviour.
    if (tier == FluxoraLatencyTier.untested) return null;
    return FluxoraLatencyBadge.colorFor(brightness, tier);
  }

  String countryCodeToEmoji(String countryCode) {
    final String code = countryCode.toUpperCase();
    if (code.length != 2) {
      return countryCode;
    }
    final int firstLetter = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  static const Map<String, String> _regionToCountryCodeMap = {
    'HKG': 'HK',
    'HKD': 'HK',
    'HONGKONG': 'HK',
    'EASTASIA': 'HK',
    'MFM': 'MO',
    'MAC': 'MO',
    'MOP': 'MO',
    'MACAU': 'MO',
    'TPE': 'TW',
    'TSA': 'TW',
    'KHH': 'TW',
    'TXG': 'TW',
    'TWN': 'TW',
    'NTW': 'TW',
    'TWD': 'TW',
    'TAIPEI': 'TW',
    'TAIWAN': 'TW',
    'NRT': 'JP',
    'HND': 'JP',
    'KIX': 'JP',
    'ITM': 'JP',
    'FUK': 'JP',
    'NGO': 'JP',
    'CTS': 'JP',
    'OKA': 'JP',
    'SDJ': 'JP',
    'HIJ': 'JP',
    'KMQ': 'JP',
    'KOJ': 'JP',
    'FSZ': 'JP',
    'KIJ': 'JP',
    'JPN': 'JP',
    'JPY': 'JP',
    'JAPAN': 'JP',
    'JAPANEAST': 'JP',
    'JAPANWEST': 'JP',
    'TOKYO': 'JP',
    'OSAKA': 'JP',
    'ICN': 'KR',
    'GMP': 'KR',
    'PUS': 'KR',
    'CJU': 'KR',
    'TAE': 'KR',
    'KOR': 'KR',
    'KRW': 'KR',
    'KOREA': 'KR',
    'KOREACENTRAL': 'KR',
    'KOREASOUTH': 'KR',
    'SEOUL': 'KR',
    'SIN': 'SG',
    'SGP': 'SG',
    'SGD': 'SG',
    'SINGAPORE': 'SG',
    'SOUTHEASTASIA': 'SG',
    'KUL': 'MY',
    'JHB': 'MY',
    'BKI': 'MY',
    'KCH': 'MY',
    'PEN': 'MY',
    'MYS': 'MY',
    'MYR': 'MY',
    'THA': 'TH',
    'THB': 'TH',
    'VNM': 'VN',
    'VND': 'VN',
    'IDN': 'ID',
    'IDR': 'ID',
    'PHP': 'PH',
    'GBR': 'GB',
    'GBP': 'GB',
    'DEU': 'DE',
    'EUR': 'EU',
    'CAD': 'CA',
    'AUD': 'AU',
    'CNY': 'CN',
    'MALAYSIA': 'MY',
    'BKK': 'TH',
    'DMK': 'TH',
    'CNX': 'TH',
    'HKT': 'TH',
    'THAILAND': 'TH',
    'HAN': 'VN',
    'SGN': 'VN',
    'DAD': 'VN',
    'VIETNAM': 'VN',
    'MNL': 'PH',
    'CEB': 'PH',
    'CRK': 'PH',
    'PHILIPPINES': 'PH',
    'CGK': 'ID',
    'DPS': 'ID',
    'SUB': 'ID',
    'INDONESIA': 'ID',
    'BOM': 'IN',
    'DEL': 'IN',
    'BLR': 'IN',
    'MAA': 'IN',
    'HYD': 'IN',
    'CCU': 'IN',
    'AMD': 'IN',
    'COK': 'IN',
    'PNQ': 'IN',
    'JAI': 'IN',
    'NAG': 'IN',
    'PAT': 'IN',
    'INDIA': 'IN',
    'CENTRALINDIA': 'IN',
    'SOUTHINDIA': 'IN',
    'WESTINDIA': 'IN',
    'MUMBAI': 'IN',
    'PEK': 'CN',
    'PKX': 'CN',
    'PVG': 'CN',
    'SHA': 'CN',
    'CAN': 'CN',
    'SZX': 'CN',
    'CTU': 'CN',
    'TFU': 'CN',
    'CKG': 'CN',
    'WUH': 'CN',
    'XIY': 'CN',
    'HGH': 'CN',
    'NKG': 'CN',
    'CGO': 'CN',
    'TAO': 'CN',
    'CSX': 'CN',
    'XMN': 'CN',
    'KMG': 'CN',
    'URC': 'CN',
    'TSN': 'CN',
    'DLC': 'CN',
    'SHE': 'CN',
    'CHINA': 'CN',
    'SYD': 'AU',
    'MEL': 'AU',
    'BNE': 'AU',
    'PER': 'AU',
    'ADL': 'AU',
    'CBR': 'AU',
    'HBA': 'AU',
    'DRW': 'AU',
    'CNS': 'AU',
    'OOL': 'AU',
    'AUSTRALIA': 'AU',
    'AUSTRALIAEAST': 'AU',
    'AUSTRALIASOUTHEAST': 'AU',
    'AUSTRALIACENTRAL': 'AU',
    'SYDNEY': 'AU',
    'MELBOURNE': 'AU',
    'AKL': 'NZ',
    'WLG': 'NZ',
    'CHC': 'NZ',
    'NEWZEALAND': 'NZ',
    'LAX': 'US',
    'SFO': 'US',
    'SJC': 'US',
    'SAN': 'US',
    'OAK': 'US',
    'SMF': 'US',
    'BUR': 'US',
    'ONT': 'US',
    'SEA': 'US',
    'PDX': 'US',
    'DFW': 'US',
    'IAH': 'US',
    'AUS': 'US',
    'SAT': 'US',
    'DAL': 'US',
    'HOU': 'US',
    'JFK': 'US',
    'EWR': 'US',
    'LGA': 'US',
    'BUF': 'US',
    'ORD': 'US',
    'MDW': 'US',
    'ATL': 'US',
    'MIA': 'US',
    'MCO': 'US',
    'TPA': 'US',
    'FLL': 'US',
    'JAX': 'US',
    'IAD': 'US',
    'DCA': 'US',
    'BOS': 'US',
    'DEN': 'US',
    'PHX': 'US',
    'LAS': 'US',
    'RNO': 'US',
    'PHL': 'US',
    'PIT': 'US',
    'DTW': 'US',
    'MSP': 'US',
    'CLE': 'US',
    'CMH': 'US',
    'CVG': 'US',
    'CLT': 'US',
    'RDU': 'US',
    'BNA': 'US',
    'MEM': 'US',
    'SLC': 'US',
    'STL': 'US',
    'MCI': 'US',
    'IND': 'US',
    'MKE': 'US',
    'OKC': 'US',
    'TUL': 'US',
    'SDF': 'US',
    'MSY': 'US',
    'ANC': 'US',
    'HNL': 'US',
    'OGG': 'US',
    'OMA': 'US',
    'BOI': 'US',
    'BHM': 'US',
    'USA': 'US',
    'USD': 'US',
    'EASTUS': 'US',
    'EASTUS2': 'US',
    'WESTUS': 'US',
    'WESTUS2': 'US',
    'WESTUS3': 'US',
    'CENTRALUS': 'US',
    'NORTHCENTRALUS': 'US',
    'SOUTHCENTRALUS': 'US',
    'WESTCENTRALUS': 'US',
    'YYZ': 'CA',
    'YVR': 'CA',
    'YUL': 'CA',
    'YYC': 'CA',
    'YEG': 'CA',
    'YOW': 'CA',
    'YWG': 'CA',
    'YHZ': 'CA',
    'CANADA': 'CA',
    'CANADACENTRAL': 'CA',
    'CANADAEAST': 'CA',
    'LHR': 'GB',
    'LGW': 'GB',
    'LCY': 'GB',
    'STN': 'GB',
    'LTN': 'GB',
    'MAN': 'GB',
    'EDI': 'GB',
    'BHX': 'GB',
    'GLA': 'GB',
    'BRS': 'GB',
    'NCL': 'GB',
    'UK': 'GB',
    'UKSOUTH': 'GB',
    'UKWEST': 'GB',
    'LONDON': 'GB',
    'FRA': 'DE',
    'MUC': 'DE',
    'BER': 'DE',
    'TXL': 'DE',
    'HAM': 'DE',
    'DUS': 'DE',
    'STR': 'DE',
    'CGN': 'DE',
    'LEJ': 'DE',
    'NUE': 'DE',
    'HAJ': 'DE',
    'GERMANY': 'DE',
    'GERMANYWESTCENTRAL': 'DE',
    'GERMANYNORTH': 'DE',
    'FRANKFURT': 'DE',
    'CDG': 'FR',
    'ORY': 'FR',
    'MRS': 'FR',
    'LYS': 'FR',
    'NCE': 'FR',
    'TLS': 'FR',
    'BOD': 'FR',
    'FRANCE': 'FR',
    'FRANCECENTRAL': 'FR',
    'FRANCESOUTH': 'FR',
    'PARIS': 'FR',
    'AMS': 'NL',
    'RTM': 'NL',
    'NETHERLANDS': 'NL',
    'WESTEUROPE': 'NL',
    'AMSTERDAM': 'NL',
    'DUB': 'IE',
    'ORK': 'IE',
    'IRELAND': 'IE',
    'NORTHEUROPE': 'IE',
    'ZRH': 'CH',
    'GVA': 'CH',
    'BSL': 'CH',
    'SWITZERLAND': 'CH',
    'SWITZERLANDNORTH': 'CH',
    'SWITZERLANDWEST': 'CH',
    'ZURICH': 'CH',
    'ARN': 'SE',
    'BMA': 'SE',
    'GOT': 'SE',
    'MMX': 'SE',
    'SWEDEN': 'SE',
    'SWEDENCENTRAL': 'SE',
    'STOCKHOLM': 'SE',
    'OSL': 'NO',
    'BGO': 'NO',
    'SVG': 'NO',
    'NORWAY': 'NO',
    'NORWAYEAST': 'NO',
    'NORWAYWEST': 'NO',
    'CPH': 'DK',
    'BLL': 'DK',
    'DENMARK': 'DK',
    'HEL': 'FI',
    'FINLAND': 'FI',
    'KEF': 'IS',
    'ICELAND': 'IS',
    'MXP': 'IT',
    'LIN': 'IT',
    'FCO': 'IT',
    'CIA': 'IT',
    'BLQ': 'IT',
    'NAP': 'IT',
    'VCE': 'IT',
    'ITALY': 'IT',
    'ITALYNORTH': 'IT',
    'MILAN': 'IT',
    'MAD': 'ES',
    'BCN': 'ES',
    'VLC': 'ES',
    'AGP': 'ES',
    'SVQ': 'ES',
    'BIO': 'ES',
    'SPAIN': 'ES',
    'SPAINCENTRAL': 'ES',
    'MADRID': 'ES',
    'LIS': 'PT',
    'OPO': 'PT',
    'FAO': 'PT',
    'PORTUGAL': 'PT',
    'BRU': 'BE',
    'BELGIUM': 'BE',
    'VIE': 'AT',
    'AUSTRIA': 'AT',
    'WAW': 'PL',
    'KRK': 'PL',
    'GDN': 'PL',
    'WRO': 'PL',
    'POLAND': 'PL',
    'POLANDCENTRAL': 'PL',
    'WARSAW': 'PL',
    'PRG': 'CZ',
    'CZECH': 'CZ',
    'BUD': 'HU',
    'HUNGARY': 'HU',
    'OTP': 'RO',
    'CLJ': 'RO',
    'ROMANIA': 'RO',
    'ATH': 'GR',
    'SKG': 'GR',
    'GREECE': 'GR',
    'IST': 'TR',
    'SAW': 'TR',
    'ESB': 'TR',
    'AYT': 'TR',
    'ADB': 'TR',
    'TURKEY': 'TR',
    'TURKIYE': 'TR',
    'KBP': 'UA',
    'IEV': 'UA',
    'ODS': 'UA',
    'UKRAINE': 'UA',
    'SVO': 'RU',
    'DME': 'RU',
    'VKO': 'RU',
    'LED': 'RU',
    'OVB': 'RU',
    'SVX': 'RU',
    'RUSSIA': 'RU',
    'SOF': 'BG',
    'ZAG': 'HR',
    'BTS': 'SK',
    'LJU': 'SI',
    'TLL': 'EE',
    'RIX': 'LV',
    'VNO': 'LT',
    'BEG': 'RS',
    'LCA': 'CY',
    'LUX': 'LU',
    'DXB': 'AE',
    'AUH': 'AE',
    'DWC': 'AE',
    'SHJ': 'AE',
    'UAE': 'AE',
    'UAENORTH': 'AE',
    'UAECENTRAL': 'AE',
    'DUBAI': 'AE',
    'RUH': 'SA',
    'JED': 'SA',
    'DMM': 'SA',
    'SAUDI': 'SA',
    'DOH': 'QA',
    'QATAR': 'QA',
    'TLV': 'IL',
    'ISRAEL': 'IL',
    'ISRAELCENTRAL': 'IL',
    'BAH': 'BH',
    'MCT': 'OM',
    'KWI': 'KW',
    'AMM': 'JO',
    'CAI': 'EG',
    'EGYPT': 'EG',
    'JNB': 'ZA',
    'CPT': 'ZA',
    'DUR': 'ZA',
    'SOUTHAFRICA': 'ZA',
    'SOUTHAFRICANORTH': 'ZA',
    'SOUTHAFRICAWEST': 'ZA',
    'NBO': 'KE',
    'LOS': 'NG',
    'ABV': 'NG',
    'CMN': 'MA',
    'MEX': 'MX',
    'GDL': 'MX',
    'MTY': 'MX',
    'QRO': 'MX',
    'CUN': 'MX',
    'TIJ': 'MX',
    'MEXICO': 'MX',
    'MEXICOCENTRAL': 'MX',
    'GRU': 'BR',
    'GIG': 'BR',
    'BSB': 'BR',
    'CGH': 'BR',
    'SDU': 'BR',
    'CNF': 'BR',
    'POA': 'BR',
    'REC': 'BR',
    'SSA': 'BR',
    'CWB': 'BR',
    'FOR': 'BR',
    'BRAZIL': 'BR',
    'BRAZILSOUTH': 'BR',
    'BRAZILSOUTHEAST': 'BR',
    'EZE': 'AR',
    'AEP': 'AR',
    'COR': 'AR',
    'ARGENTINA': 'AR',
    'SCL': 'CL',
    'CHILE': 'CL',
    'CHILECENTRAL': 'CL',
    'BOG': 'CO',
    'COLOMBIA': 'CO',
    'LIM': 'PE',
    'PERU': 'PE',
    'PTY': 'PA',
    'PANAMA': 'PA',
  };

  String normalizeRegion(String region) {
    final clean = region.trim().toUpperCase();
    final mapped = _regionToCountryCodeMap[clean];
    if (mapped != null) {
      return mapped;
    }
    if (clean.length == 2 && RegExp(r'^[A-Z]{2}$').hasMatch(clean)) {
      return clean;
    }
    return region;
  }

  bool isTunIp(String ip) {
    final address = InternetAddress.tryParse(ip.trim());
    if (address == null) return false;
    if (address.type == InternetAddressType.IPv4) {
      final parts = ip.trim().split('.').map(int.tryParse).toList();
      if (parts.length == 4 && parts.every((p) => p != null)) {
        final p0 = parts[0]!;
        final p1 = parts[1]!;
        final p2 = parts[2]!;
        // 172.19.100.0/24 (TUN Default)
        if (p0 == 172 && p1 == 19 && p2 == 100) return true;
        // 198.51.100.0/24 (TEST-NET-2 / TUN Default legacy)
        if (p0 == 198 && p1 == 51 && p2 == 100) return true;
        // 198.18.0.0/15 (Benchmarking / Fake-IP)
        if (p0 == 198 && (p1 == 18 || p1 == 19)) return true;
      }
    } else if (address.type == InternetAddressType.IPv6) {
      final clean = ip.trim().toLowerCase();
      // fdfe:dcba:9876::/126 (Default TUN IPv6)
      if (clean.startsWith('fdfe:dcba:9876:')) return true;
    }
    return false;
  }

  IpCategory classifyIp(String ip) {
    if (isTunIp(ip)) {
      return IpCategory.tun;
    }
    if (isPrivateOrReservedIp(ip)) {
      return IpCategory.lan;
    }
    return IpCategory.public;
  }

  bool isPrivateOrReservedIp(String ip) {
    final address = InternetAddress.tryParse(ip.trim());
    if (address == null) return false;

    if (address.isLoopback || address.isLinkLocal || address.isMulticast) {
      return true;
    }

    if (address.type == InternetAddressType.IPv4) {
      final parts = ip.trim().split('.').map(int.tryParse).toList();
      if (parts.length == 4 && parts.every((p) => p != null)) {
        final p0 = parts[0]!;
        final p1 = parts[1]!;
        final p2 = parts[2]!;

        // 0.0.0.0/8 (Current network / RFC 1122)
        if (p0 == 0) return true;

        // 10.0.0.0/8 (Private / RFC 1918)
        if (p0 == 10) return true;

        // 100.64.0.0/10 (CGNAT / Shared / RFC 6598: 100.64.0.0 - 100.127.255.255)
        if (p0 == 100 && (p1 >= 64 && p1 <= 127)) return true;

        // 127.0.0.0/8 (Loopback / RFC 1122)
        if (p0 == 127) return true;

        // 169.254.0.0/16 (Link Local / RFC 3927)
        if (p0 == 169 && p1 == 254) return true;

        // 172.16.0.0/12 (Private / RFC 1918: 172.16.0.0 - 172.31.255.255)
        if (p0 == 172 && (p1 >= 16 && p1 <= 31)) return true;

        // 192.0.0.0/24 (IETF Protocol Assignments / RFC 6890)
        if (p0 == 192 && p1 == 0 && p2 == 0) return true;

        // 192.0.2.0/24 (TEST-NET-1 / RFC 5737)
        if (p0 == 192 && p1 == 0 && p2 == 2) return true;

        // 192.88.99.0/24 (6to4 Relay Anycast / RFC 7526)
        if (p0 == 192 && p1 == 88 && p2 == 99) return true;

        // 192.168.0.0/16 (Private / RFC 1918)
        if (p0 == 192 && p1 == 168) return true;

        // 198.18.0.0/15 (Benchmarking / Fake-IP / RFC 2544: 198.18.0.0 - 198.19.255.255)
        if (p0 == 198 && (p1 == 18 || p1 == 19)) return true;

        // 198.51.100.0/24 (TEST-NET-2 / TUN Default / RFC 5737)
        if (p0 == 198 && p1 == 51 && p2 == 100) return true;

        // 203.0.113.0/24 (TEST-NET-3 / RFC 5737)
        if (p0 == 203 && p1 == 0 && p2 == 113) return true;

        // 224.0.0.0/4 (Multicast / RFC 5771)
        if (p0 >= 224 && p0 <= 239) return true;

        // 240.0.0.0/4 (Reserved / RFC 1112)
        if (p0 >= 240) return true;
      }
    } else if (address.type == InternetAddressType.IPv6) {
      final clean = ip.trim().toLowerCase();
      // ::1 (Loopback), :: (Unspecified)
      if (clean == '::1' || clean == '::') return true;
      // fe80::/10 (Link-local)
      if (clean.startsWith('fe8') ||
          clean.startsWith('fe9') ||
          clean.startsWith('fea') ||
          clean.startsWith('feb')) {
        return true;
      }
      // fc00::/7 (Unique Local Address ULA: fc00:: ~ fdff::)
      if (clean.startsWith('fc') || clean.startsWith('fd')) {
        return true;
      }
      // ff00::/8 (Multicast)
      if (clean.startsWith('ff')) {
        return true;
      }
      // 2001:db8::/32 (Documentation)
      if (clean.startsWith('2001:db8:')) {
        return true;
      }
    }

    return false;
  }

  String get id {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = Random();
    final randomStr = String.fromCharCodes(
      List.generate(8, (_) => random.nextInt(26) + 97),
    );
    return '$timestamp$randomStr';
  }

  String getDateStringLast2(int value) {
    var valueRaw = '0$value';
    return valueRaw.substring(valueRaw.length - 2);
  }

  String generateRandomString({int minLength = 10, int maxLength = 100}) {
    const latinChars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();

    int length = minLength + random.nextInt(maxLength - minLength + 1);

    String result = '';
    for (int i = 0; i < length; i++) {
      if (random.nextBool()) {
        result += String.fromCharCode(
          0x4E00 + random.nextInt(0x9FA5 - 0x4E00 + 1),
        );
      } else {
        result += latinChars[random.nextInt(latinChars.length)];
      }
    }

    return result;
  }

  String get uuidV4 {
    final Random random = Random();
    final bytes = List.generate(16, (_) => random.nextInt(256));

    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  String getTimeDifference(DateTime dateTime) {
    var currentDateTime = DateTime.now();
    var difference = currentDateTime.difference(dateTime);
    var inHours = difference.inHours;
    var inMinutes = difference.inMinutes;
    var inSeconds = difference.inSeconds;

    return '${getDateStringLast2(inHours)}:${getDateStringLast2(inMinutes)}:${getDateStringLast2(inSeconds)}';
  }

  String getTimeText(int? timeStamp) {
    if (timeStamp == null) {
      return '00:00:00';
    }
    final diff = timeStamp / 1000;
    final inHours = (diff / 3600).floor();
    if (inHours > 99) {
      return '99:59:59';
    }
    final inMinutes = (diff / 60 % 60).floor();
    final inSeconds = (diff % 60).floor();

    return '${getDateStringLast2(inHours)}:${getDateStringLast2(inMinutes)}:${getDateStringLast2(inSeconds)}';
  }

  Locale getSystemLocale() {
    final platformLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final supportedLocales = AppLocalizations.delegate.supportedLocales;
    
    if (platformLocale.languageCode.toLowerCase() == 'zh') {
      final isTraditional = 
        (platformLocale.countryCode?.toUpperCase() == 'TW') ||
        (platformLocale.countryCode?.toUpperCase() == 'HK') ||
        (platformLocale.countryCode?.toUpperCase() == 'MO') ||
        (platformLocale.scriptCode?.toLowerCase() == 'hant');
      return isTraditional ? const Locale('zh', 'TC') : const Locale('zh', 'CN');
    }
    
    for (final locale in supportedLocales) {
      if (locale.languageCode == platformLocale.languageCode) {
        return locale;
      }
    }
    
    // Fall back to English, not Chinese. An unsupported system language, an
    // unset locale and the POSIX `C` locale must all start in English:
    // AppImageHub runs the AppImage under the `C` locale and rejects a
    // screenshot whose text is not English.
    // https://github.com/AppImage/appimage.github.io/pull/5901
    return const Locale('en');
  }

  Locale? getLocaleForString(String? localString) {
    if (localString == null) return null;
    // "Follow system" is stored as a sentinel, not a real locale string. Return
    // null so every caller falls back to `getSystemLocale()`.
    if (localString == systemLocaleValue) return null;
    var localSplit = localString.split('_');
    if (localSplit.length == 1) {
      return Locale(localSplit[0]);
    }
    if (localSplit.length == 2) {
      return Locale(localSplit[0], localSplit[1]);
    }
    if (localSplit.length == 3) {
      return Locale.fromSubtags(
        languageCode: localSplit[0],
        scriptCode: localSplit[1],
        countryCode: localSplit[2],
      );
    }
    return null;
  }

  int sortByChar(String a, String b) {
    if (a.isEmpty && b.isEmpty) {
      return 0;
    }
    if (a.isEmpty) {
      return -1;
    }
    if (b.isEmpty) {
      return 1;
    }
    final charA = a[0];
    final charB = b[0];

    if (charA == charB) {
      return sortByChar(a.substring(1), b.substring(1));
    } else {
      return charA.compareToLower(charB);
    }
  }

  String getOverwriteLabel(String label) {
    final reg = RegExp(r'\((\d+)\)$');
    final matches = reg.allMatches(label);
    if (matches.isNotEmpty) {
      final match = matches.last;
      final number = int.parse(match[1] ?? '0') + 1;
      return label.replaceFirst(reg, '($number)', label.length - 3 - 1);
    } else {
      return '$label(1)';
    }
  }

  String getTrayIconPath({
    required Brightness brightness,
    bool isStart = false,
    bool invertTrayIcon = false,
  }) {
    if (system.isLinux) {
      return 'assets/images/icon.png';
    }

    if (system.isMacOS && isStart) {
      return 'assets/images/icon_black.png';
    }

    final suffix = system.isWindows ? 'ico' : 'png';

    final darkPath = !isStart
        ? 'assets/images/icon_light.$suffix'
        : 'assets/images/icon_white.$suffix';
    final lightPath = !isStart
        ? 'assets/images/icon.$suffix'
        : 'assets/images/icon_black.$suffix';

    if (invertTrayIcon) {
      return brightness == Brightness.dark ? lightPath : darkPath;
    }

    return brightness == Brightness.dark ? darkPath : lightPath;
  }

  /// 比较两个版本号，按语义化版本规则。
  ///
  /// 支持 `1.2.3`、`1.2.3-rc.4`、`1.2.3+build`：
  ///
  /// * 主版本号逐段比大小；
  /// * 主版本相同时，带预发布标记的**更小**（`1.0.0-rc.1 < 1.0.0`）；
  /// * 预发布标记同名时比其后的数字（`rc.9 < rc.10`）；
  /// * 最后才比 `+build`。
  ///
  /// 旧实现直接 `split('.')` 再 `int.parse(v[2])`，遇到 `1.1.0-rc.11` 会得到
  /// `"0-rc"` 并抛 FormatException。更新检查把这个调用包在 try 里，异常被
  /// 吞掉后整个函数返回 null —— 结果是**所有 RC 版本都永远检测不到新版**。
  int compareVersions(String version1, String version2) {
    final a = _parseVersion(version1);
    final b = _parseVersion(version2);

    for (var i = 0; i < 3; i++) {
      final cmp = a.numbers[i].compareTo(b.numbers[i]);
      if (cmp != 0) return cmp;
    }

    final aPre = a.prerelease;
    final bPre = b.prerelease;
    if (aPre == null && bPre != null) return 1;
    if (aPre != null && bPre == null) return -1;
    if (aPre != null && bPre != null) {
      final byName = aPre.name.compareTo(bPre.name);
      if (byName != 0) return byName;
      final byNumber = aPre.number.compareTo(bPre.number);
      if (byNumber != 0) return byNumber;
    }

    return a.build.compareTo(b.build);
  }

  /// 把 `v1.2.3-rc.4+20261021` 拆成可以比较的三部分。
  ///
  /// 任何一段解析失败都按 0 处理，绝不抛异常：版本号来自远端 release 标题，
  /// 格式不可控，抛一次就会让整个更新检查失效。
  ({List<int> numbers, ({String name, int number})? prerelease, int build})
  _parseVersion(String raw) {
    var text = raw.trim();
    if (text.startsWith('v') || text.startsWith('V')) {
      text = text.substring(1);
    }

    var build = 0;
    final plusIndex = text.indexOf('+');
    if (plusIndex >= 0) {
      build = int.tryParse(text.substring(plusIndex + 1)) ?? 0;
      text = text.substring(0, plusIndex);
    }

    ({String name, int number})? prerelease;
    final dashIndex = text.indexOf('-');
    if (dashIndex >= 0) {
      final pre = text.substring(dashIndex + 1);
      text = text.substring(0, dashIndex);
      final dotIndex = pre.indexOf('.');
      final name = dotIndex >= 0 ? pre.substring(0, dotIndex) : pre;
      final number = dotIndex >= 0
          ? (int.tryParse(pre.substring(dotIndex + 1)) ?? 0)
          : 0;
      prerelease = (name: name.toLowerCase(), number: number);
    }

    final parts = text.split('.');
    final numbers = List<int>.generate(
      3,
      (i) => i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0,
    );

    return (numbers: numbers, prerelease: prerelease, build: build);
  }

  String getPinyin(String value) {
    return value.isNotEmpty
        ? PinyinHelper.getFirstWordPinyin(value.substring(0, 1))
        : '';
  }

  String? getFileNameForDisposition(String? disposition) {
    if (disposition == null) return null;
    final parseValue = HeaderValue.parse(disposition);
    final parameters = parseValue.parameters;
    final fileNamePointKey = parameters.keys.firstWhere(
      (key) => key == 'filename*',
      orElse: () => '',
    );
    if (fileNamePointKey.isNotEmpty) {
      final res = parameters[fileNamePointKey]?.split("''") ?? [];
      if (res.length >= 2) {
        return Uri.decodeComponent(res[1]);
      }
    }
    final fileNameKey = parameters.keys.firstWhere(
      (key) => key == 'filename',
      orElse: () => '',
    );
    if (fileNameKey.isEmpty) return null;
    return parameters[fileNameKey];
  }

  FlutterView getScreen() {
    return WidgetsBinding.instance.platformDispatcher.views.first;
  }

  List<String> parseReleaseBody(String? body) {
    if (body == null) return [];
    const pattern = r'^\s*-\s+(.+)';
    final regex = RegExp(pattern, multiLine: true);
    return regex
        .allMatches(body)
        .map((match) => match.group(1)?.trim() ?? '')
        .where((item) =>
            item.isNotEmpty &&
            !item.startsWith('---') &&
            !item.startsWith(':') &&
            !item.startsWith('|') &&
            !item.startsWith('['))
        .toList();
  }

  ViewMode getViewMode(double viewWidth) {
    if (viewWidth <= maxMobileWidth) return ViewMode.mobile;
    if (viewWidth <= maxLaptopWidth) return ViewMode.laptop;
    return ViewMode.desktop;
  }

  int getProxiesColumns(double viewWidth, ProxiesLayout proxiesLayout) {
    final columns = max((viewWidth / 300).ceil(), 2);
    return switch (proxiesLayout) {
      ProxiesLayout.tight => columns + 1,
      ProxiesLayout.standard => columns,
      ProxiesLayout.loose => columns - 1,
    };
  }

  int getProfilesColumns(double viewWidth) {
    return min(max((viewWidth / 320).floor(), 1), 3);
  }

  final _indexPrimary = [50, 100, 200, 300, 400, 500, 600, 700, 800, 850, 900];

  MaterialColor _createPrimarySwatch(Color color) {
    final Map<int, Color> swatch = <int, Color>{};
    final int a = color.alpha8bit;
    final int r = color.red8bit;
    final int g = color.green8bit;
    final int b = color.blue8bit;
    for (final int strength in _indexPrimary) {
      final double ds = 0.5 - strength / 1000;
      swatch[strength] = Color.fromARGB(
        a,
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      );
    }
    swatch[50] = swatch[50]!.lighten(18);
    swatch[100] = swatch[100]!.lighten(16);
    swatch[200] = swatch[200]!.lighten(14);
    swatch[300] = swatch[300]!.lighten(10);
    swatch[400] = swatch[400]!.lighten(6);
    swatch[700] = swatch[700]!.darken(2);
    swatch[800] = swatch[800]!.darken(3);
    swatch[900] = swatch[900]!.darken(4);
    return MaterialColor(color.value32bit, swatch);
  }

  List<Color> getMaterialColorShades(Color color) {
    final swatch = _createPrimarySwatch(color);
    return <Color>[
      if (swatch[50] != null) swatch[50]!,
      if (swatch[100] != null) swatch[100]!,
      if (swatch[200] != null) swatch[200]!,
      if (swatch[300] != null) swatch[300]!,
      if (swatch[400] != null) swatch[400]!,
      if (swatch[500] != null) swatch[500]!,
      if (swatch[600] != null) swatch[600]!,
      if (swatch[700] != null) swatch[700]!,
      if (swatch[800] != null) swatch[800]!,
      if (swatch[850] != null) swatch[850]!,
      if (swatch[900] != null) swatch[900]!,
    ];
  }

  String getBackupFileName() {
    return '${appName}_backup_${DateTime.now().show}.zip';
  }

  String get logFile {
    return '${appName}_${DateTime.now().show}.log';
  }

  Future<String?> getLocalIpAddress() async {
    List<NetworkInterface> interfaces =
        await NetworkInterface.list(includeLoopback: false)
          ..sort((a, b) {
            if (a.isWifi && !b.isWifi) return -1;
            if (!a.isWifi && b.isWifi) return 1;
            if (a.includesIPv4 && !b.includesIPv4) return -1;
            if (!a.includesIPv4 && b.includesIPv4) return 1;
            return 0;
          });
    for (final interface in interfaces) {
      final nameLower = interface.name.toLowerCase();
      if (nameLower.contains('tun') ||
          nameLower.contains('vpn') ||
          nameLower.contains('tap') ||
          nameLower.contains('ppp')) {
        continue;
      }
      final addresses = interface.addresses;
      if (addresses.isEmpty) {
        continue;
      }
      addresses.sort((a, b) {
        if (a.isIPv4 && !b.isIPv4) return -1;
        if (!a.isIPv4 && b.isIPv4) return 1;
        return 0;
      });
      return addresses.first.address;
    }
    return '';
  }

  /// Every default route, gateway **and** interface name.
  ///
  /// [getLocalGateways] is the gateway-only view of the same data — it stays a
  /// `List<String>` because five call sites (including two Android
  /// `MethodChannel` wrappers) depend on that shape.
  Future<List<({String gateway, String interfaceName})>> _getDefaultRoutes() async {
    if (Platform.isLinux) {
      return _getLinuxDefaultRoutes();
    }
    if (Platform.isMacOS) {
      return _getMacOSDefaultRoutes();
    }
    if (Platform.isWindows) {
      return _getWindowsDefaultRoutes();
    }
    return [];
  }

  Future<List<String>> getLocalGateways() async {
    final routes = await _getDefaultRoutes();
    return routes.map((route) => route.gateway).toList();
  }

  Future<List<({String gateway, String interfaceName})>>
  _getLinuxDefaultRoutes() async {
    try {
      final routeFile = File('/proc/net/route');
      if (!await routeFile.exists()) return [];

      final lines = await routeFile.readAsLines();
      final routes = <({String gateway, String interfaceName})>[];
      // Header: Iface Destination Gateway Flags RefCnt Use Metric Mask ...
      for (final line in lines.skip(1)) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length < 3) continue;
        if (parts[1] != '00000000') continue; // default route destination
        final gwHex = parts[2];
        if (gwHex == '00000000') continue; // no gateway
        // /proc/net/route stores IPv4 in little-endian hex
        final bytes = [
          int.parse(gwHex.substring(6, 8), radix: 16),
          int.parse(gwHex.substring(4, 6), radix: 16),
          int.parse(gwHex.substring(2, 4), radix: 16),
          int.parse(gwHex.substring(0, 2), radix: 16),
        ];
        routes.add((gateway: bytes.join('.'), interfaceName: parts[0]));
      }
      return routes;
    } catch (e) {
      commonPrint.log('Smart Auto Stop: Linux gateway error: $e');
      return [];
    }
  }

  Future<List<({String gateway, String interfaceName})>>
  _getMacOSDefaultRoutes() async {
    try {
      final result = await Process.run('route', ['-n', 'get', 'default']);
      if (result.exitCode != 0) return [];

      var gateway = '';
      var interfaceName = '';
      final stdout = result.stdout.toString();
      for (final line in stdout.split('\n')) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('gateway:')) continue;
        final value = trimmed.substring('gateway:'.length).trim();
        // Exclude IPv6/link-local gateways
        if (value.isNotEmpty && !value.contains(':')) {
          gateway = value;
          break;
        }
      }
      if (gateway.isEmpty) return [];
      for (final line in stdout.split('\n')) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('interface:')) continue;
        interfaceName = trimmed.substring('interface:'.length).trim();
      }
      return [(gateway: gateway, interfaceName: interfaceName)];
    } catch (e) {
      commonPrint.log('Smart Auto Stop: macOS gateway error: $e');
      return [];
    }
  }

  Future<List<({String gateway, String interfaceName})>>
  _getWindowsDefaultRoutes() async {
    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          'Get-NetRoute -DestinationPrefix \'0.0.0.0/0\' '
              r'| ForEach-Object { "$($_.NextHop)|$($_.InterfaceAlias)" }',
        ],
      );
      if (result.exitCode != 0) return [];

      final routes = <({String gateway, String interfaceName})>[];
      for (final line in result.stdout.toString().split('\n')) {
        final parts = line.trim().split('|');
        final gateway = parts.first;
        if (gateway.isEmpty) continue;
        if (!RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(gateway)) continue;
        routes.add((gateway: gateway, interfaceName: parts.skip(1).join('|')));
      }
      return routes;
    } catch (e) {
      commonPrint.log('Smart Auto Stop: Windows gateway error: $e');
      return [];
    }
  }

  /// item 6 — the LAN detail behind the "intranet IP" card.
  ///
  /// Desktop is pure Dart: the default route comes from [_getDefaultRoutes]
  /// (already used by Smart Auto Stop), the address from `NetworkInterface.list`
  /// and the resolvers from [_getSystemDns]. Android has to go through
  /// `MethodChannel('service')` because neither `NetworkInterface.list` nor
  /// `connectivity_plus` exposes a gateway there.
  ///
  /// Every field defaults to empty, so a failed lookup returns an **empty**
  /// report rather than throwing — the UI renders "-" and never invents a value.
  Future<NetworkInfo> getNetworkInfo() async {
    try {
      if (system.isAndroid) {
        final info = await const MethodChannel('service').invokeMapMethod<
          String,
          Object?
        >('getNetworkInfo');
        return info == null
            ? const NetworkInfo()
            : NetworkInfo.fromJson(info);
      }
      final routes = await _getDefaultRoutes();
      final route = routes
          .where(
            (route) =>
                route.gateway != '0.0.0.0' &&
                route.interfaceName.isNotEmpty,
          )
          .firstOrNull;
      final interfaces = await NetworkInterface.list(includeLoopback: false);
      final matchedInterface = interfaces
          .where((interface) => interface.name == route?.interfaceName)
          .firstOrNull;
      final Iterable<InternetAddress> addresses =
          matchedInterface?.addresses.where((address) => !address.isLinkLocal) ??
          const <InternetAddress>[];
      final address =
          addresses.where((address) => address.isIPv4).firstOrNull ??
          addresses.firstOrNull;
      return NetworkInfo(
        type: await _getConnectivityType(),
        interfaceName: route?.interfaceName ?? '',
        ip: address?.address ?? await getLocalIpAddress() ?? '',
        gateway: route?.gateway ?? '',
        dns: await _getSystemDns(),
      );
    } catch (e) {
      commonPrint.log('Local network info error: $e');
      return const NetworkInfo();
    }
  }

  /// `Wi-Fi` · `Ethernet` · `Cellular`, or `''` when the platform cannot say.
  Future<String> _getConnectivityType() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.contains(ConnectivityResult.wifi)) return 'Wi-Fi';
      if (results.contains(ConnectivityResult.ethernet)) return 'Ethernet';
      if (results.contains(ConnectivityResult.mobile)) return 'Cellular';
    } catch (_) {}
    return '';
  }

  /// The resolvers the OS actually uses, **excluding Fluxora's own hijack DNS**.
  ///
  /// While the tunnel is up, Fluxora points the system at `198.18.0.x`; reading
  /// those back would report our own resolver as the "system DNS", which is
  /// misleading. `127.0.0.1` is excluded for the same reason.
  Future<List<String>> _getSystemDns() async {
    if (Platform.isMacOS) {
      // `systemDns` lives on `MacOS`, not `System` — it is the macOS-only
      // `networksetup -getdnsservers` reader that `System` already uses for its
      // own DNS hijack bookkeeping.
      return await MacOS().systemDns ?? [];
    }
    if (Platform.isWindows) {
      return _getWindowsDns();
    }
    if (Platform.isLinux) {
      return _getLinuxDns();
    }
    return [];
  }

  Future<List<String>> _getWindowsDns() async {
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        r'$route = Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Where-Object { $_.InterfaceAlias -notmatch "(?i)(tun|tap|wintun|meta|clash|vpn)" -and $_.NextHop -ne "0.0.0.0" } | Sort-Object RouteMetric | Select-Object -First 1; if ($route) { (Get-DnsClientServerAddress -InterfaceIndex $route.InterfaceIndex -AddressFamily IPv4).ServerAddresses } else { (Get-DnsClientServerAddress -AddressFamily IPv4).ServerAddresses }',
      ]);
      if (result.exitCode != 0) return [];
      final servers = <String>{};
      for (final line in result.stdout.toString().split('\n')) {
        final server = line.trim();
        if (server.isEmpty) continue;
        if (!RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(server)) continue;
        if (server.startsWith('198.18.') || server == '127.0.0.1') continue;
        servers.add(server);
      }
      return servers.toList();
    } catch (e) {
      commonPrint.log('Windows DNS error: $e');
      return [];
    }
  }

  Future<List<String>> _getLinuxDns() async {
    try {
      final file = File('/etc/resolv.conf');
      if (!await file.exists()) return [];
      final servers = <String>{};
      for (final line in await file.readAsLines()) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('nameserver ')) continue;
        final server = trimmed.substring('nameserver '.length).trim();
        if (server.isEmpty) continue;
        if (server.startsWith('198.18.') || server == '127.0.0.1') continue;
        servers.add(server);
      }
      return servers.toList();
    } catch (e) {
      commonPrint.log('Linux DNS error: $e');
      return [];
    }
  }

  SingleActivator controlSingleActivator(LogicalKeyboardKey trigger) {
    final control = system.isMacOS ? false : true;
    return SingleActivator(trigger, control: control, meta: !control);
  }


  FutureOr<T> handleWatch<T>(Function function) async {
    if (kDebugMode) {
      final stopwatch = Stopwatch()..start();
      final res = await function();
      stopwatch.stop();
      commonPrint.log('Time：${stopwatch.elapsedMilliseconds} ms');
      return res;
    }
    return await function();
  }

  String generateSecret() {
    final random = Random();
    // Generate an 8-digit number (10000000 to 99999999)
    final secret = 10000000 + random.nextInt(90000000);
    return secret.toString();
  }

  String patchYamlConfig(String content) {
    final shortIdExp = RegExp(
      r'(?<=\bshort-id\s*:\s*)(?!["\x27{\[\s])([0-9a-fA-F]+)(?=\s*(?:$|[,\s#\}]))',
      multiLine: true,
    );
    return content.replaceAllMapped(shortIdExp, (match) {
      return '"${match.group(1)}"';
    });
  }

  String patchValidateConfig(String content) {
    final patched = patchYamlConfig(content);
    final regExp = RegExp(
      r'^(\s*geodata-mode\s*:\s*)(true|\x27true\x27|\x22true\x22)(.*)$',
      multiLine: true,
      caseSensitive: false,
    );
    return patched.replaceAllMapped(regExp, (match) {
      return '${match.group(1)}false${match.group(3)}';
    });
  }
}

final utils = Utils();
