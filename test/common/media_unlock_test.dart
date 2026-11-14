import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';

class _MappedClient extends Fake implements HttpClient {
  _MappedClient(this.client, this.server, this.hosts, this.nativeFailsTls);

  final HttpClient client;
  final HttpServer server;
  final List<String> hosts;
  final bool nativeFailsTls;

  @override
  set connectionTimeout(Duration? value) => client.connectionTimeout = value;

  @override
  set idleTimeout(Duration value) => client.idleTimeout = value;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    hosts.add(url.host);
    final native = url.host == 'android.chat.openai.com';
    if (native && nativeFailsTls) throw const HandshakeException('fixture');
    return client.openUrl(
      method,
      Uri.http('127.0.0.1:${server.port}', native ? '/native' : url.path),
    );
  }

  @override
  void close({bool force = false}) => client.close(force: force);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'OpenAI checks the Android TLS endpoint even after a good web trace',
    () async {
      final oldConfig = globalState.config;
      final oldPlatform = System.platformOverride;
      addTearDown(() {
        globalState.config = oldConfig;
        System.platformOverride = oldPlatform;
      });
      globalState.config = oldConfig.copyWith(
        patchClashConfig: oldConfig.patchClashConfig.copyWith(unifiedDelay: false),
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) {
        if (request.uri.path == '/native') {
          request.response.statusCode = HttpStatus.forbidden;
        } else {
          request.response.write('ip=192.0.2.1\nloc=US\n');
        }
        request.response.close();
      });
      final hosts = <String>[];
      Future<MediaUnlockStatus> run(String platform, bool nativeFailsTls) async {
        hosts.clear();
        System.platformOverride = platform;
        final client = FluxoraHttpOverrides().createHttpClient(null)
          ..findProxy = (_) => 'DIRECT';
        return HttpOverrides.runZoned(
          () async {
            final result = await MediaUnlockChecker().checkPlatform(
              MediaPlatform.openai,
            );
            return result.status;
          },
          createHttpClient: (_) =>
              _MappedClient(client, server, hosts, nativeFailsTls),
        );
      }

      expect(await run('android', true), MediaUnlockStatus.failed);
      expect(hosts, ['chatgpt.com', 'android.chat.openai.com']);
      expect(await run('android', false), MediaUnlockStatus.unlocked);
      expect(hosts, ['chatgpt.com', 'android.chat.openai.com']);
      expect(await run('windows', true), MediaUnlockStatus.unlocked);
      expect(hosts, ['chatgpt.com']);
    },
  );

  group('MediaPlatform & Region Tests', () {
    test('MediaPlatform enum count and extensions', () {
      expect(MediaPlatform.values.length, 55);
      expect(MediaCategory.values.length, 7);

      for (final p in MediaPlatform.values) {
        expect(p.defaultName.isNotEmpty, true);
        expect(p.category, isNotNull);
      }

      for (final cat in MediaCategory.values) {
        final count = MediaPlatform.values.where((p) => p.category == cat).length;
        expect(count > 0, true);
      }

      expect(MediaPlatform.openai.defaultName, 'OpenAI');
      expect(MediaPlatform.openai.category, MediaCategory.ai);
      expect(MediaPlatform.claude.defaultName, 'Claude');
      expect(MediaPlatform.claude.category, MediaCategory.ai);
      expect(MediaPlatform.grok.defaultName, 'Grok');
      expect(MediaPlatform.grok.category, MediaCategory.ai);
      expect(MediaPlatform.cloudflare.defaultName, 'Cloudflare');
      expect(MediaPlatform.cloudflare.category, MediaCategory.ai);
      expect(MediaPlatform.perplexity.defaultName, 'Perplexity');
      expect(MediaPlatform.perplexity.category, MediaCategory.ai);

      expect(MediaPlatform.qqnews.defaultName, 'Tencent(CN)');
      expect(MediaPlatform.qqnews.category, MediaCategory.china);
      expect(MediaPlatform.alidnsprobe.defaultName, 'Alibaba(CN)');
      expect(MediaPlatform.alidnsprobe.category, MediaCategory.china);
      expect(MediaPlatform.netease.defaultName, 'Netease(CN)');
      expect(MediaPlatform.netease.category, MediaCategory.china);
      expect(MediaPlatform.bytedance.defaultName, 'Douyin(CN)');
      expect(MediaPlatform.bytedance.category, MediaCategory.china);
      expect(MediaPlatform.bilibili.defaultName, 'Bilibili(CN)');
      expect(MediaPlatform.bilibili.category, MediaCategory.china);
      expect(MediaPlatform.cloudflarecn.defaultName, 'Cloudflare(CN)');
      expect(MediaPlatform.cloudflarecn.category, MediaCategory.china);

      expect(MediaPlatform.netflix.category, MediaCategory.streaming);
      expect(MediaPlatform.disney.category, MediaCategory.streaming);
      expect(MediaPlatform.youtube.category, MediaCategory.streaming);
      expect(MediaPlatform.spotify.category, MediaCategory.streaming);
      expect(MediaPlatform.tiktok.category, MediaCategory.streaming);
      expect(MediaPlatform.iqiyi.category, MediaCategory.streaming);
      expect(MediaPlatform.crunchyroll.category, MediaCategory.streaming);
      expect(MediaPlatform.missav.category, MediaCategory.streaming);
      expect(MediaPlatform.ehentai.category, MediaCategory.streaming);
      // item 6 — Bettbox 1.19.4 additions.
      expect(MediaPlatform.mytvsuper.defaultName, 'myTV SUPER');
      expect(MediaPlatform.mytvsuper.category, MediaCategory.streaming);
      expect(MediaPlatform.viutv.defaultName, 'ViuTV');
      expect(MediaPlatform.viutv.category, MediaCategory.streaming);
      expect(MediaPlatform.hoytv.defaultName, 'HOY TV');
      expect(MediaPlatform.hoytv.category, MediaCategory.streaming);
      expect(MediaPlatform.rthk.defaultName, 'RTHK');
      expect(MediaPlatform.rthk.category, MediaCategory.streaming);

      expect(MediaPlatform.x.defaultName, 'Twitter');
      expect(MediaPlatform.x.category, MediaCategory.social);
      expect(MediaPlatform.reddit.category, MediaCategory.social);
      expect(MediaPlatform.discord.category, MediaCategory.social);
      expect(MediaPlatform.v2ex.category, MediaCategory.social);
      expect(MediaPlatform.medium.category, MediaCategory.social);
      expect(MediaPlatform.stackoverflow.category, MediaCategory.social);
      expect(MediaPlatform.quora.category, MediaCategory.social);
      expect(MediaPlatform.telegram.defaultName, 'Telegram');
      expect(MediaPlatform.telegram.category, MediaCategory.social);
      expect(MediaPlatform.telegram.pinColoBadge, true);

      expect(MediaPlatform.github.category, MediaCategory.developer);
      expect(MediaPlatform.wikipedia.category, MediaCategory.developer);
      expect(MediaPlatform.apple.category, MediaCategory.developer);
      expect(MediaPlatform.onetrust.category, MediaCategory.developer);
      expect(MediaPlatform.gitlab.category, MediaCategory.developer);
      expect(MediaPlatform.npm.category, MediaCategory.developer);
      expect(MediaPlatform.cdnjs.category, MediaCategory.developer);
      expect(MediaPlatform.unpkg.category, MediaCategory.developer);
      expect(MediaPlatform.nodejs.category, MediaCategory.developer);

      expect(MediaPlatform.steam.category, MediaCategory.gaming);
      expect(MediaPlatform.epic.category, MediaCategory.gaming);
      expect(MediaPlatform.ubisoft.category, MediaCategory.gaming);
      expect(MediaPlatform.humblebundle.category, MediaCategory.gaming);

      expect(MediaPlatform.coinbase.category, MediaCategory.crypto);
      expect(MediaPlatform.okx.category, MediaCategory.crypto);
      expect(MediaPlatform.kraken.category, MediaCategory.crypto);
      expect(MediaPlatform.cryptocom.category, MediaCategory.crypto);
      expect(MediaPlatform.phantom.category, MediaCategory.crypto);
      // item 6 — Bettbox 1.19.4 addition.
      expect(MediaPlatform.paypal.defaultName, 'PayPal');
      expect(MediaPlatform.paypal.category, MediaCategory.crypto);

      expect(MediaPlatform.x.isMonochrome, true);
      expect(MediaPlatform.github.isMonochrome, true);
      expect(MediaPlatform.apple.isMonochrome, true);
      expect(MediaPlatform.grok.isMonochrome, true);
      expect(MediaPlatform.epic.isMonochrome, true);
      expect(MediaPlatform.openai.isMonochrome, false);
      expect(MediaPlatform.netflix.isMonochrome, false);
    });
    test('defaultPinnedMediaPlatforms has 3 items: reddit, gemini, cloudflare', () {
      expect(defaultPinnedMediaPlatforms, [
        MediaPlatform.reddit,
        MediaPlatform.gemini,
        MediaPlatform.cloudflare,
      ]);
    });

    test('pinnedMediaPlatformsSafeFromJson migration', () {
      final migrated = pinnedMediaPlatformsSafeFromJson(['chatgpt', 'linuxdo', 'youtube', 'github']);
      expect(migrated, [
        MediaPlatform.openai,
        MediaPlatform.youtube,
        MediaPlatform.github,
      ]);
    });

    test('utils.normalizeRegion mappings', () {
      expect(utils.normalizeRegion('TWN'), 'TW');
      expect(utils.normalizeRegion('NTW'), 'TW');
      expect(utils.normalizeRegion('TWD'), 'TW');
      expect(utils.normalizeRegion('JPN'), 'JP');
      expect(utils.normalizeRegion('JPY'), 'JP');
      expect(utils.normalizeRegion('KOR'), 'KR');
      expect(utils.normalizeRegion('KRW'), 'KR');
      expect(utils.normalizeRegion('SGP'), 'SG');
      expect(utils.normalizeRegion('SGD'), 'SG');
      expect(utils.normalizeRegion('GBR'), 'GB');
      expect(utils.normalizeRegion('GBP'), 'GB');
      expect(utils.normalizeRegion('USD'), 'US');
      expect(utils.normalizeRegion('HKD'), 'HK');
    });
  });
}
