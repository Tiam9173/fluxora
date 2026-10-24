import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/profiles/aggregate_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders aggregate modes and custom switches', (tester) async {
    globalState.config = Config(
      themeProps: defaultThemeProps,
      profiles: const [],
      aggregateMode: AggregateMode.custom,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalizationDelegate()],
        supportedLocales: const [Locale('en')],
        home: const Scaffold(body: AggregateView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Merge mode'), findsOneWidget);
    expect(find.text('Node pool'), findsOneWidget);
    expect(find.text('Full merge'), findsOneWidget);
    expect(find.text('Custom merge'), findsOneWidget);
    expect(
      find.text('Single aggregate group (including current subscription)'),
      findsOneWidget,
    );
  });
}
