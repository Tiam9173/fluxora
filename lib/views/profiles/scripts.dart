import 'dart:convert';

import 'package:fluxora/clash/clash.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/pages/editor.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/card.dart';
import 'package:fluxora/widgets/dialog.dart';
import 'package:fluxora/widgets/icon.dart';
import 'package:fluxora/widgets/input.dart';
import 'package:fluxora/widgets/list.dart';
import 'package:fluxora/widgets/null_status.dart';
import 'package:fluxora/widgets/pop_scope.dart';
import 'package:fluxora/widgets/popup.dart';
import 'package:fluxora/widgets/scaffold.dart';
import 'package:fluxora/widgets/scroll.dart';
import 'package:fluxora/widgets/sheet.dart';
import 'package:fluxora/widgets/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _isExtractingCustomOptions = false;
const Duration _kMinLoadingDuration = Duration(seconds: 1);
const Duration _kCachedMinLoadingDuration = Duration(milliseconds: 500);

(Map<String, bool>, Map<String, String>) _processScriptData(
  Map<String, dynamic> data,
  Script script,
) {
  final rawOptions = data['options'];
  final rawIcons = data['icons'];

  final options = <String, bool>{};
  if (rawOptions is Map) {
    rawOptions.forEach((k, v) {
      options[k.toString()] = v is bool ? v : true;
    });
  }
  if (script.customOptions != null) {
    script.customOptions!.forEach((k, v) {
      if (options.containsKey(k)) {
        options[k] = v;
      }
    });
  }

  final icons = <String, String>{};
  if (rawIcons is Map) {
    rawIcons.forEach((k, v) {
      if (v != null) {
        icons[k.toString()] = v.toString();
      }
    });
  }
  return (options, icons);
}

Future<void> showScriptCustomOptions(
  BuildContext context,
  WidgetRef ref, {
  required Script script,
}) async {
  if (_isExtractingCustomOptions) return;
  _isExtractingCustomOptions = true;
  try {
    await globalState.appController.safeRun(
      silence: false,
      needLoading: true,
      () async {
        final stopwatch = Stopwatch()..start();
        final content = await script.readContent();
        final cached = JavaScriptRuntimeManager.getCachedOptions(content);
        final data = cached ??
            await JavaScriptRuntimeManager.extractScriptOptions(content);
        final (options, icons) = _processScriptData(data, script);

        final targetDuration = cached != null
            ? _kCachedMinLoadingDuration
            : _kMinLoadingDuration;
        final remaining =
            targetDuration.inMilliseconds - stopwatch.elapsedMilliseconds;
        if (remaining > 0) {
          await Future.delayed(Duration(milliseconds: remaining));
        }

        if (!context.mounted) return;

        showExtend(
          context,
          builder: (_, type) {
            return _ScriptCustomOptionsSheet(
              type: type,
              script: script,
              initialOptions: options,
              icons: icons,
            );
          },
        );
      },
    );
  } finally {
    _isExtractingCustomOptions = false;
  }
}

/// Upstream c0cce973 — the file name a script exports as.
///
/// The label is a human name, not a file name: the `.js` suffix is enforced
/// here (an extensionless file is awkward to re-import on desktop), and a blank
/// label — which the editor normally prevents — falls back instead of producing
/// a hidden `.js`.
String scriptExportFileName(String label) {
  final rawName = label.trim();
  if (rawName.isEmpty) {
    return 'script.js';
  }
  return rawName.endsWith('.js') ? rawName : '$rawName.js';
}

class ScriptsView extends ConsumerStatefulWidget {
  const ScriptsView({super.key});

  @override
  ConsumerState<ScriptsView> createState() => _ScriptsViewState();
}

class _ScriptsViewState extends ConsumerState<ScriptsView> {
  Future<void> _handleDelScript(String label) async {
    final res = await globalState.showMessage(
      message: TextSpan(
        text: appLocalizations.deleteTip(appLocalizations.script),
      ),
    );
    if (res != true) {
      return;
    }
    await ref.read(scriptStateProvider.notifier).del(label);
  }

  Future<void> _handleSyncScript(String id) async {
    await globalState.appController.safeRun(
      silence: false,
      () async {
        await ref.read(scriptStateProvider.notifier).syncScript(id);
        globalState.showNotifier(appLocalizations.success);
      },
    );
  }

  Future<void> _handleCustomOptions(Script script) async {
    await showScriptCustomOptions(context, ref, script: script);
  }

