import 'dart:async';

import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/services/system_proxy_readback.dart';
import 'package:fluxora/services/tun_readback.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> _handleNetworkConfigChange(WidgetRef ref) async {
  if (system.isAndroid) {
    final isVpnEnabled = ref.read(vpnSettingProvider).enable;
    final isCoreRunning = ref.read(runTimeProvider) != null;
    if (isVpnEnabled && isCoreRunning) {
      globalState.showNotifier(
        appLocalizations.vpnTip,
        actionLabel: appLocalizations.restart,
        showCountdown: true,
        onAction: () async {
          await globalState.appController.restartCore();
          globalState.showNotifier(appLocalizations.success);
        },
      );
      return;
    }
  }
  globalState.appController.updateClashConfig();
}

class VPNItem extends ConsumerWidget {
  const VPNItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final enable = ref.watch(
      vpnSettingProvider.select((state) => state.enable),
    );
    return ListItem.switchItem(
      title: const Text('VPN'),
      subtitle: Text(appLocalizations.vpnEnableDesc),
      delegate: SwitchDelegate(
        value: enable,
        onChanged: (value) async {
          ref
              .read(vpnSettingProvider.notifier)
              .updateState((state) => state.copyWith(enable: value));
        },
      ),
    );
  }
}

class TUNItem extends ConsumerWidget {
  const TUNItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final enable = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.enable),
    );

    return ListItem.switchItem(
      title: Text(appLocalizations.tun),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(appLocalizations.tunDesc),
          const SizedBox(height: 4),
          // P2.6-F: the switch above is the *desired* state; this line reports
          // the OS's *actual* state. The two are never conflated.
          const TunStatusLine(),
        ],
      ),
      delegate: SwitchDelegate(
        value: enable,
        onChanged: (value) async {
          ref
              .read(patchClashConfigProvider.notifier)
              .updateState((state) => state.copyWith.tun(enable: value));
        },
      ),
    );
  }
}

/// P2.6-F: the "desired vs actual" indicator for desktop TUN.
///
/// Mirrors [SystemProxyStatusLine]: it reads `TunReadbackService.instance` — the
/// single readback owner — so the switch and the status line can never disagree
/// about what the OS actually has. It never fabricates ON: `unknown` and
/// `unsupported` are shown as such.
///
/// The readback is triggered from `initState` (never from `build()`), so a
/// rebuild can never spawn an OS query.
class TunStatusLine extends ConsumerStatefulWidget {
  const TunStatusLine({super.key});

  @override
  ConsumerState<TunStatusLine> createState() => _TunStatusLineState();
}

class _TunStatusLineState extends ConsumerState<TunStatusLine> {
  @override
  void initState() {
    super.initState();
    // One observation on first display — never from `build()`. Only if nothing
    // has been observed yet, so several mounts do not each trigger their own.
    if (TunReadbackService.instance.lastReadback.value == null) {
      unawaited(TunReadbackService.instance.read());
    }
  }

