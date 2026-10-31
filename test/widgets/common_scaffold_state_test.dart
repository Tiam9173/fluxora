import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import '../support/recording_app_controller.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/widgets.dart';

/// K5 — `CommonScaffold` search / edit state machine invariants.
///
/// `AURORA_UI_AUDIT_PHASE0.md` §12 lists K5 as protected, must-not-regress work:
/// "CommonScaffold 搜索/编辑态状态机（F1 已修后的现状）". Phase 02 may restyle the
/// bar but must not change what the user observes when entering, clearing or
/// leaving search, or when a selection turns the bar into edit mode.
///
/// Nothing covered this before: `grep CommonScaffold test/` matched one file,
/// and that match was incidental. The three modes are distinguished by two
/// private getters (`_isSearch` = `query != null`, `_isEdit` = `editCount > 0`),
/// so these tests assert the **rendered** difference rather than reaching into
/// state.
///
/// The controller is a [RecordingAppController]: search / edit mode mounts
/// `SystemBackBlock`, which calls `globalState.appController` from a post-frame
/// callback in `dispose`. Binding the real controller to a test-scoped
/// `WidgetRef` makes that callback trip riverpod's "ref after unmount" guard —
/// an artifact of the harness, not of the widget (production binds the
/// controller to the root `Application` state, see `pop_scope_test.dart`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Rebound per test — see the comment in `setUp`.
  var controllerBound = false;

  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  setUp(() {
    // Each test needs its own binding: the controller captures the `ref` of the
    // Consumer that created it, and that ref dies with the test's tree. Reusing
    // a controller across tests trips riverpod's "ref after unmount" assertion
    // inside `SystemBackBlock.dispose`.
    controllerBound = false;
    globalState.appState = AppState(
      viewSize: const Size(400, 800),
      brightness: Brightness.dark,
      requests: FixedList(10),
      version: 1,
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
  });

  Widget seedGlobals(Widget child) {
    return Builder(
      builder: (ctx) {
        globalState.theme = CommonTheme.of(ctx, 1.0);
        globalState.measure = Measure.of(ctx, 1.0);
        return child;
      },
    );
  }

  Future<void> pumpScaffold(
    WidgetTester tester, {
    AppBarSearchState? searchState,
    AppBarEditState? editState,
  }) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        // `CommonScaffold` reads `loadingProvider` / `isMobileViewProvider` for
        // the loading strip, and entering search mode mounts `SystemBackBlock`,
        // whose initState / dispose read `globalState.appController`.
        // Production binds the controller in `application.dart`; bind it once
        // per test here — same pattern as `tools_empty_search_state_test.dart`.
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (ctx, ref, _) {
                if (!controllerBound) {
                  controllerBound = true;
                  globalState.appController = RecordingAppController(ctx, ref);
                }
                return seedGlobals(
                  CommonScaffold(
                    title: 'page-title',
                    body: const SizedBox.expand(),
                    searchState: searchState,
                    editState: editState,
                  ),
                );
              },
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump();
    // No teardown pump here on purpose. Search / edit mode mounts
    // `SystemBackBlock`, whose `dispose` schedules a post-frame callback that
    // reads `backBlockProvider` through the controller's captured ref. Not
    // pumping after the test ends leaves that callback unrun — which is how the
    // existing `tools_empty_search_state_test.dart` harness stays green — and
    // the next test rebinds a live controller, so a late callback is harmless.
  }

  group('K5 — normal mode', () {
    testWidgets('with no states the plain title is shown', (tester) async {
      await pumpScaffold(tester);

      expect(find.text('page-title'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('a searchState with a null query is not search mode', (
      tester,
    ) async {
      // `query == null` means "search is available but idle" — the bar must
      // still look like the normal bar.
      await pumpScaffold(
        tester,
        searchState: AppBarSearchState(onSearch: (_) {}),
      );

      expect(find.text('page-title'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('an editState with a zero count is not edit mode', (
      tester,
    ) async {
      await pumpScaffold(
        tester,
        editState: AppBarEditState(editCount: 0, onExit: () {}),
      );

      expect(find.text('page-title'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });
  });

  group('K5 — search mode', () {
    testWidgets('a non-null query swaps the title for a search field', (
      tester,
    ) async {
      await pumpScaffold(
        tester,
        searchState: AppBarSearchState(onSearch: (_) {}, query: 'abc'),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('page-title'), findsNothing);
    });

    testWidgets('search mode shows a back affordance', (tester) async {
      await pumpScaffold(
        tester,
        searchState: AppBarSearchState(onSearch: (_) {}, query: 'abc'),
      );

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('typing forwards every keystroke to onSearch', (tester) async {
      final seen = <String>[];
      await pumpScaffold(
        tester,
        searchState: AppBarSearchState(onSearch: seen.add, query: 'a'),
      );

      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump();

      expect(seen, contains('ab'));
    });
  });

  group('K5 — edit mode', () {
    testWidgets('a positive edit count replaces the title with the count', (
      tester,
    ) async {
      await pumpScaffold(
        tester,
        editState: AppBarEditState(editCount: 3, onExit: () {}),
      );

      expect(find.text('page-title'), findsNothing);
      expect(find.text(appLocalizations.selectedCountTitle('3')), findsOneWidget);
    });

    testWidgets('edit mode leading is a cancel action, not back', (
      tester,
    ) async {
      await pumpScaffold(
        tester,
        editState: AppBarEditState(editCount: 1, onExit: () {}),
      );

      expect(find.byIcon(Icons.close), findsWidgets);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('tapping cancel calls onExit exactly once', (tester) async {
      var exits = 0;
      await pumpScaffold(
        tester,
        editState: AppBarEditState(editCount: 2, onExit: () => exits++),
      );

      // The leading button is the first `close` icon in the bar.
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();

      expect(exits, 1);
    });
  });

  group('K5 — edit wins over search', () {
    testWidgets('when both are active the leading stays the cancel action', (
      tester,
    ) async {
      // `_buildLeading` checks `_isEdit` first, so a selection that turns the
      // bar into edit mode must not be replaced by the search back arrow.
      await pumpScaffold(
        tester,
        searchState: AppBarSearchState(onSearch: (_) {}, query: 'abc'),
        editState: AppBarEditState(editCount: 1, onExit: () {}),
      );

      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byIcon(Icons.close), findsWidgets);
    });
  });

  // ── K5 — the actions-area clear button ────────────────────────────────────
  //
  // In search mode the bar carries **two** close-ish affordances:
  //   · leading  → `Icons.arrow_back`, tooltip `back`,   runs `_handleExitSearching`
  //   · actions  → `Icons.close`,      tooltip `clear`,  runs `_handleClear`
  // They do different things, so these tests address them by tooltip rather than
  // by icon (`find.byIcon(Icons.close).first` would hit whichever comes first in
  // paint order and silently test the wrong button).
  //
  // `_handleClear` has two branches:
  //   text non-empty → clear the field, stay in search
  //   text empty     → unfocus and drop `query`, leaving search
  //
  // Note: `CommonScaffold` does **not** seed `_textController` from
  // `searchState.query` — it only writes the controller out through `onChanged`.
  // So a caller that opens search with a pre-filled query sees an empty field,
  // and the first clear press exits. That is existing behaviour, pinned below
  // rather than "fixed", because K5 forbids changing the state machine.

  group('K5 — search clear', () {
    testWidgets('clearing a non-empty field empties it and stays in search', (
      tester,
    ) async {
      final seen = <String>[];
      await pumpScaffold(
        tester,
        searchState: AppBarSearchState(onSearch: seen.add, query: 'a'),
      );

      // Typing is what puts text into `_textController` (see the note above).
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump();
      seen.clear();

      await tester.tap(find.byTooltip(appLocalizations.clear));
      await tester.pump();

      expect(
        find.byType(TextField),
        findsOneWidget,
        reason: 'a clear press with text must not leave search mode',
      );
      expect(find.text('page-title'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty,
      );
      expect(
        seen,
        contains(''),
        reason: 'clearing must tell the caller the query is now empty',
      );
    });

    testWidgets('a second clear press on an empty field exits search', (
      tester,
    ) async {
      await pumpScaffold(
        tester,
        searchState: AppBarSearchState(onSearch: (_) {}, query: 'a'),
      );

      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump();

      // First press: clears the text, still searching.
      await tester.tap(find.byTooltip(appLocalizations.clear));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);

      // Second press: nothing left to clear, so the bar leaves search.
      await tester.tap(find.byTooltip(appLocalizations.clear));
      await tester.pump();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('page-title'), findsOneWidget);
    });

    testWidgets('the leading back affordance exits regardless of text', (
      tester,
    ) async {
      // `_handleExitSearching` clears the input *and* drops the query, so the
      // back arrow must always leave search — it is not a clear button.
      await pumpScaffold(
        tester,
        searchState: AppBarSearchState(onSearch: (_) {}, query: 'a'),
      );

      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump();

      await tester.tap(find.byTooltip(appLocalizations.back));
      await tester.pump();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('page-title'), findsOneWidget);
    });

    testWidgets('clear does not appear when the bar is not searching', (
      tester,
    ) async {
      // The actions area only offers `clear` while searching; otherwise it
      // offers `search`. Mixing them up would leave a dead button in the bar.
      await pumpScaffold(tester);

      expect(find.byTooltip(appLocalizations.clear), findsNothing);
    });
  });
}
