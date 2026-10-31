import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/enum/enum.dart';

/// K4 — navigation architecture invariants.
///
/// `AURORA_UI_AUDIT_PHASE0.md` §12 lists K4 as **protected, must-not-regress**
/// work: "Navigation 单例 + 8 主项 + more 分组 + TV 焦点遍历". §10.9-4 adds the
/// operative wording — **不改导航信息架构** — i.e. Phase 02 may restyle the
/// navigation but must not change how many destinations exist, what they are,
/// what order they appear in, or which ones live behind `more`.
///
/// Before this file nothing asserted any of that: `grep "Navigation\." test/`
/// returned zero. A refactor could have dropped a destination or reordered the
/// rail and every test would still have passed.
///
/// These are **information-architecture** assertions only. They say nothing
/// about how the bar or rail is drawn.
void main() {
  /// The order users actually see, top-to-bottom / left-to-right.
  const expectedOrder = <PageLabel>[
    PageLabel.dashboard,
    PageLabel.proxies,
    PageLabel.profiles,
    PageLabel.connections,
    PageLabel.resources,
    PageLabel.script,
    PageLabel.logs,
    PageLabel.tools,
  ];

  group('K4 — eight destinations in a fixed order', () {
    test('exactly eight destinations are returned', () {
      final items = navigation.getItems();
      expect(items.length, 8);
    });

    test('labels match the documented order', () {
      final labels = navigation.getItems().map((e) => e.label).toList();
      expect(labels, expectedOrder);
    });

    test('adding hasProxies does not change the destination set', () {
      // `hasProxies` only decides whether the proxies entry is *available* in
      // each mode; it must never add or remove a destination from the list.
      final without = navigation.getItems().map((e) => e.label).toList();
      final withProxies = navigation
          .getItems(hasProxies: true)
          .map((e) => e.label)
          .toList();
      expect(withProxies, without);
    });

    test('openLogs does not change the destination set either', () {
      final labels = navigation
          .getItems(openLogs: true)
          .map((e) => e.label)
          .toList();
      expect(labels, expectedOrder);
    });
  });

  group('K4 — the `more` grouping', () {
    /// Destinations that sit behind the overflow entry.
    const moreLabels = <PageLabel>{
      PageLabel.connections,
      PageLabel.resources,
      PageLabel.script,
      PageLabel.logs,
    };

    test('exactly four destinations carry the more mode', () {
      final more = navigation
          .getItems()
          .where((e) => e.modes.contains(NavigationItemMode.more))
          .map((e) => e.label)
          .toSet();
      expect(more, moreLabels);
    });

    test('resources and script are overflow-only', () {
      // Measured on the real implementation: these two carry `more` and nothing
      // else, so they never appear in the desktop rail or the mobile bar —
      // they are reachable only through the overflow entry. Pinning it stops a
      // future "tidy-up" from silently promoting them into the rail.
      for (final label in [PageLabel.resources, PageLabel.script]) {
        final item = navigation.getItems().firstWhere((e) => e.label == label);
        expect(
          item.modes,
          [NavigationItemMode.more],
          reason: '$label is overflow-only',
        );
      }
    });

    test('the two navigable-everywhere overflow entries stay on desktop', () {
      // connections and logs sit in `more` *and* in the desktop rail.
      for (final label in [PageLabel.connections, PageLabel.logs]) {
        final item = navigation.getItems().firstWhere((e) => e.label == label);
        expect(
          item.modes.contains(NavigationItemMode.desktop),
          isTrue,
          reason: '$label must also be a desktop rail destination',
        );
        expect(item.modes.contains(NavigationItemMode.more), isTrue);
      }
    });

    test('the primary destinations are not hidden behind more', () {
      for (final label in [
        PageLabel.dashboard,
        PageLabel.profiles,
        PageLabel.tools,
      ]) {
        final item = navigation.getItems().firstWhere((e) => e.label == label);
        expect(
          item.modes.contains(NavigationItemMode.more),
          isFalse,
          reason: '$label is a primary destination',
        );
      }
    });
  });

  group('K4 — singleton identity', () {
    test('Navigation() always returns the same instance', () {
      // The singleton is part of the protected architecture: pages rely on one
      // shared list, so a second instance would fork the IA.
      expect(identical(Navigation(), Navigation()), isTrue);
      expect(identical(Navigation(), navigation), isTrue);
    });
  });

  group('K4 — every destination builds a page', () {
    test('no destination has a null builder', () {
      for (final item in navigation.getItems()) {
        expect(item.builder, isNotNull, reason: '${item.label} has no builder');
      }
    });
  });
}
