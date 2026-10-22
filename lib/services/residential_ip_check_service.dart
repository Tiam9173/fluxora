import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fluxora/models/chain_proxy.dart';

/// 住宅 IP 的体检结论。
enum ResidentialIpVerdict {
  /// 账号密码通过，出口 IP 与预期一致，且不像机房。
  usable,

  /// 能连上，但出口被标记为机房/代理。
  hosted,

  /// 能连上，但出口 IP 和预期不一致。
  mismatch,

  /// 账号密码被拒（S5 authentication failed 一类）。
  authFailed,

  /// 连不上：域名解析失败、端口不通、超时。
  unreachable,
}

class ResidentialIpCheckResult {
  final ResidentialIpVerdict verdict;
  final String message;

  /// 实测出口 IP，连不上时为 null。
  final String? exitIp;
  final String? country;
  final String? isp;

  /// 是否被 IP 库标成机房/代理。
  final bool looksHosted;
  final int? latencyMs;

  const ResidentialIpCheckResult({
    required this.verdict,
    required this.message,
    this.exitIp,
    this.country,
    this.isp,
    this.looksHosted = false,
    this.latencyMs,
  });

  bool get isUsable => verdict == ResidentialIpVerdict.usable;
}

/// 体检一个住宅代理：先验账号密码，再看真实出口。
///
/// 只读：不写配置、不改链路，失败也不会影响正在运行的连接。
class ResidentialIpCheckService {
  const ResidentialIpCheckService({
    this.timeout = const Duration(seconds: 10),
    this.echoHost = 'ip-api.com',
    this.echoPath = '/json?fields=status,country,countryCode,isp,query,hosting,proxy',
  });

  final Duration timeout;
  final String echoHost;
  final String echoPath;