  /// Upstream c0cce973 — write the script to a user-chosen `.js` file.
  ///
  /// The save dialog is the platform's own picker (`picker.saveFile` writes the
  /// bytes itself), so the content never round-trips through app state. A null
  /// path means the user cancelled, which is not an error worth reporting.
  Future<void> _handleExportFile(Script script) async {
    final res = await globalState.appController.safeRun<bool>(
      () async {
        final path = await picker.saveFile(
          scriptExportFileName(script.label),
          utf8.encode(await script.readContent()),
          allowedExtensions: ['js'],
        );
        return path != null;
      },
      needLoading: true,
      title: appLocalizations.tip,
    );
    if (res == true && mounted) {
      context.showNotifier(appLocalizations.exportSuccess);
    }
  }

  void _handleShowScriptSettings() {
    showSheet(
      context: context,
      builder: (_, type) {
        return _ScriptSettingsSheet(type: type);
      },
    );
  }

  Widget _buildContent() {
    return Consumer(
      builder: (_, ref, _) {
        final vm2 = ref.watch(
          scriptStateProvider.select(
            (state) => VM2(a: state.currentId, b: state.scripts),
          ),
        );
        final currentId = vm2.a;
        final scripts = vm2.b;
        if (scripts.isEmpty) {
          return NullStatus(
            label: appLocalizations.nullTip(appLocalizations.script),
          );
        }
        return CommonScrollBar(
          controller: null,
          child: ListView.builder(
            padding: kMaterialListPadding.copyWith(bottom: 16 + 64),
            itemCount: scripts.length,
            itemBuilder: (_, index) {
              final script = scripts[index];
              final isSelected = script.id == currentId;
              return Container(
                padding: kTabLabelPadding,
                margin: EdgeInsets.symmetric(vertical: 6),
                child: CommonCard(
                  type: CommonCardType.filled,
                  radius: 16,
                  child: ListItem(
                    padding: const EdgeInsets.only(left: 12, right: 12),
                    title: EmojiText(script.label),
                    leading: Switch(
                      value: isSelected,
                      onChanged: (value) {
                        if (value) {
                          ref.read(scriptStateProvider.notifier).setId(script.id);
                        } else if (isSelected) {
                          ref.read(scriptStateProvider.notifier).setId(script.id);
                        }
                      },
                    ),
                    trailing: CommonPopupBox(
                      targetBuilder: (open) {
                        return IconButton(
                          onPressed: () {
                            open();
                          },
                          tooltip: appLocalizations.more,
                          icon: Icon(Icons.more_vert),
                        );
                      },
                      popup: CommonPopupMenu(
                        items: [
                          PopupMenuItemData(
                            icon: Icons.edit,
                            label: appLocalizations.edit,
                            onPressed: () {
                              _handleToEditor(script: script);
                            },
                          ),
                          if (script.isCompatibleWithFluxora)
                            PopupMenuItemData(
                              icon: Icons.tune,
                              label: appLocalizations.custom,
                              onPressed: () {
                                _handleCustomOptions(script);
                              },
                            ),
                          if (script.url != null && script.url!.isNotEmpty)
                            PopupMenuItemData(
                              icon: Icons.sync,
                              label: appLocalizations.sync,
                              onPressed: () {
                                _handleSyncScript(script.id);
                              },
                            ),
                          PopupMenuItemData(
                            icon: Icons.file_copy_outlined,
                            label: appLocalizations.exportFile,
                            onPressed: () {
                              _handleExportFile(script);
                            },
                          ),
                          PopupMenuItemData(
                            icon: Icons.delete,
                            label: appLocalizations.delete,
                            onPressed: () {
                              _handleDelScript(script.label);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _handleEditorSave(
    BuildContext _,
    String title,
    String content, {
    Script? script,
    String? url,
  }) async {
    final oldContent = script == null ? null : await script.readContent();
    if (oldContent != null && oldContent != content) {
      JavaScriptRuntimeManager.invalidateCachedOptions(oldContent);
    }
    var finalLabel = title.trim();
    if (finalLabel.isEmpty) {
      finalLabel = ref
          .read(scriptStateProvider.notifier)
          .getAvailableLabel(appLocalizations.unnamed);
    }
    final draft =
        script?.copyWith(label: finalLabel, url: url) ??
        Script.create(label: finalLabel, url: url);
    if (draft.label != script?.label) {
      final isExits = ref
          .read(scriptStateProvider.notifier)
          .isExits(draft.label);
      if (isExits) {
        globalState.showMessage(
          message: TextSpan(
            text: appLocalizations.existsTip(appLocalizations.name),
          ),
          cancelable: false,
        );
        return;
      }
    }
    final newScript = await globalState.appController.safeRun(
      silence: false,
      () => draft.writeContent(content),
    );
    if (newScript == null || !mounted) return;
    ref.read(scriptStateProvider.notifier).setScript(newScript);
    Navigator.of(context).pop();
  }

  Future<bool> _handleEditorPop(
    BuildContext _,
    String title,
    String content,
    String raw, {
    Script? script,
  }) async {
    if (content == raw) {
      return true;
    }
    final res = await globalState.showMessage(
      message: TextSpan(text: appLocalizations.saveChanges),
    );
    if (res == true && mounted) {
      _handleEditorSave(context, title, content, script: script, url: script?.url);
    } else {
      return true;
    }
    return false;
  }

  Future<void> _handleToEditor({
    Script? script,
    String? initialContent,
    String? url,
    String? fileName,
    bool delayedFocus = false,
  }) async {
    final raw = initialContent ?? await script?.readContent() ?? scriptTemplate;
    // 没有现成名字时，从脚本内容或链接推断一个，省得列表里全是「未命名」。
    final title =
        script?.label ??
        suggestScriptLabel(content: raw, url: url, fileName: fileName) ??
        '';
    if (!mounted) return;
    String? importedUrl = url ?? script?.url;
    BaseNavigator.push(
      context,
      EditorPage(
        titleEditable: true,
        // 新建脚本时保存按钮必须可用：标题已经自动填好，内容和初始内容一样，
        // 只靠"有没有改动"判断的话按钮会一直是灰的。
        isNew: script == null,
        title: title,
        supportRemoteDownload: true,
        delayedFocus: delayedFocus,
        onUrlImport: (downloadedUrl) {
          importedUrl = downloadedUrl;
        },
        onSave: (context, title, content) {
          final scriptToSave = script != null
              ? script.copyWith(url: importedUrl)
              : null;
          _handleEditorSave(context, title, content, script: scriptToSave, url: importedUrl);
        },
        onPop: (context, title, content) {
          return _handleEditorPop(context, title, content, raw, script: script);
        },
        languages: const [Language.javaScript],
        content: raw,
      ),
    );
  }

  Future<void> _handleImport() async {
    final option = await globalState.showCommonDialog<ImportOption>(
      child: const _ScriptImportOptionsDialog(),
    );
    if (option == null) {
      return;
    }

    switch (option) {
      case ImportOption.code:
        _handleToEditor(delayedFocus: true);
      case ImportOption.url:
        await _handleUrlImport();
      case ImportOption.file:
        await _handleFileImport();
    }
  }

  Future<void> _handleUrlImport() async {
    final url = await globalState.showCommonDialog<String>(
      child: InputDialog(
        title: appLocalizations.importUrl,
        value: '',
        labelText: appLocalizations.url,
        delayedFocus: true,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return appLocalizations.emptyTip(appLocalizations.value);
          }
          if (!value.isUrl) {
            return appLocalizations.urlTip(appLocalizations.value);
          }
          return null;
        },
      ),
    );
    if (url == null || url.isEmpty) {
      return;
    }

    try {
      final res = await request.getTextResponseForUrl(url);
      if (!JavaScriptRuntimeManager.looksLikeScript(res.data)) {
        // 直接进编辑器再存下来，只会在启用脚本时报一句看不懂的语法错误。
        globalState.showMessage(
          message: TextSpan(text: appLocalizations.scriptUrlNotAScript),
          cancelable: false,
        );
        return;
      }
      if (mounted) {
        _handleToEditor(initialContent: res.data, url: url);
      }
    } catch (e) {
      globalState.showMessage(
        message: TextSpan(text: '${appLocalizations.importFailed}: $e'),
        cancelable: false,
      );
    }
  }

  Future<void> _handleFileImport() async {
    final file = await picker.pickerFile();
    if (file == null) {
      return;
    }
    final bytes = file.bytes;
    if (bytes == null) {
      return;
    }
    final content = utf8.decode(bytes);
    if (mounted) {
      _handleToEditor(initialContent: content, fileName: file.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _handleImport();
        },
        child: Icon(Icons.add),
      ),
      actions: [
        IconButton(
          onPressed: _handleShowScriptSettings,
          tooltip: appLocalizations.settings,
          icon: Icon(Icons.settings),
        ),
      ],
      body: _buildContent(),
      title: appLocalizations.script,
    );
  }
}

class _ScriptSettingsSheet extends ConsumerWidget {
  final SheetType type;

  const _ScriptSettingsSheet({
    required this.type,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final currentProfileId = ref.watch(currentProfileIdProvider);
    return AdaptiveSheetScaffold(
      type: type,
      body: profiles.isEmpty
          ? NullStatus(label: appLocalizations.nullProfileDesc)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              itemCount: profiles.length,
              itemBuilder: (_, index) {
                final profile = profiles[index];
                final isCurrentProfile = profile.id == currentProfileId;
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: CommonCard(
                    type: CommonCardType.filled,
                    child: ListTile(
                      contentPadding: const EdgeInsets.only(left: 16, right: 16),
                      title: EmojiText(profile.label ?? profile.id),
                      trailing: Switch(
                        value: profile.useScriptOverride,
                        onChanged: (value) async {
                          ref.read(profilesProvider.notifier).updateProfile(
                            profile.id,
                            (p) => p.copyWith(useScriptOverride: value),
                          );
                          if (isCurrentProfile) {
                            await globalState.appController.applyProfile(silence: true);
                          }
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
      title: appLocalizations.useGlobalScriptOverride,
    );
  }
}

class _ScriptImportOptionsDialog extends StatelessWidget {
  const _ScriptImportOptionsDialog();

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: appLocalizations.import,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Wrap(
        children: [
          ListItem(
            onTap: () {
              Navigator.of(context).pop(ImportOption.code);
            },
            leading: const Icon(Icons.code),
            title: Text(appLocalizations.importFromCode),
          ),
          ListItem(
            onTap: () {
              Navigator.of(context).pop(ImportOption.url);
            },
            leading: const Icon(Icons.link),
            title: Text(appLocalizations.importUrl),
          ),
          ListItem(
            onTap: () {
              Navigator.of(context).pop(ImportOption.file);
            },
            leading: const Icon(Icons.file_open),
            title: Text(appLocalizations.importFile),
          ),
        ],
      ),
    );
  }
}

class _ScriptCustomOptionsSheet extends ConsumerStatefulWidget {
  final SheetType type;
  final Script script;
  final Map<String, bool> initialOptions;
  final Map<String, String> icons;

  const _ScriptCustomOptionsSheet({
    required this.type,
    required this.script,
    required this.initialOptions,
    required this.icons,
  });

  @override
  ConsumerState<_ScriptCustomOptionsSheet> createState() =>
      __ScriptCustomOptionsSheetState();
}

class __ScriptCustomOptionsSheetState
    extends ConsumerState<_ScriptCustomOptionsSheet> {
  late Map<String, bool> _options;
  bool _dirty = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _options = Map<String, bool>.from(widget.initialOptions);
  }

  bool get _hasUnsavedChanges => _dirty;

  Future<void> _handleSave() async {
    if (_isSaving) return;
    final scripts = ref.read(scriptStateProvider).scripts;
    final index = scripts.indexWhere((item) => item.id == widget.script.id);
    if (index == -1) {
      _dirty = false;
      if (mounted) setState(() {});
      return;
    }
    final currentScript = scripts[index];
    final updatedScript = currentScript.copyWith(
      customOptions: Map<String, bool>.from(_options),
    );
    ref.read(scriptStateProvider.notifier).setScript(updatedScript);
    _dirty = false;
    if (mounted) setState(() => _isSaving = true);
    try {
      final applyFuture = ref.read(scriptStateProvider).currentId == widget.script.id
          ? globalState.appController.applyProfile(silence: true)
          : Future.value();
      await Future.wait([
        applyFuture,
        Future.delayed(_kMinLoadingDuration),
      ]);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop();
      }
    }
  }

  void _onOptionChanged(String key, bool value) {
    setState(() {
      _options[key] = value;
      _dirty = true;
    });
  }

  Future<bool> _confirmDiscard() async {
    if (_isSaving) return false;
    if (!_hasUnsavedChanges) return true;
    final res = await globalState.showCommonDialog<bool>(
      child: CommonDialog(
        title: appLocalizations.saveChanges,
        actions: [
          TextButton(
            onPressed: () => globalState.navigatorKey.currentState?.pop(false),
            child: Text(appLocalizations.cancel),
          ),
          FilledButton(
            onPressed: () =>
                globalState.navigatorKey.currentState?.pop(true),
            child: Text(appLocalizations.save),
          ),
        ],
      ),
    );
    if (res == true) {
      await _handleSave();
      return false;
    }
    return res == false;
  }

  bool _isValidIconUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('data:image/');
  }

  @override
  Widget build(BuildContext context) {
    final keys = _options.keys.toList();
    return CommonPopScope(
      onPop: _confirmDiscard,
      child: AbsorbPointer(
        absorbing: _isSaving,
        child: AdaptiveSheetScaffold(
          type: widget.type,
          title: appLocalizations.customScriptOptions,
          actions: [
            IconButton(
              onPressed: (_dirty && !_isSaving) ? _handleSave : null,
              icon: const Icon(Icons.save),
              tooltip: appLocalizations.save,
            ),
          ],
          body: Column(
            children: [
              if (_isSaving)
                LinearProgressIndicator(
                  minHeight: 2,
                  color: context.colorScheme.primary,
                ),
              Expanded(
                child: keys.isEmpty
                    ? NullStatus(label: appLocalizations.noStatusAvailable)
                    : RepaintBoundary(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          itemCount: keys.length,
                          itemBuilder: (_, index) {
                            final key = keys[index];
                            final val = _options[key] ?? true;
                            final iconUrl = widget.icons[key];
                            return RepaintBoundary(
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: CommonCard(
                                  type: CommonCardType.filled,
                                  child: ListTile(
                                    contentPadding:
                                        const EdgeInsets.only(left: 16, right: 16),
                                    leading: _isValidIconUrl(iconUrl)
                                        ? CommonTargetIcon(src: iconUrl!, size: 24)
                                        : const Icon(Icons.alt_route),
                                    title: Text(key),
                                    trailing: Switch(
                                      value: val,
                                      onChanged: (v) {
                                        _onOptionChanged(key, v);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showGroupSwitchOptions(
  BuildContext context,
  WidgetRef ref, {
  required String profileId,
}) async {
  await globalState.appController.safeRun(
    silence: false,
    needLoading: true,
    () async {
      final stopwatch = Stopwatch()..start();
      final rawConfig = await globalState.getProfileConfig(profileId);
      final rules = rawConfig['rules'] as List? ?? [];
      final proxyGroups = rawConfig['proxy-groups'] as List? ?? [];
      final mode = ref.read(patchClashConfigProvider).mode;
      String? matchTarget;
      for (final rule in rules) {
        if (rule is String) {
          final parsed = ParsedRule.parseString(rule);
          if (parsed.ruleAction == RuleAction.MATCH &&
              parsed.ruleTarget != null &&
              parsed.ruleTarget!.isNotEmpty) {
            matchTarget = parsed.ruleTarget;
            break;
          }
        }
      }

      final remaining =
          _kMinLoadingDuration.inMilliseconds -
          stopwatch.elapsedMilliseconds;
      if (remaining > 0) {
        await Future.delayed(Duration(milliseconds: remaining));
      }

      if (!context.mounted) return;

      showExtend(
        context,
        builder: (_, type) {
          return _GroupSwitchOptionsSheet(
            type: type,
            profileId: profileId,
            matchTarget: matchTarget,
            mode: mode,
            groupNames: [
              for (final g in proxyGroups)
                if (g is Map && g['name'] is String) g['name'] as String,
            ],
          );
        },
      );
    },
  );
}

class _GroupSwitchOptionsSheet extends ConsumerStatefulWidget {
  final SheetType type;
  final String profileId;
  final String? matchTarget;
  final Mode mode;
  final List<String> groupNames;

  const _GroupSwitchOptionsSheet({
    required this.type,
    required this.profileId,
    required this.matchTarget,
    required this.mode,
    required this.groupNames,
  });

  @override
  ConsumerState<_GroupSwitchOptionsSheet> createState() =>
      _GroupSwitchOptionsSheetState();
}

class _GroupSwitchOptionsSheetState
    extends ConsumerState<_GroupSwitchOptionsSheet> {
  late Map<String, bool> _options;
  late Map<String, bool> _originalOptions;
  late Set<String> _lockedGroups;
  bool _dirty = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentProfileProvider);
    final groupSwitches = profile?.groupSwitches ?? {};
    final isGlobalMode = widget.mode == Mode.global;

    _options = {
      for (final name in widget.groupNames)
        if (isGlobalMode || name != 'GLOBAL')
          name: groupSwitches[name] ?? true,
    };
    _originalOptions = Map<String, bool>.from(_options);
    _lockedGroups = _computeLockedGroups();
  }

  Set<String> _computeLockedGroups() {
    final locked = <String>{};
    final firstNonGlobal = _options.keys.firstWhere(
      (k) => k != 'GLOBAL',
      orElse: () => '',
    );
    if (firstNonGlobal.isNotEmpty) {
      locked.add(firstNonGlobal);
    }
    if (widget.mode == Mode.global && _options.containsKey('GLOBAL')) {
      locked.add('GLOBAL');
    }
    final matchTarget = widget.matchTarget;
    if (matchTarget != null && matchTarget.isNotEmpty) {
      locked.add(matchTarget);
    }
    return locked;
  }

  bool get _hasUnsavedChanges => _dirty;

  void _onOptionChanged(String key, bool value) {
    setState(() {
      _options[key] = value;
      _dirty = true;
    });
  }

  Future<bool> _confirmDiscard() async {
    if (_isSaving) return false;
    if (!_hasUnsavedChanges) return true;
    final res = await globalState.showCommonDialog<bool>(
      child: CommonDialog(
        title: appLocalizations.saveChanges,
        actions: [
          TextButton(
            onPressed: () => globalState.navigatorKey.currentState?.pop(false),
            child: Text(appLocalizations.cancel),
          ),
          FilledButton(
            onPressed: () =>
                globalState.navigatorKey.currentState?.pop(true),
            child: Text(appLocalizations.save),
          ),
        ],
      ),
    );
    if (res == true) {
      await _handleSave();
      return false;
    }
    return res == false;
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (widget.profileId != ref.read(currentProfileIdProvider)) {
      _dirty = false;
      if (mounted) setState(() {});
      return;
    }

    if (mounted) setState(() => _isSaving = true);

    try {
      final validOptions = {
        for (final name in widget.groupNames) name: _options[name] ?? true,
      };

      ref.read(profilesProvider.notifier).updateProfile(
        widget.profileId,
        (state) => state.copyWith(groupSwitches: validOptions),
      );

      final patchConfig = ref.read(patchClashConfigProvider);
      final rawConfig = await globalState.patchRawConfig(
        patchConfig: patchConfig,
      );

      final configForValidation = Map<String, dynamic>.from(rawConfig);
      if (configForValidation.containsKey('rule')) {
        configForValidation['rules'] = configForValidation.remove('rule');
      }

      final message = await clashCore.validateConfig(
        json.encode(configForValidation),
      );

      if (message.isNotEmpty) {
        ref.read(profilesProvider.notifier).updateProfile(
          widget.profileId,
          (state) => state.copyWith(groupSwitches: _originalOptions),
        );
        if (mounted) {
          await globalState.showMessage(
            message: TextSpan(
              text: '${appLocalizations.profileParseErrorDesc}: $message',
            ),
            cancelable: false,
          );
        }
        return;
      }

      final applyFuture = globalState.appController.applyProfile(
        silence: true,
      );
      await Future.wait([
        applyFuture,
        Future.delayed(_kMinLoadingDuration),
      ]);

      _dirty = false;
      _originalOptions = Map<String, bool>.from(validOptions);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keys = _options.keys.toList();
    return CommonPopScope(
      onPop: _confirmDiscard,
      child: AbsorbPointer(
        absorbing: _isSaving,
        child: AdaptiveSheetScaffold(
          type: widget.type,
          title: appLocalizations.customScriptOptions,
          actions: [
            IconButton(
              onPressed: (_dirty && !_isSaving) ? _handleSave : null,
              icon: const Icon(Icons.save),
              tooltip: appLocalizations.save,
            ),
          ],
          body: Column(
            children: [
              if (_isSaving)
                LinearProgressIndicator(
                  minHeight: 2,
                  color: context.colorScheme.primary,
                ),
              Expanded(
                child: keys.isEmpty
                    ? NullStatus(label: appLocalizations.noStatusAvailable)
                    : RepaintBoundary(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          itemCount: keys.length,
                          itemBuilder: (_, index) {
                            final key = keys[index];
                            final val = _options[key] ?? true;
                            final locked = _lockedGroups.contains(key);
                            return RepaintBoundary(
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: CommonCard(
                                  type: CommonCardType.filled,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.only(
                                      left: 16,
                                      right: 16,
                                    ),
                                    leading: const Icon(Icons.alt_route),
                                    title: Text(key),
                                    trailing: Switch(
                                      value: val,
                                      onChanged: locked
                                          ? null
                                          : (v) {
                                              _onOptionChanged(key, v);
                                            },
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