  @override
  Widget build(BuildContext context) {
    final desired = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.enable),
    );
    final service = TunReadbackService.instance;

    return ValueListenableBuilder<bool>(
      valueListenable: service.isChecking,
      builder: (context, checking, _) {
        return ValueListenableBuilder<TunReadback?>(
          valueListenable: service.lastReadback,
          builder: (context, readback, _) {
            return _buildStatus(
              context,
              resolveTunStatus(
                desiredEnabled: desired,
                checking: checking,
                readback: readback,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatus(BuildContext context, TunStatusKind status) {
    final (IconData? icon, String text, Color color) = switch (status) {
      TunStatusKind.notChecked => (
        null,
        '',
        context.colorScheme.onSurfaceVariant,
      ),
      TunStatusKind.checking => (
        Icons.sync,
        appLocalizations.tunChecking,
        context.colorScheme.onSurfaceVariant,
      ),
      TunStatusKind.unsupported => (
        Icons.info_outline,
        appLocalizations.tunUnsupported,
        context.colorScheme.onSurfaceVariant,
      ),
      TunStatusKind.unknown => (
        Icons.help_outline,
        appLocalizations.tunUnknown,
        context.colorScheme.onSurfaceVariant,
      ),
      TunStatusKind.on => (
        Icons.check_circle_outline,
        appLocalizations.tunActualOn,
        context.colorScheme.primary,
      ),
      TunStatusKind.off => (
        Icons.radio_button_unchecked,
        appLocalizations.tunActualOff,
        context.colorScheme.onSurfaceVariant,
      ),
      TunStatusKind.mismatchOn => (
        Icons.warning_amber_rounded,
        appLocalizations.tunMismatchOn,
        context.colorScheme.error,
      ),
      TunStatusKind.mismatchOff => (
        Icons.warning_amber_rounded,
        appLocalizations.tunMismatchOff,
        context.colorScheme.error,
      ),
    };

    if (icon == null) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: context.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class AllowBypassItem extends ConsumerWidget {
  const AllowBypassItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final allowBypass = ref.watch(
      vpnSettingProvider.select((state) => state.allowBypass),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.allowBypass),
      subtitle: Text(appLocalizations.allowBypassDesc),
      delegate: SwitchDelegate(
        value: allowBypass,
        onChanged: (bool value) async {
          ref
              .read(vpnSettingProvider.notifier)
              .updateState((state) => state.copyWith(allowBypass: value));
          await _handleNetworkConfigChange(ref);
        },
      ),
    );
  }
}

class VpnSystemProxyItem extends ConsumerWidget {
  const VpnSystemProxyItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final systemProxy = ref.watch(
      vpnSettingProvider.select((state) => state.systemProxy),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.systemProxy),
      subtitle: Text(appLocalizations.vpnSystemProxyDesc),
      delegate: SwitchDelegate(
        value: systemProxy,
        onChanged: (bool value) async {
          if (value) {
            final res = await globalState.showMessage(
              message: TextSpan(
                text: appLocalizations.vpnSystemProxyConfirmDesc,
              ),
            );
            if (res != true) return;
          }
          ref
              .read(vpnSettingProvider.notifier)
              .updateState((state) => state.copyWith(systemProxy: value));
          await _handleNetworkConfigChange(ref);
        },
      ),
    );
  }
}

/// P2.5-B (CF-3): the single, shared "desired vs actual" indicator.
///
/// Both the Network settings page and the dashboard read the **same** source —
/// `SystemProxyReadbackService.instance` — so they can never disagree about
/// what the OS actually has. It never fabricates ON: `unknown` / `unsupported`
/// are shown as such.
///
/// The readback is triggered from `initState` (never from `build()`), so a
/// rebuild can never spawn an OS query.
class SystemProxyStatusLine extends ConsumerStatefulWidget {
  const SystemProxyStatusLine({super.key, this.compact = false});

  /// Compact mode renders a bare icon (with a tooltip) instead of icon + text,
  /// for the height-constrained dashboard card.
  final bool compact;

  @override
  ConsumerState<SystemProxyStatusLine> createState() =>
      _SystemProxyStatusLineState();
}

class _SystemProxyStatusLineState extends ConsumerState<SystemProxyStatusLine> {
  @override
  void initState() {
    super.initState();
    // One observation on first display — never from `build()`. Only if nothing
    // has been observed yet, so the settings page and the dashboard do not each
    // trigger their own. The shared service is the single readback owner.
    if (SystemProxyReadbackService.instance.lastReadback.value == null) {
      unawaited(SystemProxyReadbackService.instance.read());
    }
  }

  @override
  Widget build(BuildContext context) {
    final desired = ref.watch(
      networkSettingProvider.select((state) => state.systemProxy),
    );
    final service = SystemProxyReadbackService.instance;

    return ValueListenableBuilder<bool>(
      valueListenable: service.isChecking,
      builder: (context, checking, _) {
        return ValueListenableBuilder<SystemProxyReadback?>(
          valueListenable: service.lastReadback,
          builder: (context, readback, _) {
            return _buildStatus(
              context,
              resolveSystemProxyStatus(
                desiredEnabled: desired,
                checking: checking,
                readback: readback,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatus(BuildContext context, SystemProxyStatusKind status) {
    final (IconData? icon, String text, Color color) = switch (status) {
      SystemProxyStatusKind.notChecked => (
        null,
        '',
        context.colorScheme.onSurfaceVariant,
      ),
      SystemProxyStatusKind.checking => (
        Icons.sync,
        appLocalizations.systemProxyChecking,
        context.colorScheme.onSurfaceVariant,
      ),
      SystemProxyStatusKind.unsupported => (
        Icons.info_outline,
        appLocalizations.systemProxyUnsupported,
        context.colorScheme.onSurfaceVariant,
      ),
      SystemProxyStatusKind.unknown => (
        Icons.help_outline,
        appLocalizations.systemProxyUnknown,
        context.colorScheme.onSurfaceVariant,
      ),
      SystemProxyStatusKind.on => (
        Icons.check_circle_outline,
        appLocalizations.systemProxyActualOn,
        context.colorScheme.primary,
      ),
      SystemProxyStatusKind.off => (
        Icons.radio_button_unchecked,
        appLocalizations.systemProxyActualOff,
        context.colorScheme.onSurfaceVariant,
      ),
      SystemProxyStatusKind.mismatchOn => (
        Icons.warning_amber_rounded,
        appLocalizations.systemProxyMismatchOn,
        context.colorScheme.error,
      ),
      SystemProxyStatusKind.mismatchOff => (
        Icons.warning_amber_rounded,
        appLocalizations.systemProxyMismatchOff,
        context.colorScheme.error,
      ),
    };

    if (icon == null) return const SizedBox.shrink();
    if (widget.compact) {
      // Only surface mismatches / unknowns on the compact dashboard card; the
      // "matched" states are already conveyed by the switch itself.
      if (status == SystemProxyStatusKind.on ||
          status == SystemProxyStatusKind.off) {
        return const SizedBox.shrink();
      }
      return Tooltip(message: text, child: Icon(icon, size: 16, color: color));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: context.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class SystemProxyItem extends ConsumerWidget {
  const SystemProxyItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final systemProxy = ref.watch(
      networkSettingProvider.select((state) => state.systemProxy),
    );

    return ListItem.switchItem(
      title: Text(appLocalizations.systemProxy),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(appLocalizations.systemProxyDesc),
          const SizedBox(height: 4),
          const SystemProxyStatusLine(),
        ],
      ),
      delegate: SwitchDelegate(
        value: systemProxy,
        onChanged: (bool value) async {
          // P2.5-B (CF-3): route through the controller so the OS readback
          // always runs. Writing the desired provider directly here would skip
          // the observation and leave the UI unable to tell "requested" from
          // "actually applied".
          await globalState.appController.setSystemProxy(value);
        },
      ),
    );
  }
}

class AutoSetSystemDnsItem extends ConsumerWidget {
  const AutoSetSystemDnsItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final autoSetSystemDnsState = ref.watch(autoSetSystemDnsStateProvider);
    final canSetSystemDns = autoSetSystemDnsState.a;
    final autoSetSystemDns = autoSetSystemDnsState.b;
    return ListItem.switchItem(
      title: Text(appLocalizations.autoSetSystemDns),
      delegate: SwitchDelegate(
        value: autoSetSystemDns,
        onChanged: canSetSystemDns
            ? (bool value) async {
                ref
                    .read(networkSettingProvider.notifier)
                    .updateState(
                      (state) => state.copyWith(autoSetSystemDns: value),
                    );
              }
            : null,
      ),
    );
  }
}

class StrictRouteItem extends ConsumerWidget {
  const StrictRouteItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strictRoute = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.strictRoute),
    );

    return ListItem.switchItem(
      title: Text(appLocalizations.strictRoute),
      subtitle: Text(appLocalizations.strictRouteDesc),
      delegate: SwitchDelegate(
        value: strictRoute,
        onChanged: (value) async {
          ref
              .read(patchClashConfigProvider.notifier)
              .updateState((state) => state.copyWith.tun(strictRoute: value));

          await _handleNetworkConfigChange(ref);
        },
      ),
    );
  }
}

class IcmpForwardingItem extends ConsumerWidget {
  const IcmpForwardingItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Note: inverted because disableIcmpForwarding=true means disabled
    // UI shows "Enable ICMP forwarding"
    final icmpForwarding = ref.watch(
      patchClashConfigProvider.select(
        (state) => !state.tun.disableIcmpForwarding,
      ),
    );

    return ListItem.switchItem(
      title: Text(appLocalizations.icmpForwarding),
      subtitle: Text(appLocalizations.icmpForwardingDesc),
      delegate: SwitchDelegate(
        value: icmpForwarding,
        onChanged: (value) async {
          // Invert before passing to core
          ref
              .read(patchClashConfigProvider.notifier)
              .updateState(
                (state) => state.copyWith.tun(disableIcmpForwarding: !value),
              );

          await _handleNetworkConfigChange(ref);
        },
      ),
    );
  }
}

class DnsHijackItem extends ConsumerWidget {
  const DnsHijackItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dnsHijack = ref.watch(
      patchClashConfigProvider.select(
        (state) => state.tun.dnsHijack.isNotEmpty,
      ),
    );

    return ListItem.switchItem(
      title: Text(appLocalizations.dnsHijack),
      subtitle: Text(appLocalizations.dnsHijackDesc),
      delegate: SwitchDelegate(
        value: dnsHijack,
        onChanged: (value) async {
          ref
              .read(patchClashConfigProvider.notifier)
              .updateState(
                (state) => state.copyWith.tun(
                  dnsHijack: value ? ['any:53', 'tcp://any:53'] : [],
                ),
              );
          await _handleNetworkConfigChange(ref);
        },
      ),
    );
  }
}

class EndpointIndependentNatItem extends ConsumerWidget {
  const EndpointIndependentNatItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final endpointIndependentNat = ref.watch(
      patchClashConfigProvider.select(
        (state) => state.tun.endpointIndependentNat,
      ),
    );

    return ListItem.switchItem(
      title: Text(appLocalizations.endpointIndependentNat),
      subtitle: Text(appLocalizations.endpointIndependentNatDesc),
      delegate: SwitchDelegate(
        value: endpointIndependentNat,
        onChanged: (value) async {
          if (value) {
            final res = await globalState.showMessage(
              title: appLocalizations.tip,
              message: TextSpan(
                text: appLocalizations.endpointIndependentNatConfirmDesc,
              ),
            );
            if (res != true) return;
          }
          ref
              .read(patchClashConfigProvider.notifier)
              .updateState(
                (state) => state.copyWith.tun(endpointIndependentNat: value),
              );
          await _handleNetworkConfigChange(ref);
        },
      ),
    );
  }
}

class TunStackItem extends ConsumerWidget {
  const TunStackItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final stack = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.stack),
    );

    return ListItem.options(
      title: Text(appLocalizations.stackMode),
      subtitle: Text(stack.name),
      delegate: OptionsDelegate<TunStack>(
        value: stack,
        options: TunStack.values,
        textBuilder: (value) => value.name,
        onChanged: (value) async {
          if (value == null) {
            return;
          }
          ref
              .read(patchClashConfigProvider.notifier)
              .updateState((state) => state.copyWith.tun(stack: value));
          await _handleNetworkConfigChange(ref);
        },
        title: appLocalizations.stackMode,
      ),
    );
  }
}

