import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef OnSelected = void Function(int index);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Map<int, FocusNode> _navFocusNodes = {};
  int _currentNavIndex = 0;

  /// Height of the floating bottom dock, measured after layout.
  ///
  /// On mobile the dock is painted **over** the page (`Stack` + `Positioned`),
  /// so the page loses the bottom slice of its viewport. Nothing reserved that
  /// space before: `generateListView` only pads by `24 + padding.bottom`, where
  /// `padding.bottom` is the *system* inset — so on a 390×844 phone the last
  /// row of a list sat at y 782–802 while the dock covered y 762–844, leaving
  /// the final row invisible and untappable.
  ///
  /// Measured rather than hardcoded because the dock's height follows the text
  /// scale (it contains a label under every icon).
  final GlobalKey _dockKey = GlobalKey();
  double _dockHeight = 0;

  /// Schedules a post-frame measurement of the dock.
  ///
  /// Safe to call from `build`: the callback only calls `setState` when the
  /// height actually changed, so the measure → rebuild → measure loop settles
  /// after one extra frame.
  void _scheduleDockMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _dockKey.currentContext?.findRenderObject() as RenderBox?;
      final height = box?.size.height ?? 0;
      if (height <= 0 || (height - _dockHeight).abs() < 0.5) return;
      setState(() => _dockHeight = height);
    });
  }

  FocusNode _getNavFocusNode(int index) {
    return _navFocusNodes.putIfAbsent(index, () => FocusNode());
  }

  void _requestNavFocus(int index) {
    if (!globalState.isAndroidTV) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _getNavFocusNode(index).requestFocus();
      }
    });
  }

  bool get isNavFocused => _navFocusNodes.values.any((node) => node.hasFocus);

  void focusNav() {
    if (!globalState.isAndroidTV || !mounted) return;
    _getNavFocusNode(_currentNavIndex).requestFocus();
  }

  @override
  void initState() {
    super.initState();
    if (globalState.isAndroidTV) {
      _requestNavFocus(0);
    }
  }

  @override
  void dispose() {
    for (final node in _navFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HomeBackScope(
      onTvBack: () {
        final currentPage = globalState.appState.pageLabel;
        final isNav = isNavFocused;

        if (isNav) {
          if (currentPage == PageLabel.dashboard) {
            return false;
          }
          globalState.appController.toPage(PageLabel.dashboard);
          return true;
        }

        focusNav();
        return true;
      },
      child: Material(
        color: context.colorScheme.surface,
        child: Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(navigationStateProvider);
            final isMobile = state.viewMode == ViewMode.mobile;
            final navigationItems = state.navigationItems;
            final currentIndex = state.currentIndex;
            final bottomNavigationBar = globalState.isAndroidTV
                ? _buildTVBottomNavBar(
                    context,
                    navigationItems: navigationItems,
                    currentIndex: currentIndex,
                  )
                : AuroraBottomNavBar(
                    navigationItems: navigationItems,
                    selectedIndex: currentIndex,
                    onTabChange: (index) {
                      globalState.appController.toPage(
                        navigationItems[index].label,
                      );
                    },
                  );
            if (isMobile) {
              // Tell the page how much of its bottom the floating dock covers.
              //
              // Pages that already honour `MediaQuery.padding.bottom` — every
              // list built by `generateListView` does — then reserve the right
              // amount instead of scrolling their last row underneath the dock.
              //
              // The injection has to happen *inside* `removePadding`: that
              // widget rebuilds its data from the outer context, so wrapping it
              // from the outside would be discarded.
              //
              // `max` rather than a sum: the dock's own `SafeArea` already
              // includes the system inset, so adding it again would over-reserve
              // by the gesture-bar height on phones.
              _scheduleDockMeasure();
              final pageContent = MediaQuery.removePadding(
                removeTop: false,
                removeBottom: false,
                removeLeft: true,
                removeRight: true,
                context: context,
                child: Builder(
                  builder: (pageCtx) {
                    final mq = MediaQuery.of(pageCtx);
                    // Always wrap — never conditionally.
                    //
                    // The measure lands in a post-frame callback, so the first
                    // frame runs with `_dockHeight == 0` and the second with the
                    // real height. A conditional wrapper changes the widget type
                    // in that slot (`Consumer` → `MediaQuery`), which makes
                    // Flutter **remount the whole page subtree**: measured on a
                    // 400×800 mobile shell, the page's `initState` ran twice and
                    // `dispose` once, i.e. every cold start re-ran the page's
                    // real side effects (dashboard cards hit
                    // `SystemProxyReadbackService` and
                    // `ClashHandlerInterface.getMemory`). Keeping the shape
                    // stable costs one inherited widget and removes the remount.
                    final bottom = _dockHeight > mq.padding.bottom
                        ? _dockHeight
                        : mq.padding.bottom;
                    final page = MediaQuery(
                      data: mq.copyWith(
                        padding: mq.padding.copyWith(bottom: bottom),
                      ),
                      child: child!,
                    );
                    // Publish the height itself as well. Pages that add their
                    // own bottom padding through
                    // `getFloatingBottomBarReserveHeight` must not read it back
                    // out of `MediaQuery.padding` — they would count it twice.
                    return FloatingDockMetrics(
                      height: _dockHeight,
                      child: page,
                    );
                  },
                ),
              );
              final navBar = MediaQuery.removePadding(
                removeTop: true,
                removeBottom: false,
                removeLeft: true,
                removeRight: true,
                context: context,
                child: bottomNavigationBar,
              );
              return Stack(
                children: [
                  Positioned.fill(child: pageContent),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: KeyedSubtree(key: _dockKey, child: navBar),
                  ),
                ],
              );
            }
            return child!;
          },
          child: Consumer(
            builder: (_, ref, _) {
              final navigationItems = ref
                  .watch(currentNavigationItemsStateProvider)
                  .value;
              final isMobile = ref.watch(isMobileViewProvider);
              return _HomePageView(
                navigationItems: navigationItems,
                pageBuilder: (_, index) {
                  final navigationItem = navigationItems[index];
                  final navigationView = navigationItem.builder(context);
                  return KeepScope(
                    key: ValueKey(navigationItem.label),
                    keep: isMobile || navigationItem.keep,
                    child: isMobile
                        ? navigationView
                        : Navigator(
                            pages: [MaterialPage(child: navigationView)],
                            onDidRemovePage: (_) {},
                          ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTVBottomNavBar(
    BuildContext context, {
    required List<NavigationItem> navigationItems,
    required int currentIndex,
  }) {
    if (_currentNavIndex != currentIndex) {
      _currentNavIndex = currentIndex;
      _requestNavFocus(currentIndex);
    }

    // The visual layer lives in `AuroraTvNavBar` so it can be tested without
    // `isAndroidTV` (unreachable on a desktop test host). Everything that makes
    // the bar *behave* — the per-index focus nodes, the focus request that
    // follows the current page, and the `toPage` mapping — stays here.
    return AuroraTvNavBar(
      destinations: navigationItems
          .map(
            (e) => AuroraRailDestination(
              icon: e.icon,
              label: e.label.localizedName,
            ),
          )
          .toList(),
      selectedIndex: currentIndex,
      focusNodes: [
        for (var i = 0; i < navigationItems.length; i++) _getNavFocusNode(i),
      ],
      onSelect: (index) {
        globalState.appController.toPage(navigationItems[index].label);
      },
    );
  }
}

class _HomePageView extends ConsumerStatefulWidget {
  final IndexedWidgetBuilder pageBuilder;
  final List<NavigationItem> navigationItems;

  const _HomePageView({
    required this.pageBuilder,
    required this.navigationItems,
  });

  @override
  ConsumerState createState() => _HomePageViewState();
}

class _HomePageViewState extends ConsumerState<_HomePageView> {
  late PageController _pageController;
  late final ProviderSubscription<PageLabel> _pageLabelSubscription;
  int _currentPageIndex = 0;

  @override
  initState() {
    super.initState();
    _currentPageIndex = _pageIndex < 0 ? 0 : _pageIndex;
    _pageController = PageController(initialPage: _currentPageIndex);
    _pageLabelSubscription = ref.listenManual(currentPageLabelProvider, (
      prev,
      next,
    ) {
      if (prev != next) {
        _toPage(next);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _HomePageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationItems.length != widget.navigationItems.length ||
        oldWidget.navigationItems.asMap().entries.any(
          (entry) =>
              entry.value.label != widget.navigationItems[entry.key].label,
        )) {
      _updatePageController();
    }
  }

  int get _pageIndex {
    return widget.navigationItems.indexWhere(
      (item) => item.label == globalState.appState.pageLabel,
    );
  }

  Future<void> _toPage(
    PageLabel pageLabel, [
    bool ignoreAnimateTo = false,
  ]) async {
    if (!mounted) {
      return;
    }
    final index = widget.navigationItems.indexWhere(
      (item) => item.label == pageLabel,
    );
    if (index == -1) {
      return;
    }

    if (!globalState.isAndroidTV) {
      FocusManager.instance.primaryFocus?.unfocus();
    }

    if (_currentPageIndex == index) return;
    setState(() => _currentPageIndex = index);
    if (!_pageController.hasClients) return;
    final motion = FluxoraMotion.ofContext(context);
    if (ignoreAnimateTo ||
        !ref.read(isMobileViewProvider) ||
        motion.reduceMotion ||
        ((_pageController.page ?? index) - index).abs() > 1.1) {
      _pageController.jumpToPage(index);
    } else {
      await _pageController.animateToPage(
        index,
        duration: motion.base,
        curve: motion.standard,
      );
    }
  }

  void _updatePageController() {
    final pageLabel = ref.read(currentPageLabelProvider);
    _toPage(pageLabel, true);
  }

  @override
  void dispose() {
    _pageLabelSubscription.close();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = ref.watch(isMobileViewProvider);
    return PageView.builder(
      key: const ValueKey('main-page-view'),
      controller: _pageController,
      physics: mobile
          ? const PageScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      onPageChanged: (index) {
        if (_currentPageIndex != index) {
          setState(() => _currentPageIndex = index);
        }
        final page = widget.navigationItems[index].label;
        if (ref.read(currentPageLabelProvider) != page) {
          globalState.appController.toPage(page);
        }
      },
      itemCount: widget.navigationItems.length,
      findChildIndexCallback: (key) {
        final index = widget.navigationItems.indexWhere(
          (item) => ValueKey(item.label) == key,
        );
        return index < 0 ? null : index;
      },
      itemBuilder: (context, index) {
        return TickerMode(
          key: ValueKey(widget.navigationItems[index].label),
          enabled: _currentPageIndex == index,
          child: widget.pageBuilder(context, index),
        );
      },
    );
  }
}

class HomeBackScope extends ConsumerWidget {
  final Widget child;
  final bool Function()? onTvBack;

  const HomeBackScope({super.key, required this.child, this.onTvBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (system.isAndroid) {
      final backBlock = ref.watch(backBlockProvider);
      final currentPage = ref.watch(currentPageLabelProvider);
      final rootPageLabels = ref.watch(
        currentNavigationItemsStateProvider.select(
          (state) => state.value.map((item) => item.label).toSet(),
        ),
      );
      final isCurrentRootPage = rootPageLabels.contains(currentPage);

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop || backBlock) return;
          final navigatorState = globalState.navigatorKey.currentState;
          if (navigatorState?.userGestureInProgress == true) return;

          if (globalState.isAndroidTV) {
            final tvBack = onTvBack;
            if (tvBack != null && tvBack()) return;
          }

          if (!isCurrentRootPage) {
            globalState.appController.toPage(PageLabel.dashboard);
            return;
          }
          if (navigatorState != null && navigatorState.canPop()) {
            navigatorState.pop();
            return;
          }
          await globalState.appController.handleBackOrExit();
        },
        child: child,
      );
    }
    return child;
  }
}
