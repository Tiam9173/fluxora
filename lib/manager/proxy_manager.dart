import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxyManager extends ConsumerStatefulWidget {
  final Widget child;

  const ProxyManager({super.key, required this.child});

  @override
  ConsumerState createState() => _ProxyManagerState();
}

class _ProxyManagerState extends ConsumerState<ProxyManager> {
  Future<bool?> _updateProxy(ProxyState proxyState) async {
    final isStart = proxyState.isStart;
    final systemProxy = proxyState.systemProxy;
    final port = proxyState.port;
    if (!system.isWindows) return null;
    if (isStart && systemProxy) {
      // B3 — records the previous system proxy first, and only claims ownership
      // after a read-back proves the write landed.
      if (port <= 0) return false;
      return ProxyOwnership.apply(port: port, bypass: proxyState.bypassDomain);
    } else {
      // Releases only what this app actually set. On the first frame of a cold
      // start that is nothing, so merely launching Fluxora no longer forces
      // WinINET to direct-connect and clobber another program's proxy.
      await ProxyOwnership.release(reason: 'proxy_manager');
      return null;
    }
  }

  /// Serialises the async proxy work.
  ///
  /// `_updateProxy` awaits a settle delay and a read-back, so two rapid toggles
  /// would otherwise interleave and the later one could observe the earlier
  /// one's half-applied state.
  Future<void> _pending = Future<void>.value();

  void _enqueue(ProxyState proxyState) {
    _pending = _pending.then((_) async {
      if (!mounted || ref.read(proxyStateProvider) != proxyState) return;
      final applied = ref.read(systemProxyAppliedProvider.notifier);
      applied.state = null;
      try {
        final success = await _updateProxy(proxyState);
        if (mounted && ref.read(proxyStateProvider) == proxyState) {
          applied.state = success;
        }
      } catch (error) {
        commonPrint.log('System proxy update failed: $error');
        if (mounted && ref.read(proxyStateProvider) == proxyState) {
          applied.state = false;
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(proxyStateProvider, (prev, next) {
      if (prev != next) {
        _enqueue(next);
      }
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
