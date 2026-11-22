import 'dart:convert';

import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/proxy_icon_sets.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

final _serviceIcons = IconCollection(
  name: 'Fluxora services',
  icons: [
    for (final entry in ProxyIconSets.services.entries)
      CollectionIcon(
        name: entry.key
            .replaceFirst(RegExp(r'^\(\?i\)'), '')
            .replaceAll('|', ' / '),
        url: entry.value,
      ),
  ],
);

Future<String?> showProxyIconLibrary(
  BuildContext context, {
  String? groupName,
  String selected = '',
}) => showExtend<String>(
  context,
  props: const ExtendProps(maxWidth: 640),
  builder: (_, type) => AdaptiveSheetScaffold(
    type: type,
    title: Localizations.localeOf(context).languageCode == 'zh'
        ? '图标库'
        : 'Icon library',
    body: IconLibraryView(groupName: groupName, selected: selected),
  ),
);

class IconLibraryView extends ConsumerStatefulWidget {
  const IconLibraryView({
    this.groupName,
    this.selected = '',
    this.store,
    super.key,
  });

  final String? groupName;
  final String selected;
  final IconCollectionStore? store;

  @override
  ConsumerState<IconLibraryView> createState() => _IconLibraryViewState();
}

class _IconLibraryViewState extends ConsumerState<IconLibraryView> {
  final _search = TextEditingController();
  late final _store = widget.store ?? IconCollectionStore();
  List<IconCollection> _collections = [];
  IconCollection _active = _serviceIcons;
  bool _loading = true;
  bool _importing = false;
  String? _error;

