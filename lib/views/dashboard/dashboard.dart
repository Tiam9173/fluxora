import 'dart:async';
import 'dart:math';

import 'package:fluxora/state.dart';

import 'package:defer_pointer/defer_pointer.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final customDashboardTitleProvider =
    StateNotifierProvider<CustomDashboardTitleNotifier, String?>((ref) {
      return CustomDashboardTitleNotifier();
    });

/// Colour of the customised home title. `null` means "follow the theme", which
/// is also what the reset option stores — a colour chosen once should not
/// outlive the title it was chosen for.
final customDashboardTitleColorProvider =
    StateNotifierProvider<CustomDashboardTitleColorNotifier, int?>((ref) {
      return CustomDashboardTitleColorNotifier();
    });

const customDashboardTitleColorKey = 'custom_dashboard_title_color';

class CustomDashboardTitleColorNotifier extends StateNotifier<int?> {
  CustomDashboardTitleColorNotifier() : super(null) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    state = prefs?.getInt(customDashboardTitleColorKey);
  }

  Future<void> updateColor(int? color) async {
    state = color;
    final prefs = await preferences.sharedPreferencesCompleter.future;
    if (color == null) {
      prefs?.remove(customDashboardTitleColorKey);
    } else {
      prefs?.setInt(customDashboardTitleColorKey, color);
    }
  }
}

class CustomDashboardTitleNotifier extends StateNotifier<String?> {
  CustomDashboardTitleNotifier() : super(null) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await preferences.sharedPreferencesCompleter.future;
    state = prefs?.getString(customDashboardTitleKey);
  }

  Future<void> updateTitle(String? title) async {
    state = title;
    final prefs = await preferences.sharedPreferencesCompleter.future;
    if (title == null) {
      prefs?.remove(customDashboardTitleKey);
    } else {
      prefs?.setString(customDashboardTitleKey, title);
    }
  }
}

