import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/views/config/general.dart';

/// P1 ⑥ — the degraded-config notice.
///
/// The notice renders the core's **raw** message, so the narrow-width cases
/// guard the longest realistic line: a jsdelivr URL inside an `EOF` error. No
/// overflow means the user can actually read which rule provider failed on a
/// 280dp phone.
void main() {
  const sampleMessage =
      'initial rule provider github error: 502 Bad Gateway\n'
      'initial rule provider awavenue-ads error: Get '
      "'https://cdn.jsdelivr.net/gh/x/y.yaml': EOF";

  setUpAll(() async {
    // Production widgets read the global `appLocalizations`, whose `_current`
    // is only set by `AppLocalizations.load`.
    await AppLocalizations.load(const Locale('zh', 'CN'));
  });

  testWidgets('shows the localised title and the raw core message', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RuleProviderWarningNotice(message: sampleMessage),
        ),
      ),
    );

    expect(
      find.text(appLocalizations.ruleProviderWarningsTitle),
      findsOneWidget,
    );
    expect(
      find.textContaining('initial rule provider github error: 502'),
      findsOneWidget,
    );
    expect(find.textContaining('cdn.jsdelivr.net'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismiss button invokes the callback', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RuleProviderWarningNotice(
            message: sampleMessage,
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.close));
    expect(dismissed, isTrue);
  });

  for (final size in const [Size(280, 560), Size(320, 640)]) {
    testWidgets('no overflow at ${size.width.toInt()}dp', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RuleProviderWarningNotice(message: sampleMessage),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  }
}
