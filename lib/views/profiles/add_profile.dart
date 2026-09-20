import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/pages/scan.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'edit_profile.dart';
import 'profile_nodes_view.dart';

class AddProfileView extends StatelessWidget {
  final BuildContext context;

  const AddProfileView({super.key, required this.context});

  Future<void> _handleAddProfileFormFile() async {
    globalState.appController.addProfileFormFile();
  }

  Future<void> _handleAddProfileFormURL(String url, {String? ageSecretKey}) async {
    final editKey = GlobalKey<EditProfileViewState>();
    final profile = Profile.normal(
      url: url,
      ageSecretKey: ageSecretKey,
    );
    showExtend(
      context,
      builder: (_, type) {
        return AdaptiveSheetScaffold(
          type: type,
          actions: [
            IconButton(
              icon: const Icon(Icons.security),
              tooltip: appLocalizations.ageKeyGenerateTitle,
              onPressed: () {
                editKey.currentState?.showAgeKeyGenerator();
              },
            ),
          ],
          body: EditProfileView(
            key: editKey,
            profile: profile,
            context: context,
            isNew: true,
          ),
          title: appLocalizations.importFromURL,
        );
      },
    );
  }

  Future<void> _handleAddProfileFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text?.trim();

      if (text == null || text.isEmpty) {
        if (context.mounted) {
          context.showSnackBar(
            appLocalizations.emptyTip(appLocalizations.clipboard),
          );
        }
        return;
      }

      if (!text.isUrl) {
        if (context.mounted) {
          context.showSnackBar(
            appLocalizations.urlTip(appLocalizations.clipboard),
          );
        }
        return;
      }

      _handleAddProfileFormURL(text);
    } catch (e) {
      if (context.mounted) {
        context.showSnackBar(e.toString());
      }
    }
  }

  Future<void> _toScan() async {
    if (system.isDesktop) {
      globalState.appController.addProfileFormQrCode();
      return;
    }
    final url = await BaseNavigator.push(context, const ScanPage());
    if (url != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleAddProfileFormURL(url);
      });
    }
  }

  Future<void> _toAdd() async {
    _handleAddProfileFormURL('');
  }

  @override
  Widget build(context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        CommonCard(
          type: CommonCardType.filled,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListItem(
                leading: const Icon(Icons.qr_code_sharp),
                title: Text(appLocalizations.qrcode),
                subtitle: Text(appLocalizations.qrcodeDesc),
                onTap: _toScan,
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: context.colorScheme.outlineVariant.withValues(
                  alpha: context.colorScheme.brightness == Brightness.light ? 0.6 : 0.45,
                ),
                indent: 16,
                endIndent: 16,
              ),
              ListItem(
                leading: const Icon(Icons.content_paste),
                title: Text(appLocalizations.clipboard),
                subtitle: Text(appLocalizations.clipboardDesc),
                onTap: _handleAddProfileFromClipboard,
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: context.colorScheme.outlineVariant.withValues(
                  alpha: context.colorScheme.brightness == Brightness.light ? 0.6 : 0.45,
                ),
                indent: 16,
                endIndent: 16,
              ),
              ListItem(
                leading: const Icon(Icons.upload_file_sharp),
                title: Text(appLocalizations.file),
                subtitle: Text(appLocalizations.fileDesc),
                onTap: _handleAddProfileFormFile,
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: context.colorScheme.outlineVariant.withValues(
                  alpha: context.colorScheme.brightness == Brightness.light ? 0.6 : 0.45,
                ),
                indent: 16,
                endIndent: 16,
              ),
              ListItem(
                leading: const Icon(Icons.cloud_download_sharp),
                title: Text(appLocalizations.url),
                subtitle: Text(appLocalizations.urlDesc),
                onTap: _toAdd,
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: context.colorScheme.outlineVariant.withValues(
                  alpha: context.colorScheme.brightness == Brightness.light ? 0.6 : 0.45,
                ),
                indent: 16,
                endIndent: 16,
              ),
              ListItem(
                leading: const Icon(Icons.playlist_add_rounded, color: Colors.blueAccent),
                title: const Text('新建空白分组'),
                subtitle: const Text('创建一个新的空白配置，支持手动录入与管理全协议自建节点'),
                onTap: () => _handleCreateEmptyProfile(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleCreateEmptyProfile(BuildContext ctx) async {
    final nameCtrl = TextEditingController(text: '自建节点');
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.playlist_add_rounded, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text('新建空白分组'),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '创建空白分组后，您可以手动录入各协议节点或一键批量导入分享链接。',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '分组名称',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final groupName = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : '自建节点';

    const initialYaml = '''
mixed-port: 7890
allow-lan: false
mode: rule
log-level: info
proxies: []
proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - DIRECT
rules:
  - MATCH,PROXY
''';

    final newProfile = Profile.normal(label: groupName);
    try {
      final savedProfile = await newProfile.saveFileWithString(initialYaml);
      await globalState.appController.addProfile(savedProfile);
      if (!ctx.mounted) return;
      Navigator.of(ctx).pop(); // close add_profile sheet
      final navState = globalState.navigatorKey.currentState;
      if (navState != null && navState.mounted) {
        BaseNavigator.push(
          navState.context,
          ProfileNodesView(profile: savedProfile),
        );
        navState.context.showNotifier('空白分组 "$groupName" 创建成功，请添加节点');
      }
    } catch (e) {
      if (ctx.mounted) {
        ctx.showSnackBar('创建分组失败: $e');
      }
    }
  }
}
