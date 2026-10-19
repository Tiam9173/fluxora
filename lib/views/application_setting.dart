import 'package:fluxora/common/common.dart';
import 'package:fluxora/providers/config.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluxora/state.dart';

class CloseConnectionsItem extends ConsumerWidget {
  const CloseConnectionsItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final closeConnections = ref.watch(
      appSettingProvider.select((state) => state.closeConnections),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.autoCloseConnections),
      subtitle: Text(appLocalizations.autoCloseConnectionsDesc),
      delegate: SwitchDelegate(
        value: closeConnections,
        onChanged: (value) async {
          ref
              .read(appSettingProvider.notifier)
              .updateState((state) => state.copyWith(closeConnections: value));
        },
      ),
    );
  }
}

class UsageItem extends ConsumerWidget {
  const UsageItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final onlyStatisticsProxy = ref.watch(
      appSettingProvider.select((state) => state.onlyStatisticsProxy),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.onlyStatisticsProxy),
      subtitle: Text(appLocalizations.onlyStatisticsProxyDesc),
      delegate: SwitchDelegate(
        value: onlyStatisticsProxy,
        onChanged: (bool value) async {
          ref
              .read(appSettingProvider.notifier)
              .updateState(
                (state) => state.copyWith(onlyStatisticsProxy: value),
              );
        },
      ),
    );
  }
}

class AutoLaunchItem extends ConsumerWidget {
  const AutoLaunchItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoLaunch = ref.watch(
      appSettingProvider.select((state) => state.autoLaunch),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.autoLaunch),
      subtitle: Text(appLocalizations.autoLaunchDesc),
      delegate: SwitchDelegate(
        value: autoLaunch,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .updateState((state) => state.copyWith(autoLaunch: value));
        },
      ),
    );
  }
}

class SilentLaunchItem extends ConsumerWidget {
  const SilentLaunchItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final silentLaunch = ref.watch(
      appSettingProvider.select((state) => state.silentLaunch),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.silentLaunch),
      subtitle: Text(appLocalizations.silentLaunchDesc),
      delegate: SwitchDelegate(
        value: silentLaunch,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .updateState((state) => state.copyWith(silentLaunch: value));
        },
      ),
    );
  }
}

class AutoRunItem extends ConsumerWidget {
  const AutoRunItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoRun = ref.watch(
      appSettingProvider.select((state) => state.autoRun),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.autoRun),
      subtitle: Text(appLocalizations.autoRunDesc),
      delegate: SwitchDelegate(
        value: autoRun,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .updateState((state) => state.copyWith(autoRun: value));
        },
      ),
    );
  }
}

class HiddenItem extends ConsumerWidget {
  const HiddenItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(
      appSettingProvider.select((state) => state.hidden),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.exclude),
      subtitle: Text(appLocalizations.excludeDesc),
      delegate: SwitchDelegate(
        value: hidden,
        onChanged: (value) {
          ref
              .read(appSettingProvider.notifier)
              .updateState((state) => state.copyWith(hidden: value));
        },
      ),
    );
  }
}


class ShowStartSwitchItem extends ConsumerWidget {
  const ShowStartSwitchItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showStartSwitch = ref.watch(
      appSettingProvider.select((state) => state.showStartSwitch),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.showStartSwitch),
      subtitle: Text(appLocalizations.showStartSwitchDesc),
      delegate: SwitchDelegate(
        value: showStartSwitch,
        onChanged: (value) {
          ref
              .read(appSettingProvider.notifier)
              .updateState((state) => state.copyWith(showStartSwitch: value));
        },
      ),
    );
  }
}

class AlwaysShowTitleBarItem extends ConsumerWidget {
  const AlwaysShowTitleBarItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alwaysShowTitleBar = ref.watch(
      vpnSettingProvider.select((state) => state.alwaysShowTitleBar),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.alwaysShowTitleBar),
      subtitle: Text(appLocalizations.alwaysShowTitleBarDesc),
      delegate: SwitchDelegate(
        value: alwaysShowTitleBar,
        onChanged: (bool value) async {
          ref
              .read(vpnSettingProvider.notifier)
              .updateState(
                (state) => state.copyWith(alwaysShowTitleBar: value),
              );
        },
      ),
    );
  }
}

class NavBarHapticFeedbackItem extends ConsumerWidget {
  const NavBarHapticFeedbackItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enableNavBarHapticFeedback = ref.watch(
      appSettingProvider.select((state) => state.enableNavBarHapticFeedback),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.navBarHapticFeedback),
      subtitle: Text(appLocalizations.navBarHapticFeedbackDesc),
      delegate: SwitchDelegate(
        value: enableNavBarHapticFeedback,
        onChanged: (value) {
          ref
              .read(appSettingProvider.notifier)
              .updateState(
                (state) => state.copyWith(enableNavBarHapticFeedback: value),
              );
        },
      ),
    );
  }
}

class AutoCheckUpdateItem extends ConsumerWidget {
  const AutoCheckUpdateItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoCheckUpdate = ref.watch(
      appSettingProvider.select((state) => state.autoCheckUpdate),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.autoCheckUpdate),
      subtitle: Text(appLocalizations.autoCheckUpdateDesc),
      delegate: SwitchDelegate(
        value: autoCheckUpdate,
        onChanged: (bool value) {
          ref
              .read(appSettingProvider.notifier)
              .updateState((state) => state.copyWith(autoCheckUpdate: value));
        },
      ),
    );
  }
}

class ApplicationSettingView extends StatelessWidget {
  const ApplicationSettingView({super.key});

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [
      AutoLaunchItem(),
      if (system.isDesktop) ...[SilentLaunchItem()],
      AutoRunItem(),
      if (system.isAndroid) ...[HiddenItem()],
      if (system.isDesktop) ...[
        if (system.isWindows || system.isLinux)
          const AlwaysShowTitleBarItem(),
      ],
      const ShowStartSwitchItem(),
      if (system.isAndroid) ...[
        NavBarHapticFeedbackItem(),
        const RestartCoreKeepServiceItem(),
      ],
      CloseConnectionsItem(),
      UsageItem(),
      AutoCheckUpdateItem(),
    ];
    return generateListView(generateSection(items: items));
  }
}

/// 重启内核的两种语义。
///
/// 关闭（默认，Bettbox 行为）：服务状态跟着内核走，通知栏会看到短暂断开。
/// 打开：重启期间保持隧道在线，所有 App 不会掉网。
class RestartCoreKeepServiceItem extends StatefulWidget {
  const RestartCoreKeepServiceItem({super.key});

  @override
  State<RestartCoreKeepServiceItem> createState() =>
      _RestartCoreKeepServiceItemState();
}

class _RestartCoreKeepServiceItemState
    extends State<RestartCoreKeepServiceItem> {
  static const String _key = 'restart_core_keeps_service';

  @override
  void initState() {
    super.initState();
    Preferences().sharedPreferencesCompleter.future.then((prefs) {
      final value = prefs?.getBool(_key) ?? false;
      globalState.restartCoreKeepsService = value;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListItem.switchItem(
      title: const Text('重启内核时保持服务在线'),
      subtitle: const Text('关闭时服务状态跟随内核（通知栏会短暂显示断开）'),
      delegate: SwitchDelegate(
        value: globalState.restartCoreKeepsService,
        onChanged: (value) async {
          globalState.restartCoreKeepsService = value;
          final prefs = await Preferences().sharedPreferencesCompleter.future;
          await prefs?.setBool(_key, value);
          if (mounted) setState(() {});
        },
      ),
    );
  }
}