  Future<ResidentialIpCheckResult> check(
    LandingProxy proxy, {
    String? expectedIp,
  }) async {
    if (proxy.protocol != ChainProxyProtocol.socks5) {
      // 只实现了 SOCKS5 的握手；其它协议交给现有的延迟测试，别在这里假装
      // 验过账号密码。
      return const ResidentialIpCheckResult(
        verdict: ResidentialIpVerdict.unreachable,
        message: '仅支持 SOCKS5 账号密码校验',
      );
    }

    final watch = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(
        proxy.server,
        proxy.port,
        timeout: timeout,
      );
      socket.setOption(SocketOption.tcpNoDelay, true);

      String? failure;
      try {
        failure = await _handshake(
          socket,
          username: proxy.username,
          password: proxy.password,
          targetHost: echoHost,
          targetPort: 80,
        );
      } on SocketException {
        // TCP 连上了，但对端在认证阶段就把连接关掉。住宅代理最常见的两种
        // 原因都在这里：账号密码不对，或者它只放行白名单里的源 IP。
        // 报成"连不上"会把用户引到网络排查上去，其实是认证没过。
        return ResidentialIpCheckResult(
          verdict: ResidentialIpVerdict.authFailed,
          message: '账号或密码被拒（对端在认证阶段断开；也可能该代理只放行白名单 IP）',
          latencyMs: watch.elapsedMilliseconds,
        );
      }
      if (failure != null) {
        return ResidentialIpCheckResult(
          verdict: ResidentialIpVerdict.authFailed,
          message: failure,
          latencyMs: watch.elapsedMilliseconds,
        );
      }

      final body = await _httpGet(socket, echoHost, echoPath);
      final json = jsonDecode(body) as Map<String, dynamic>;
      final exitIp = json['query'] as String?;
      final hosted =
          (json['hosting'] as bool? ?? false) ||
          (json['proxy'] as bool? ?? false);

      final verdict = decideVerdict(
        exitIp: exitIp,
        expectedIp: expectedIp,
        looksHosted: hosted,
      );
      return ResidentialIpCheckResult(
        verdict: verdict,
        message: describeVerdict(verdict),
        exitIp: exitIp,
        country: json['country'] as String?,
        isp: json['isp'] as String?,
        looksHosted: hosted,
        latencyMs: watch.elapsedMilliseconds,
      );
    } on SocketException catch (e) {
      return ResidentialIpCheckResult(
        verdict: ResidentialIpVerdict.unreachable,
        message: '连不上 ${proxy.server}:${proxy.port}（${e.osError?.message ?? e.message}）',
        latencyMs: watch.elapsedMilliseconds,
      );
    } on TimeoutException {
      return ResidentialIpCheckResult(
        verdict: ResidentialIpVerdict.unreachable,
        message: '连接超时',
        latencyMs: watch.elapsedMilliseconds,
      );
    } catch (e) {
      return ResidentialIpCheckResult(
        verdict: ResidentialIpVerdict.unreachable,
        message: '检测失败：$e',
        latencyMs: watch.elapsedMilliseconds,
      );
    } finally {
      try {
        socket?.destroy();
      } catch (_) {}
    }
  }

  /// 经链路检测：请求走内核的 mixed 端口，由当前选中的出站（链式代理组）
  /// 转发出去，看到的是**真实出口**。
  ///
  /// 和 [check] 的区别很重要：住宅代理通常按源 IP 做白名单，从手机直连必然
  /// 被对端掐断；只有走前置跳板出去才是它认识的那个来源。直连失败不代表
  /// 代理不能用，只有这一条能回答"到底能不能用"。
  ///
  /// [mixedPort] 必须是**本次会话实际生效**的端口（避让之后的那个），不能读
  /// 配置里的原始值——混合端口被占用时会换端口，读配置就会连到没人监听的
  /// 地方去。
  Future<ResidentialIpCheckResult> checkThroughMixedPort({
    required int mixedPort,
    String? expectedIp,
  }) async {
    final watch = Stopwatch()..start();
    final client = HttpClient();
    client.connectionTimeout = timeout;
    // mixed 端口同时支持 HTTP 代理和 SOCKS5，这里用 HTTP CONNECT。
    client.findProxy = (uri) => 'PROXY 127.0.0.1:$mixedPort';
    try {
      final request = await client
          .getUrl(Uri.parse('http://$echoHost$echoPath'))
          .timeout(timeout);
      final response = await request.close().timeout(timeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      final json = jsonDecode(body) as Map<String, dynamic>;
      final exitIp = json['query'] as String?;
      final hosted =
          (json['hosting'] as bool? ?? false) ||
          (json['proxy'] as bool? ?? false);
      final verdict = decideVerdict(
        exitIp: exitIp,
        expectedIp: expectedIp,
        looksHosted: hosted,
      );
      return ResidentialIpCheckResult(
        verdict: verdict,
        message: describeVerdict(verdict),
        exitIp: exitIp,
        country: json['country'] as String?,
        isp: json['isp'] as String?,
        looksHosted: hosted,
        latencyMs: watch.elapsedMilliseconds,
      );
    } on TimeoutException {
      return ResidentialIpCheckResult(
        verdict: ResidentialIpVerdict.unreachable,
        message: '经链路检测超时（mixed 端口 $mixedPort）',
        latencyMs: watch.elapsedMilliseconds,
      );
    } on SocketException catch (e) {
      return ResidentialIpCheckResult(
        verdict: ResidentialIpVerdict.unreachable,
        message: '连不上内核 mixed 端口 $mixedPort（${e.osError?.message ?? e.message}）',
        latencyMs: watch.elapsedMilliseconds,
      );
    } catch (e) {
      return ResidentialIpCheckResult(
        verdict: ResidentialIpVerdict.unreachable,
        message: '经链路检测失败：$e',
        latencyMs: watch.elapsedMilliseconds,
      );
    } finally {
      client.close(force: true);
    }
  }

  /// 结论判定抽成纯函数，方便测试。
  static ResidentialIpVerdict decideVerdict({
    required String? exitIp,
    String? expectedIp,
    bool looksHosted = false,
  }) {
    if (exitIp == null || exitIp.isEmpty) {
      return ResidentialIpVerdict.unreachable;
    }
    final expected = expectedIp?.trim();
    if (expected != null && expected.isNotEmpty && expected != exitIp) {
      return ResidentialIpVerdict.mismatch;
    }
    if (looksHosted) return ResidentialIpVerdict.hosted;
    return ResidentialIpVerdict.usable;
  }

  static String describeVerdict(ResidentialIpVerdict verdict) {
    return switch (verdict) {
      ResidentialIpVerdict.usable => '住宅 IP 可用',
      ResidentialIpVerdict.hosted => '能连通，但出口被标记为机房/代理',
      ResidentialIpVerdict.mismatch => '出口 IP 与预期不一致',
      ResidentialIpVerdict.authFailed => '账号或密码错误',
      ResidentialIpVerdict.unreachable => '无法连接',
    };
  }

  /// 完成 SOCKS5 协商并连到目标。成功返回 null，失败返回给人看的原因。
  Future<String?> _handshake(
    Socket socket, {
    required String username,
    required String password,
    required String targetHost,
    required int targetPort,
  }) async {
    final input = StreamQueue(socket);
    try {
      // 只提供「用户名/密码」一种认证方式。
      socket.add(Uint8List.fromList([0x05, 0x01, 0x02]));
      final methodReply = await input.read(2);
      if (methodReply[0] != 0x05) return '对方不是 SOCKS5 服务';
      final method = methodReply[1];
      if (method == 0xFF) return '服务端不接受用户名密码认证';
      if (method != 0x02) {
        // 服务端选了「无需认证」：账号密码其实没被验证过，但连接可用。
        // 这里不算失败，继续往下连目标即可。
        if (method != 0x00) return '不支持的认证方式（$method）';
      } else {
        final user = utf8.encode(username);
        final pass = utf8.encode(password);
        socket.add(Uint8List.fromList([
          0x01,
          user.length,
          ...user,
          pass.length,
          ...pass,
        ]));
        final authReply = await input.read(2);
        if (authReply[1] != 0x00) {
          // 这正是用户在别处看到的 "S5 authentication failed"。
          return '账号或密码被拒绝（S5 authentication failed）';
        }
      }

      // CONNECT 到回显服务。
      final hostBytes = utf8.encode(targetHost);
      socket.add(Uint8List.fromList([
        0x05,
        0x01,
        0x00,
        0x03,
        hostBytes.length,
        ...hostBytes,
        (targetPort >> 8) & 0xFF,
        targetPort & 0xFF,
      ]));
      final reply = await input.read(4);
      if (reply[1] != 0x00) return 'SOCKS5 连接目标被拒（错误码 ${reply[1]}）';
      // 吃掉 BND.ADDR + BND.PORT
      switch (reply[3]) {
        case 0x01:
          await input.read(4 + 2);
        case 0x03:
          final len = await input.read(1);
          await input.read(len[0] + 2);
        case 0x04:
          await input.read(16 + 2);
      }
      return null;
    } on TimeoutException {
      return '握手超时';
    } finally {
      input.dispose();
    }
  }

  Future<String> _httpGet(Socket socket, String host, String path) async {
    socket.write('GET $path HTTP/1.1\r\nHost: $host\r\n'
        'User-Agent: Fluxora\r\nConnection: close\r\n\r\n');
    final buffer = <int>[];
    await for (final chunk in socket.timeout(timeout)) {
      buffer.addAll(chunk);
      if (buffer.length > 64 * 1024) break;
    }
    final text = utf8.decode(buffer, allowMalformed: true);
    final split = text.indexOf('\r\n\r\n');
    if (split < 0) throw const FormatException('回显服务没有返回 HTTP 响应');
    return text.substring(split + 4);
  }
}