typedef _IsEditWidgetBuilder = Widget Function(bool isEdit);

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  final key = GlobalKey<SuperGridState>();
  final GlobalKey<_DashboardStartSwitchState> _startSwitchKey = GlobalKey();
  final _isEditNotifier = ValueNotifier<bool>(false);
  final _addedWidgetsNotifier = ValueNotifier<List<GridItem>>([]);

  @override
  void initState() {
    super.initState();
    if (globalState.isAndroidTV) {
      globalState.focusDashboardStartSwitch = _requestStartSwitchFocus;
    }
  }

  void _requestStartSwitchFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSwitchKey.currentState?.requestFocus();
    });
  }

  @override
  void dispose() {
    if (globalState.focusDashboardStartSwitch == _requestStartSwitchFocus) {
      globalState.focusDashboardStartSwitch = null;
    }
    _isEditNotifier.dispose();
    _addedWidgetsNotifier.dispose();
    super.dispose();
  }

  Widget _buildIsEdit(_IsEditWidgetBuilder builder) {
    return ValueListenableBuilder(
      valueListenable: _isEditNotifier,
      builder: (_, isEdit, _) {
        return builder(isEdit);
      },
    );
  }

  List<Widget> _buildActions() {
    final showStartSwitch = ref.watch(
      appSettingProvider.select((state) => state.showStartSwitch),
    );
    return [
      _buildIsEdit((isEdit) {
        return isEdit
            ? ValueListenableBuilder(
                valueListenable: _addedWidgetsNotifier,
                builder: (_, addedChildren, child) {
                  if (addedChildren.isEmpty) {
                    return Container();
                  }
                  return child!;
                },
                child: IconButton(
                  onPressed: () {
                    _showAddWidgetsModal();
                  },
                  icon: Icon(Icons.add_circle),
                ),
              )
            : SizedBox();
      }),
      Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _handleUpdateIsEdit,
          onLongPress: () {
            if (!_isEditNotifier.value) {
              _showEditTitleDialog();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: _buildIsEdit((isEdit) {
              return isEdit ? const Icon(Icons.save) : const Icon(Icons.edit);
            }),
          ),
        ),
      ),
      if (showStartSwitch)
        _DashboardStartSwitch(key: _startSwitchKey),
    ];
  }

  void _showAddWidgetsModal() {
    showSheet(
      builder: (_, type) {
        return ValueListenableBuilder(
          valueListenable: _addedWidgetsNotifier,
          builder: (_, value, _) {
            return AdaptiveSheetScaffold(
              type: type,
              body: _AddDashboardWidgetModal(
                items: value,
                onAdd: (gridItem) {
                  key.currentState?.handleAdd(gridItem);
                },
              ),
              title: appLocalizations.add,
            );
          },
        );
      },
      context: context,
    );
  }

  /// The app-bar title, tappable to edit. Rendered through [EmojiText] so a
  /// custom title keeps the same typography (and emoji support) as the default.
  Widget _buildCustomTitle(BuildContext context) {
    final title =
        ref.watch(customDashboardTitleProvider) ?? appLocalizations.dashboard;
    final colorValue = ref.watch(customDashboardTitleColorProvider);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showEditTitleDialog,
      child: EmojiText(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: colorValue == null
            ? null
            : TextStyle(color: Color(colorValue)),
      ),
    );
  }

  void _showEditTitleDialog() async {
    final currentTitle = ref.read(customDashboardTitleProvider) ?? '';
    final currentColor = ref.read(customDashboardTitleColorProvider);
    final result = await globalState.showCommonDialog<_DashboardTitleResult>(
      child: _DashboardTitleDialog(
        initialValue: currentTitle,
        initialColor: currentColor,
      ),
    );
    if (result == null) return;
    ref
        .read(customDashboardTitleProvider.notifier)
        .updateTitle(result.title.isEmpty ? null : result.title);
    // A title reset also resets the colour: keeping a colour with no title
    // would silently repaint the default "首页" label later.
    await ref
        .read(customDashboardTitleColorProvider.notifier)
        .updateColor(result.title.isEmpty ? null : result.color);
  }

  void _handleUpdateIsEdit() {
    if (_isEditNotifier.value == true) {
      _handleSave();
    }
    _isEditNotifier.value = !_isEditNotifier.value;
  }

  void _handleSave() {
    final children = key.currentState?.children;
    if (children == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dashboardWidgets = children
          .map((item) => DashboardWidget.getDashboardWidget(item))
          .toList();
      ref
          .read(appSettingProvider.notifier)
          .updateState(
            (state) => system.isAndroid
                ? state.copyWith(
                    mobileDashboardWidgets: dashboardWidgets,
                    dashboardWidgets: dashboardWidgets,
                  )
                : state.copyWith(
                    desktopDashboardWidgets: dashboardWidgets,
                    dashboardWidgets: dashboardWidgets,
                  ),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardStateProvider);
    final columns = max(4 * ((dashboardState.viewWidth / 320).ceil()), 8);
    final spacing = 16.ap;
    final isMobileView = ref.watch(isMobileViewProvider);
    final children = [
      ...dashboardState.dashboardWidgets
          .where(
            (item) => item.platforms.contains(SupportPlatform.currentPlatform),
          )
          .map((item) => item.widget),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addedWidgetsNotifier.value = DashboardWidget.values
          .where(
            (item) =>
                !children.contains(item.widget) &&
                item.platforms.contains(SupportPlatform.currentPlatform),
          )
          .map((item) => item.widget)
          .toList();
    });
    return CommonScaffold(
      // The title is the edit entry point: tapping it opens the text + colour
      // editor, so customising does not require entering dashboard edit mode.
      titleWidget: _buildCustomTitle(context),
      actions: _buildActions(),
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16).copyWith(
            bottom:
                16 +
                (isMobileView ? getFloatingBottomBarReserveHeight(context) : 0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildIsEdit((isEdit) {
                if (isEdit) {
                  return SystemBackBlock(
                    child: CommonPopScope(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SuperGrid(
                            key: key,
                            crossAxisCount: columns,
                            crossAxisSpacing: spacing,
                            mainAxisSpacing: spacing,
                            children: [
                              ...dashboardState.dashboardWidgets
                                  .where(
                                    (item) => item.platforms.contains(
                                      SupportPlatform.currentPlatform,
                                    ),
                                  )
                                  .map((item) => item.widget),
                            ],
                            onUpdate: () {
                              _handleSave();
                            },
                          ),
                        ],
                      ),
                      onPop: () {
                        _handleUpdateIsEdit();
                        return false;
                      },
                    ),
                  );
                } else {
                  return Grid(
                    crossAxisCount: columns,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    children: [...children],
                  );
                }
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddDashboardWidgetModal extends StatelessWidget {
  final List<GridItem> items;
  final Function(GridItem item) onAdd;

  const _AddDashboardWidgetModal({required this.items, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return DeferredPointerHandler(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Grid(
          crossAxisCount: 8,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: items
              .map(
                (item) => item.wrap(
                  builder: (child) {
                    return _AddedContainer(
                      onAdd: () {
                        onAdd(item);
                      },
                      child: child,
                    );
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _AddedContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback onAdd;

  const _AddedContainer({required this.child, required this.onAdd});

  @override
  State<_AddedContainer> createState() => _AddedContainerState();
}

class _AddedContainerState extends State<_AddedContainer> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(_AddedContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {}
  }

  Future<void> _handleAdd() async {
    widget.onAdd();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ActivateBox(child: widget.child),
        Positioned(
          top: -8,
          right: -8,
          child: DeferPointer(
            child: SizedBox(
              width: 24,
              height: 24,
              child: IconButton.filled(
                iconSize: 20,
                padding: EdgeInsets.all(2),
                onPressed: _handleAdd,
                icon: Icon(Icons.add),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardTitleResult {
  final String title;
  final int? color;

  const _DashboardTitleResult({required this.title, this.color});
}

class _DashboardTitleDialog extends StatefulWidget {
  final String initialValue;
  final int? initialColor;

  const _DashboardTitleDialog({
    required this.initialValue,
    this.initialColor,
  });

  @override
  State<_DashboardTitleDialog> createState() => _DashboardTitleDialogState();
}

class _DashboardTitleDialogState extends State<_DashboardTitleDialog> {
  /// Palette for the title. The first swatch is "follow the theme" (null),
  /// which is why the list is `int?` rather than a list of colours.
  static const List<int?> _palette = [
    null,
    0xFF29D6C7,
    0xFF4C8DFF,
    0xFF7C75FF,
    0xFFFF6B9D,
    0xFFFFB020,
    0xFFFF5252,
    0xFF4CAF50,
  ];

  late final TextEditingController _controller;
  late int? _color;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _color = widget.initialColor;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate(String value) {
    int len = 0;
    for (int i = 0; i < value.length; i++) {
      len += value.codeUnitAt(i) > 127 ? 2 : 1;
    }
    setState(() {
      if (len > 20) {
        _errorText = appLocalizations.titleTooLong;
      } else {
        _errorText = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CommonDialog(
      title: appLocalizations.customDashboardTitle,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(appLocalizations.cancel),
        ),
        TextButton(
          onPressed: _errorText == null
              ? () {
                  Navigator.of(context).pop(
                    _DashboardTitleResult(
                      title: _controller.text,
                      color: _color,
                    ),
                  );
                }
              : null,
          child: Text(appLocalizations.confirm),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Have fun with Fluxora',
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
              onChanged: _validate,
            ),
            const SizedBox(height: 14),
            Text(
              appLocalizations.titleColor,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final swatch in _palette)
                  _buildSwatch(context, swatch),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwatch(BuildContext context, int? value) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = value == _color;
    final fill = value == null ? colorScheme.surfaceContainerHighest : Color(value);
    return InkWell(
      onTap: () => setState(() => _color = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: value == null
            ? Icon(
                Icons.palette_outlined,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              )
            : (isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null),
      ),
    );
  }
}

class _DashboardStartSwitch extends ConsumerStatefulWidget {
  const _DashboardStartSwitch({super.key});

  @override
  ConsumerState<_DashboardStartSwitch> createState() =>
      _DashboardStartSwitchState();
}

class _DashboardStartSwitchState extends ConsumerState<_DashboardStartSwitch> {
  bool _isDisabled = false;
  bool? _optimisticStart;
  FocusNode? _focusNode;

  @override
  void initState() {
    super.initState();
    if (globalState.isAndroidTV) {
      _focusNode = FocusNode()..addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _focusNode?.removeListener(_onFocusChange);
    _focusNode?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    globalState.isDashboardStartSwitchFocused =
        _focusNode?.hasFocus ?? false;
  }

  void requestFocus() {
    _focusNode?.requestFocus();
  }

  void _handleStart() async {
    if (_isDisabled) return;
    final isStart = ref.read(runTimeProvider) != null;
    final newState = !isStart;
    setState(() {
      _isDisabled = true;
      _optimisticStart = newState;
    });

    try {
      await globalState.appController.updateStatus(newState);
    } catch (e) {
      commonPrint.log('updateStatus failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDisabled = false;
          _optimisticStart = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(startButtonSelectorStateProvider);
    final isRestarting = ref.watch(isRestartingCoreProvider);
    final isSmartStopped = ref.watch(isSmartStoppedProvider);
    final runTime = ref.watch(runTimeProvider);
    final isStart = runTime != null;
    final displayStart = isSmartStopped ? false : (_optimisticStart ?? isStart);

    final canPress =
        state.isInit && state.hasProfile && !_isDisabled && !isRestarting && !isSmartStopped;

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Switch(
        focusNode: _focusNode,
        value: displayStart,
        onChanged: canPress ? (_) => _handleStart() : null,
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected) &&
              !states.contains(WidgetState.disabled)) {
            return theme.colorScheme.primary;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected) &&
              !states.contains(WidgetState.disabled)) {
            return theme.colorScheme.primary.withValues(alpha: 0.2);
          }
          return null;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected) &&
              !states.contains(WidgetState.disabled)) {
            return Colors.transparent;
          }
          return null;
        }),
      ),
    );
  }
}