/// TUN 下的系统 DNS 模式（内核 v1.19.33 新增）。
///
/// 空串表示不写这个字段，由内核按平台决定——这是升级前的行为，默认值必须
/// 保持它，否则老用户升级后 DNS 行为会莫名改变。
class TunDnsModeItem extends ConsumerWidget {
  const TunDnsModeItem({super.key});

  static const _values = ['', 'disabled', 'native', 'hijack'];

  String _label(String value) {
    return switch (value) {
      'disabled' => appLocalizations.tunDnsModeDisabled,
      'native' => appLocalizations.tunDnsModeNative,
      'hijack' => appLocalizations.tunDnsModeHijack,
      _ => appLocalizations.tunDnsModeDefault,
    };
  }

  @override
  Widget build(BuildContext context, ref) {
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.dnsMode),
    );

    return ListItem.options(
      title: Text(appLocalizations.tunDnsMode),
      subtitle: Text(appLocalizations.tunDnsModeDesc),
      delegate: OptionsDelegate<String>(
        value: mode,
        options: _values,
        textBuilder: _label,
        onChanged: (value) async {
          if (value == null) {
            return;
          }
          ref
              .read(patchClashConfigProvider.notifier)
              .updateState((state) => state.copyWith.tun(dnsMode: value));
          await _handleNetworkConfigChange(ref);
        },
        title: appLocalizations.tunDnsMode,
      ),
    );
  }
}