/// 把字节流按需读够 N 个字节——SOCKS5 的应答是定长的，普通 stream 不保证
/// 一次给全。
class StreamQueue {
  StreamQueue(this._socket) {
    _sub = _socket.listen(
      (data) {
        _buffer.addAll(data);
        _pump();
      },
      onError: (Object e, StackTrace s) => _completeError(e),
      onDone: () => _completeError(
        const SocketException('连接被对端关闭'),
      ),
      cancelOnError: true,
    );
  }

  final Socket _socket;
  late final StreamSubscription<List<int>> _sub;
  final List<int> _buffer = [];
  Completer<Uint8List>? _pending;
  int _needed = 0;

  void _pump() {
    final pending = _pending;
    if (pending == null) return;
    if (_buffer.length < _needed) return;
    final out = Uint8List.fromList(_buffer.sublist(0, _needed));
    _buffer.removeRange(0, _needed);
    _pending = null;
    pending.complete(out);
  }

  void _completeError(Object error) {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(error);
    }
  }

  Future<Uint8List> read(int count) {
    if (_buffer.length >= count) {
      final out = Uint8List.fromList(_buffer.sublist(0, count));
      _buffer.removeRange(0, count);
      return Future.value(out);
    }
    _needed = count;
    final completer = Completer<Uint8List>();
    _pending = completer;
    return completer.future;
  }

  void dispose() {
    _sub.cancel();
  }
}
