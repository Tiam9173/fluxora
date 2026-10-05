import 'package:dio/dio.dart';
import 'package:fluxora/models/common.dart';
import 'package:fluxora/models/public_ip_info.dart';
import 'package:fluxora/services/public_ip_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PublicIpService 公网 IP 探测与容灾降级测试', () {
    test('1. 正确解析 IPv4 标准 JSON 响应', () async {
      const mockJson = '''
      {
        "status": "success",
        "country": "Hong Kong",
        "countryCode": "HK",
        "region": "HCW",
        "regionName": "Central and Western",
        "city": "Hong Kong",
        "isp": "Cloudflare, Inc.",
        "as": "AS13335 Cloudflare, Inc.",
        "query": "104.21.55.2"
      }
      ''';

      final service = PublicIpService(
        customFetcher: (url, {timeout, cancelToken, proxyPort = 0}) async {
          return mockJson;
        },
      );

      final res = await service.fetchPublicIp();
      expect(res.isSuccess, isTrue);
      final ipInfo = res.data!;
      expect(ipInfo.ip, '104.21.55.2');
      expect(ipInfo.version, IpVersion.v4);
      expect(ipInfo.country, 'Hong Kong');
      expect(ipInfo.countryCode, 'HK');
      expect(ipInfo.city, 'Hong Kong');
      expect(ipInfo.isp, 'Cloudflare, Inc.');
      expect(ipInfo.asn, 'AS13335 Cloudflare, Inc.');
    });

    test('2. 正确解析 IPv6 标准 JSON 响应', () async {
      const mockJson = '''
      {
        "ip": "2400:cb00:2048:1::c629:d7a2",
        "country_code": "JP",
        "country": "Japan",
        "region": "Tokyo",
        "city": "Tokyo",
        "organization_name": "KDDI Corporation",
        "asn": 2516
      }
      ''';

      final service = PublicIpService(
        customFetcher: (url, {timeout, cancelToken, proxyPort = 0}) async {
          return mockJson;
        },
      );

      final res = await service.fetchPublicIp(targetVersion: IpVersion.v6);
      expect(res.isSuccess, isTrue);
      final ipInfo = res.data!;
      expect(ipInfo.ip, '2400:cb00:2048:1::c629:d7a2');
      expect(ipInfo.version, IpVersion.v6);
      expect(ipInfo.countryCode, 'JP');
      expect(ipInfo.country, 'Japan');
      expect(ipInfo.city, 'Tokyo');
      expect(ipInfo.isp, 'KDDI Corporation');
      expect(ipInfo.asn, '2516');
    });

    test('3. 超时或异常正确捕获', () async {
      final service = PublicIpService(
        customFetcher: (url, {timeout, cancelToken, proxyPort = 0}) async {
          throw DioException(
            requestOptions: RequestOptions(path: url),
            type: DioExceptionType.connectionTimeout,
            message: 'Connection timed out',
          );
        },
      );

      final res = await service.fetchPublicIp();
      expect(res.isError, isTrue);
      expect(res.data, isNull);
    });

    test('4. 首选源失败时多源自动 Fallback 降级', () async {
      int attempt = 0;
      final service = PublicIpService(
        customFetcher: (url, {timeout, cancelToken, proxyPort = 0}) async {
          attempt++;
          if (attempt == 1) {
            // 第一个源宕机或返回 500
            throw Exception('Primary source down 500');
          }
          // 第二个源 (geo.json 或 trace) 成功返回 Cloudflare Trace 格式
          return '''
fl=123f45
h=ip.sb
ip=103.21.244.15
ts=1720000000
visit_scheme=https
uag=Fluxora
colo=HKG
http=http/2
loc=HK
tls=TLSv1.3
sni=plaintext
warp=off
gateway=off
rbi=off
kex=X25519
''';
        },
      );

      final res = await service.fetchPublicIp();
      expect(res.isSuccess, isTrue);
      expect(attempt, 2);
      final ipInfo = res.data!;
      expect(ipInfo.ip, '103.21.244.15');
      expect(ipInfo.version, IpVersion.v4);
      expect(ipInfo.countryCode, 'HK');
    });

    test('5. 内存缓存有效性 (Cache Hit)', () async {
      int networkCalls = 0;
      final service = PublicIpService(
        cacheTtl: const Duration(minutes: 5),
        customFetcher: (url, {timeout, cancelToken, proxyPort = 0}) async {
          networkCalls++;
          return '{"query": "1.1.1.1", "status": "success"}';
        },
      );

      // 第 1 次请求：真实网络调用
      final res1 = await service.fetchPublicIp(proxyPort: 7890);
      expect(res1.isSuccess, isTrue);
      expect(networkCalls, 1);

      // 第 2 次请求：命中缓存，网络调用计数不变
      final res2 = await service.fetchPublicIp(proxyPort: 7890);
      expect(res2.isSuccess, isTrue);
      expect(networkCalls, 1);
      expect(res2.data!.ip, '1.1.1.1');

      // 强制刷新：触发真实网络调用
      final res3 = await service.fetchPublicIp(
        proxyPort: 7890,
        forceRefresh: true,
      );
      expect(res3.isSuccess, isTrue);
      expect(networkCalls, 2);
    });

    test('6. 畸形响应安全处理 (Malformed Response)', () async {
      final service = PublicIpService(
        customFetcher: (url, {timeout, cancelToken, proxyPort = 0}) async {
          return '<<<INVALID HTML 404 NOT FOUND>>>';
        },
      );

      final res = await service.fetchPublicIp();
      expect(res.isError, isTrue);
      expect(res.data, isNull);
    });

    test('7. 所有源全挂时返回结构化错误', () async {
      final service = PublicIpService(
        customFetcher: (url, {timeout, cancelToken, proxyPort = 0}) async {
          throw Exception('Network unreachable');
        },
      );

      final res = await service.fetchPublicIp();
      expect(res.isError, isTrue);
      expect(res.message, contains('Network unreachable'));
    });
  });
}