class MtuItem extends ConsumerWidget {
  const MtuItem({super.key});

  Future<void> _showCustomMtuDialog(
    BuildContext context,
    WidgetRef ref,
    int currentMtu,
  ) async {
    String inputValue = '$currentMtu';
    String? errorText;
    final controller = TextEditingController(text: inputValue);

    final result = await globalState.showCommonDialog<bool>(
      child: StatefulBuilder(
        builder: (context, setState) {
          return CommonDialog(
            title: 'MTU',
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: Text(appLocalizations.cancel),
              ),
              TextButton(
                onPressed: errorText == null && inputValue.isNotEmpty
                    ? () {
                        Navigator.of(context).pop(true);
                      }
                    : null,
                child: Text(appLocalizations.confirm),
              ),
            ],
            child: TextField(
              autofocus: true,
              keyboardType: TextInputType.number,
              controller: controller,
              decoration: InputDecoration(
                labelText: 'MTU',
                errorText: errorText,
                hintText: '1280-65535',
              ),
              onChanged: (value) {
                inputValue = value;
                // Real-time validation
                if (value.isEmpty) {
                  setState(() {
                    errorText = appLocalizations.emptyTip('MTU');
                  });
                } else {
                  final intValue = int.tryParse(value);
                  if (intValue == null) {
                    setState(() {
                      errorText = appLocalizations.numberTip('MTU');
                    });
                  } else if (intValue < 1280 || intValue > 65535) {
                    setState(() {
                      errorText = 'MTU Must be 1280-65535';
                    });
                  } else {
                    setState(() {
                      errorText = null;
                    });
                  }
                }
              },
              onSubmitted: (value) {
                if (errorText == null && value.isNotEmpty) {
                  Navigator.of(context).pop(true);
                }
              },
            ),
          );
        },
      ),
    );

    // Clean up controller
    controller.dispose();

    if (result == true && inputValue.isNotEmpty) {
      final intValue = int.tryParse(inputValue);
      if (intValue != null && intValue >= 1280 && intValue <= 65535) {
        ref
            .read(patchClashConfigProvider.notifier)
            .updateState((state) => state.copyWith.tun(mtu: intValue));
        await _handleNetworkConfigChange(ref);
      }
    }
  }

  @override
  Widget build(BuildContext context, ref) {
    final mtu = ref.watch(
      patchClashConfigProvider.select((state) => state.tun.mtu),
    );

    // Preset options
    final presetOptions = [1480, 4064, 9000];
    final isCustom = !presetOptions.contains(mtu);

    return ListItem.options(
      title: const Text('MTU'),
      subtitle: Text(isCustom ? '$mtu (${appLocalizations.custom})' : '$mtu'),
      delegate: OptionsDelegate<String>(
        value: isCustom ? 'custom' : '$mtu',
        options: ['1480', '4064', '9000', 'custom'],
        textBuilder: (value) {
          if (value == 'custom') {
            return '${appLocalizations.custom}...';
          }
          return value;
        },
        onChanged: (value) async {
          if (value == null) return;

          // If custom option selected
          if (value == 'custom') {
            // 选项面板此时正在 pop，同一帧里再 push 一个对话框会让 Navigator
            // 在移除节点时仍持有 dependents，触发 framework 的断言红屏。
            // 等这一帧结束、面板真正关掉之后再开输入框。
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showCustomMtuDialog(context, ref, mtu);
            });
          } else {
            // Apply preset value directly
            final intValue = int.parse(value);
            ref
                .read(patchClashConfigProvider.notifier)
                .updateState((state) => state.copyWith.tun(mtu: intValue));
            await _handleNetworkConfigChange(ref);
          }
        },
        title: 'MTU',
      ),
    );
  }
}

