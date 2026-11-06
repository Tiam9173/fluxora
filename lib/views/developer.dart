import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/common.dart';
import 'package:fluxora/providers/config.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeveloperView extends ConsumerWidget {
  const DeveloperView({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final enable = ref.watch(
      appSettingProvider.select((state) => state.developerMode),
    );
    final portFallbackNotice = ref.watch(
      vpnSettingProvider.select((state) => state.portFallbackNotice),
    );
    final items = [
      ...generateSection(
        items: [
          ListItem.switchItem(
            title: Text(appLocalizations.developerMode),
            delegate: SwitchDelegate(
              value: enable,
              onChanged: (value) {
                ref
                    .read(appSettingProvider.notifier)
                    .updateState(
                      (state) => state.copyWith(developerMode: value),
                    );
              },
            ),
          ),
        ],
      ),
      ...generateSection(
        title: appLocalizations.options,
        items: [
          // 端口避让本身是静默修好的行为，弹提示只在排查「LAN 分享地址连不上」
          // 时有用，所以放在开发者选项里、默认关。
          ListItem.switchItem(
            title: Text(appLocalizations.portFallbackNoticeSwitch),
            subtitle: Text(appLocalizations.portFallbackNoticeSwitchDesc),
            delegate: SwitchDelegate(
              value: portFallbackNotice,
              onChanged: (value) {
                ref
                    .read(vpnSettingProvider.notifier)
                    .updateState(
                      (state) => state.copyWith(portFallbackNotice: value),
                    );
              },
            ),
          ),
          ListItem(
            title: Text(appLocalizations.messageTest),
            onTap: () {
              context.showNotifier(appLocalizations.messageTestTip);
            },
          ),
          ListItem(
            title: Text(appLocalizations.logsTest),
            onTap: () {
              for (int i = 0; i < 100; i++) {
                globalState.appController.addLog(
                  Log.app(
                    '[$i]${utils.generateRandomString(maxLength: 200, minLength: 20)}',
                  ),
                );
              }
            },
          ),
          ListItem(
            title: Text(appLocalizations.clearData),
            onTap: () async {
              final res = await globalState.showMessage(
                title: appLocalizations.clearDataTipTitle,
                message: TextSpan(
                  text: appLocalizations.clearDataTipDesc,
                ),
              );
              if (res != true) return;
              await globalState.appController.handleClear();
            },
          ),
        ],
      ),
    ];
    return generateListView(items);
  }
}