  bool get _zh => Localizations.localeOf(context).languageCode == 'zh';
  bool get _storageUnavailable =>
      _error?.startsWith(_zh ? '图标库读取失败' : 'Icon sets could not be read') ==
      true;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCollections() async {
    try {
      final collections = await _store.load();
      if (mounted) setState(() => _collections = collections);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = _zh
              ? '图标库读取失败，现有数据未覆盖：$error'
              : 'Icon sets could not be read; saved data was left untouched: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openQure() async {
    setState(() => _importing = true);
    try {
      final content = await rootBundle.loadString(
        'assets/data/qure_icon_set.json',
      );
      final collection = IconCollection.parse(
        content,
        source: IconCollection.qureSource,
      );
      if (mounted) setState(() => _active = collection);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              '${_zh ? '无法加载 Qure 图标集' : 'Could not load Qure icon set'}: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _importFile() async {
    try {
      final file = await picker.pickerFile(
        withData: true,
        allowedExtensions: ['json'],
      );
      if (file?.bytes == null) return;
      if (file!.bytes!.length > IconCollection.maxBytes) {
        throw const FormatException('Icon collection exceeds 2 MiB');
      }
      await _addCollection(
        IconCollection.parse(utf8.decode(file.bytes!), source: file.name),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = '${_zh ? '导入失败' : 'Import failed'}: $error');
      }
    }
  }

  Future<void> _importUrl() async {
    final url = await globalState.showCommonDialog<String>(
      child: InputDialog(
        title: _zh ? '从链接导入图标集' : 'Import icon set from URL',
        value: '',
        labelText: _zh ? '图标集 URL' : 'Icon set URL',
        delayedFocus: true,
        validator: (value) => IconCollection.isWebUrl(value ?? '')
            ? null
            : (_zh ? '请输入有效的 HTTP(S) 地址' : 'Enter a valid HTTP(S) URL'),
      ),
    );
    if (url == null || !mounted) return;
    setState(() => _importing = true);
    try {
      await _addCollection(await IconCollection.download(url));
    } catch (error) {
      if (mounted) {
        setState(() => _error = '${_zh ? '导入失败' : 'Import failed'}: $error');
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _addCollection(IconCollection collection) async {
    if (_error != null &&
        _error!.startsWith(_zh ? '图标库读取失败' : 'Icon sets could not be read')) {
      throw const FormatException(
        'Resolve the stored icon-set error before importing',
      );
    }
    final duplicate = _collections.any((item) => item.name == collection.name);
    if (duplicate) {
      throw FormatException(
        _zh ? '已有同名图标集，请先移除旧图标集' : 'A set with this name already exists',
      );
    }
    final next = [..._collections, collection];
    await _store.save(next);
    if (mounted) {
      setState(() {
        _collections = next;
        _active = collection;
        _error = null;
      });
    }
  }

  Future<void> _removeCollection(IconCollection collection) async {
    final next = _collections.where((item) => item != collection).toList();
    try {
      await _store.save(next);
      if (mounted) {
        setState(() {
          _collections = next;
          if (_active == collection) _active = _serviceIcons;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = '${_zh ? '移除失败' : 'Could not remove set'}: $error',
        );
      }
    }
  }

  Future<void> _select(CollectionIcon icon) async {
    var url = icon.url;
    if (widget.groupName == null) {
      final rule = await globalState.showCommonDialog<String>(
        child: InputDialog(
          title: _zh ? '为名称添加图标匹配' : 'Match icon by name',
          value: '(?i)${RegExp.escape(icon.label)}',
          labelText: _zh ? '正则表达式' : 'Regular expression',
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return _zh ? '不能为空' : 'Required';
            }
            try {
              RegExp(value);
              return null;
            } on FormatException {
              return _zh ? '正则表达式无效' : 'Invalid regular expression';
            }
          },
        ),
      );
      if (rule == null) return;
      ref.read(proxiesStyleSettingProvider.notifier).updateState((state) {
        final rules = <String, String>{rule: url};
        for (final entry in state.iconMap.entries) {
          if (entry.key != rule) rules[entry.key] = entry.value;
        }
        return state.copyWith(
          iconStyle: state.iconStyle == ProxiesIconStyle.none
              ? ProxiesIconStyle.standard
              : state.iconStyle,
          iconMap: rules,
        );
      });
    } else {
      Navigator.of(context).pop(url);
    }
  }

  Future<void> _clearGroupIcon() async {
    Navigator.of(context).pop('');
  }

  @override
  Widget build(BuildContext context) {
    final icons = _active.icons
        .where((icon) {
          final query = _search.text.trim().toLowerCase();
          return query.isEmpty || icon.name.toLowerCase().contains(query);
        })
        .toList(growable: false);
    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final showRemove = _collections.contains(_active);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _collectionChip(
                  _serviceIcons,
                  label: _zh ? '内置服务' : _serviceIcons.name,
                ),
                _collectionChip(
                  IconCollection(name: 'Qure SVG', icons: const []),
                  onSelected: _openQure,
                ),
                for (final collection in _collections)
                  _collectionChip(collection),
                if (showRemove)
                  IconButton(
                    tooltip: _zh ? '移除当前图标集' : 'Remove current set',
                    onPressed: () => _removeCollection(_active),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: _zh ? '搜索图标' : 'Search icons',
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: _zh ? '清除搜索' : 'Clear search',
                      onPressed: () => setState(_search.clear),
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _loading || _importing || _storageUnavailable
                    ? null
                    : _importFile,
                icon: const Icon(Icons.file_open_outlined),
                label: Text(_zh ? '导入文件' : 'Import file'),
              ),
              OutlinedButton.icon(
                onPressed: _loading || _importing || _storageUnavailable
                    ? null
                    : _importUrl,
                icon: const Icon(Icons.link),
                label: Text(_zh ? '导入链接' : 'Import URL'),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_active.source == IconCollection.qureSource)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _zh
                    ? 'Qure Style SVG · aaANDkk · 非官方整理；参考/重绘图标仅供学习交流，不作商业盈利。第三方素材遵循原许可。'
                    : 'Unofficial Qure Style SVG set by aaANDkk. Reference/redrawn icons are for learning, not commercial use; third-party assets retain their own licenses.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 8),
          if (_importing || _loading)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : icons.isEmpty
                ? Center(child: Text(_zh ? '没有找到图标' : 'No icons found'))
                : GridView.builder(
                    key: ValueKey('${_active.name}-${_search.text}'),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: width < 360 ? 82 : 104,
                      mainAxisExtent: 96 + (textScale - 1).clamp(0, 1) * 24,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: icons.length,
                    itemBuilder: (context, index) {
                      final icon = icons[index];
                      final selected = icon.url == widget.selected;
                      return Material(
                        color: selected
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _select(icon),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CommonTargetIcon(src: icon.url, size: 36),
                                const SizedBox(height: 6),
                                Text(
                                  icon.label,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (widget.groupName != null && widget.selected.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _clearGroupIcon,
                icon: const Icon(Icons.remove_circle_outline),
                label: Text(_zh ? '恢复自动匹配' : 'Use automatic match'),
              ),
            ),
          if (_active.source == IconCollection.qureSource)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () =>
                    launchUrl(Uri.parse(IconCollection.qureSource)),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(_zh ? '查看来源与授权' : 'Source and license'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _collectionChip(
    IconCollection collection, {
    String? label,
    VoidCallback? onSelected,
  }) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label ?? collection.name),
      selected: _active == collection || _active.name == collection.name,
      onSelected: (_) => onSelected == null
          ? setState(() => _active = collection)
          : onSelected(),
    ),
  );
}