class BypassDomainItem extends StatelessWidget {
  const BypassDomainItem({super.key});

  @override
  Widget build(BuildContext context) {
    return ListItem.next(
      title: Text(appLocalizations.bypassDomain),
      subtitle: Text(appLocalizations.bypassDomainDesc),
      delegate: NextDelegate(
        blur: false,
        actions: [
          Consumer(
            builder: (_, ref, _) {
              return IconButton(
                onPressed: () async {
                  final res = await globalState.showMessage(
                    title: appLocalizations.reset,
                    message: TextSpan(text: appLocalizations.resetTip),
                  );
                  if (res != true) {
                    return;
                  }
                  ref
                      .read(networkSettingProvider.notifier)
                      .updateState(
                        (state) =>
                            state.copyWith(bypassDomain: defaultBypassDomain),
                      );
                },
                tooltip: appLocalizations.reset,
                icon: const Icon(Icons.replay),
              );
            },
          ),
        ],
        title: appLocalizations.bypassDomain,
        widget: Consumer(
          builder: (_, ref, _) {
            final bypassDomain = ref.watch(
              networkSettingProvider.select((state) => state.bypassDomain),
            );
            return ListInputPage(
              title: appLocalizations.bypassDomain,
              items: bypassDomain,
              titleBuilder: (item) => Text(item),
              onChange: (items) {
                ref
                    .read(networkSettingProvider.notifier)
                    .updateState(
                      (state) => state.copyWith(bypassDomain: List.from(items)),
                    );
              },
            );
          },
        ),
      ),
    );
  }
}

