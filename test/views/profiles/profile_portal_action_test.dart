import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/profile.dart';
import 'package:fluxora/views/profiles/profiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  Profile profile({String portalUrl = ''}) => Profile(
    id: 'portal-ui',
    label: 'Airport A',
    url: 'https://sub.example.com/api',
    portalUrl: portalUrl,
    portalSource: portalUrl.isEmpty
        ? ProfilePortalSource.unset
        : ProfilePortalSource.manual,
    autoUpdateDuration: Duration.zero,
  );

  Widget tree(Profile value) => ProviderScope(
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(1.4)),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 343,
            child: ProfileItem(
              profile: value,
              groupValue: null,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('configured portal shows one accessible globe action', (
    tester,
  ) async {
    await tester.pumpWidget(tree(profile(portalUrl: 'https://example.com')));
    await tester.pump();

    expect(find.byIcon(Icons.language_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unconfigured portal adds no visual placeholder', (tester) async {
    await tester.pumpWidget(tree(profile()));
    await tester.pump();

    expect(find.byIcon(Icons.language_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
