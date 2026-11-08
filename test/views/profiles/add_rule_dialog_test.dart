import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/providers/providers.dart';
import 'package:fluxora/enum/enum.dart';
import 'package:fluxora/views/profiles/override_profile.dart';

/// Phase 01-D4.2 — regression guards for `AddRuleDialog`.
///
/// Both recent changes to this dialog had **zero** automated coverage:
///   · D1 — the `DropdownMenuTheme` now derives its input decoration from the
///     ambient theme instead of building a bare one;
///   · D3 — the sub-rule `DropdownMenu` gained the `errorText` it was missing,
///     so a failed validation is no longer silent.
///
/// These tests drive the **real production widget** through a real
/// `Navigator.push` and assert on what the dialog actually renders, rather than
/// on a validator's return value in isolation.
///
/// Scope note — what is *not* covered here:
///   · The D1 theme inheritance itself. Production assembles `ThemeData`
///     privately inside `FluxoraApplication`, so a widget test cannot reproduce
///     the exact ambient input theme without duplicating it. Asserting a
///     hand-rolled copy would test the copy, not the app.
///   · The Android TV branch (`globalState.isAndroidTV`), which needs a real
///     Android TV target.
void main() {
  testWidgets(
    'active rule targets track live script groups while the dialog stays open',
    (tester) async {
      final old = globalState.config;
      addTearDown(() => globalState.config = old);
      globalState.config = const Config(
        themeProps: ThemeProps(),
        currentProfileId: 'live-rules',
        profiles: [
          Profile(
            id: 'live-rules',
            label: 'Fixture',
            autoUpdateDuration: Duration(days: 1),
          ),
        ],
      );
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AddRuleDialog(
              profileId: 'live-rules',
              snippet: ClashConfigSnippet(),
            ),
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AddRuleDialog)),
      );
      container.read(groupsProvider.notifier).value = [
        const Group(type: GroupType.Selector, name: 'Script target A'),
      ];
      await tester.pump();
      List<String> targets() => tester
          .widgetList<DropdownMenu<String>>(find.byType(DropdownMenu<String>))
          .expand((menu) => menu.dropdownMenuEntries.map((item) => item.label))
          .toList();
      expect(targets(), contains('Script target A'));
      container.read(groupsProvider.notifier).value = [
        const Group(type: GroupType.Selector, name: 'Script target B'),
      ];
      await tester.pump();
      expect(targets(), contains('Script target B'));
      expect(targets(), isNot(contains('Script target A')));
      container.read(currentProfileIdProvider.notifier).value = null;
      await tester.pump();
      expect(targets(), isNot(contains('Script target B')));
    },
  );
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  setUp(() {
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

  ClashConfigSnippet snippet() => ClashConfigSnippet(
    ruleProvider: const [RuleProvider(name: 'provider-a')],
    subRules: const [SubRule(name: 'sub-a')],
  );

  /// Opens the dialog the way production does — pushed onto a real navigator —
  /// and returns an accessor for the value it pops with.
  ///
  /// `rule:` is the production "edit an existing rule" entry point, so the
  /// action (`SUB-RULE`, `RULE-SET`, …) can be selected without driving the
  /// action picker's nested dialog.
  Future<Rule? Function()> openDialog(
    WidgetTester tester, {
    required Rule rule,
  }) async {
    Rule? popped;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    popped = await Navigator.of(context).push<Rule>(
                      MaterialPageRoute(
                        builder: (_) =>
                            AddRuleDialog(snippet: snippet(), rule: rule),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => popped;
  }

  testWidgets('builds through the production entry point', (tester) async {
    await openDialog(tester, rule: Rule.value('DOMAIN,example.com,DIRECT'));

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(appLocalizations.confirm), findsOneWidget);
  });

  testWidgets('empty sub-rule surfaces the validator message', (tester) async {
    // `SUB-RULE,<content>,<sub-rule>` — the trailing comma leaves the sub-rule
    // empty while the content stays valid, so only that field can fail.
    await openDialog(tester, rule: Rule.value('SUB-RULE,example.com,'));
    final message = appLocalizations.emptyTip(appLocalizations.subRule);

    expect(find.text(message), findsNothing, reason: 'nothing before submit');

    await tester.tap(find.text(appLocalizations.confirm));
    await tester.pumpAndSettle();

    // The D3 fix: the message reaches the screen instead of the confirm button
    // silently doing nothing.
    expect(find.text(message), findsOneWidget);
    // Validation blocked the pop.
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('valid sub-rule submits and pops with the rule', (tester) async {
    final result = await openDialog(
      tester,
      rule: Rule.value('SUB-RULE,example.com,sub-a'),
    );
    final message = appLocalizations.emptyTip(appLocalizations.subRule);

    await tester.tap(find.text(appLocalizations.confirm));
    await tester.pumpAndSettle();

    expect(find.text(message), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    final rule = result();
    expect(rule, isNotNull);
    expect(rule!.value, contains('sub-a'));
  });

  testWidgets('provider validation still reports its own message', (
    tester,
  ) async {
    // `RULE-SET,<provider>,<target>` with an empty provider: the D3 change must
    // not have disturbed the sibling field that already had `errorText`.
    await openDialog(tester, rule: Rule.value('RULE-SET,,DIRECT'));
    final message = appLocalizations.emptyTip(appLocalizations.ruleProviders);

    await tester.tap(find.text(appLocalizations.confirm));
    await tester.pumpAndSettle();

    expect(find.text(message), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