class BypassPrivateRouteItem extends ConsumerWidget {
  const BypassPrivateRouteItem({super.key});

  void _showEditPage(BuildContext context, WidgetRef ref) {
    showExtend(
      context,
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        title: appLocalizations.bypassPrivateRoute,
        actions: [
          Consumer(
            builder: (_, ref, _) {
              return IconButton(
                onPressed: () async {
                  final res = await globalState.showMessage(
                    title: appLocalizations.reset,
                    message: TextSpan(text: appLocalizations.resetTip),
                  );
                  if (res != true) return;
                  ref
                      .read(networkSettingProvider.notifier)
                      .updateState(
                        (state) => state.copyWith(
                          bypassPrivateRouteAddress: system.isDesktop
                              ? defaultDesktopBypassPrivateRouteAddress
                              : defaultBypassPrivateRouteAddress,
                        ),
                      );
                  await _handleNetworkConfigChange(ref);
                },
                tooltip: appLocalizations.reset,
                icon: const Icon(Icons.replay),
              );
            },
          ),
        ],
        body: Consumer(
          builder: (_, ref, _) {
            final bypassPrivateRouteAddress = ref.watch(
              networkSettingProvider.select(
                (state) => state.realBypassPrivateRouteAddress,
              ),
            );
            return ListInputPage(
              title: appLocalizations.bypassPrivateRoute,
              items: bypassPrivateRouteAddress,
              titleBuilder: (item) => Text(item),
              onChange: (items) async {
                ref
                    .read(networkSettingProvider.notifier)
                    .updateState(
                      (state) => state.copyWith(
                        bypassPrivateRouteAddress: List.from(items),
                      ),
                    );
                await _handleNetworkConfigChange(ref);
              },
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, ref) {
    final bypassPrivateRoute = ref.watch(
      networkSettingProvider.select((state) => state.bypassPrivateRoute),
    );
    return ListItem.switchItem(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // item 4 — the label must be allowed to shrink: unwrapped it overflowed
          // the switch row by 13 px at 280 dp under the app's 1.4x text scale.
          Flexible(
            child: Text(
              appLocalizations.bypassPrivateRoute,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (system.isDesktop) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: appLocalizations.edit,
              child: InkResponse(
                radius: 16,
                onTap: () => _showEditPage(context, ref),
                child: Icon(
                  Icons.settings_outlined,
                  size: 18,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(appLocalizations.bypassPrivateRouteDesc),
      delegate: SwitchDelegate(
        value: bypassPrivateRoute,
        onChanged: (value) async {
          ref
              .read(networkSettingProvider.notifier)
              .updateState(
                (state) => state.copyWith(bypassPrivateRoute: value),
              );
          await _handleNetworkConfigChange(ref);
        },
      ),
    );
  }
}

final networkItems = [
  if (system.isAndroid) ...generateSection(items: const [VPNItem()]),
  if (system.isAndroid)
    ...generateSection(
      title: 'VPN',
      items: [const AllowBypassItem(), const VpnSystemProxyItem()],
    ),
  if (system.isDesktop)
    ...generateSection(
      title: appLocalizations.system,
      items: [SystemProxyItem(), BypassDomainItem()],
    ),
  ...generateSection(
    title: appLocalizations.options,
    items: [
      if (system.isDesktop) const TUNItem(),
      if (system.isMacOS || system.isLinux) const AutoSetSystemDnsItem(),
      if (!system.isAndroid) const StrictRouteItem(),
      const IcmpForwardingItem(),
      const DnsHijackItem(),
      const EndpointIndependentNatItem(),
      const TunStackItem(),
      const TunDnsModeItem(),
      const MtuItem(),
      const BypassPrivateRouteItem(),
    ],
  ),
];

class NetworkListView extends StatelessWidget {
  const NetworkListView({super.key});

  @override
  Widget build(BuildContext context) {
    return generateListView(networkItems);
  }
}
