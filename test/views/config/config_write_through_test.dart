import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/state.dart';

/// The settings sub-pages do not keep a local copy of what the user picked —
/// they write straight into `patchClashConfigProvider` and read it back. That
/// makes the provider the single source of truth, but it also means the whole
/// "did my change stick" question is really two questions:
///
/// 1. does `updateState` reach `globalState.config` (the object that gets
///    serialised), and
/// 2. does that change reach disk.
///
/// (1) is testable without any platform service and is covered here. (2) is
/// traced in the report — it runs through `configStateProvider` →
/// `app_manager`'s listener → `savePreferencesDebounce()` →
/// `preferences.saveConfig()`, i.e. a debounced `shared_preferences.setString`.
void main() {
  late Config previous;

  setUp(() {
    previous = globalState.config;
    globalState.config = Config(themeProps: defaultThemeProps);
  });

  tearDown(() => globalState.config = previous);

  /// A container with the provider kept alive, mirroring the app (where
  /// `configStateProvider` watches it). The write-through does not actually
  /// depend on that listener — see the last test — but keeping one here means
  /// the tests exercise the same shape the settings pages run under.
  ProviderContainer containerWithListener() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(patchClashConfigProvider, (_, _) {});
    addTearDown(sub.close);
    return container;
  }

  group('settings write-through', () {
    test('the initial value comes from globalState.config', () {
      globalState.config = Config(themeProps: defaultThemeProps).copyWith(
        patchClashConfig: const ClashConfig().copyWith(keepAliveInterval: 17),
      );

      final container = containerWithListener();
      expect(
        container.read(patchClashConfigProvider).keepAliveInterval,
        17,
        reason: 'the row must show what is actually stored, not a default',
      );
    });

    test('updateState reaches the object that gets serialised', () {
      final container = containerWithListener();

      container
          .read(patchClashConfigProvider.notifier)
          .updateState((s) => s.copyWith(keepAliveInterval: 30));

      expect(
        container.read(patchClashConfigProvider).keepAliveInterval,
        30,
        reason: 'the provider reflects the new value',
      );
      expect(
        globalState.config.patchClashConfig.keepAliveInterval,
        30,
        reason:
            '`preferences.saveConfig(globalState.config)` is what reaches disk, '
            'so the change has to land there — not only in the provider',
      );
    });

    test('a null builder leaves the value untouched', () {
      // `updateState` accepts a nullable result so a failing validation can
      // decline the update; that must not wipe the setting.
      final container = containerWithListener();
      container
          .read(patchClashConfigProvider.notifier)
          .updateState((s) => s.copyWith(keepAliveInterval: 42));

      container.read(patchClashConfigProvider.notifier).updateState((_) => null);

      expect(container.read(patchClashConfigProvider).keepAliveInterval, 42);
      expect(globalState.config.patchClashConfig.keepAliveInterval, 42);
    });

    test('sibling settings in the same object are preserved', () {
      final container = containerWithListener();
      final notifier = container.read(patchClashConfigProvider.notifier);
      notifier.updateState((s) => s.copyWith(keepAliveInterval: 30));
      notifier.updateState((s) => s.copyWith(unifiedDelay: true));

      final stored = globalState.config.patchClashConfig;
      expect(stored.keepAliveInterval, 30);
      expect(stored.unifiedDelay, isTrue);
    });

    test('the write-through does not depend on anything listening', () {
      // `onUpdate` runs from `updateShouldNotify`, which Riverpod evaluates to
      // decide whether to notify — not only when a listener exists. Measured
      // here: a container that merely reads the provider still reaches
      // `globalState.config`. That is what makes the eventual
      // `savePreferences()` write fresh data even if the settings page was
      // already gone by the time it ran.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(patchClashConfigProvider.notifier)
          .updateState((s) => s.copyWith(keepAliveInterval: 99));

      expect(
        globalState.config.patchClashConfig.keepAliveInterval,
        99,
        reason: 'no listener, still written through',
      );
    });
  });
}
