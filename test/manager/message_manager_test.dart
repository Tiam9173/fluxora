import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/common/tokens/fluxora_material.dart';
import 'package:fluxora/common/tokens/fluxora_typography.dart';
import 'package:fluxora/manager/message_manager.dart';

import '../support/render_capture.dart';

void main() {
  testWidgets('global toast deduplicates and can be dismissed by swiping', (
    tester,
  ) async {
    final key = GlobalKey<MessageManagerState>();
    final capture = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: fluxoraMaterialTheme(
          ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            fontFamily: 'HarmonyOS_Sans',
            textTheme: FluxoraTypography.textTheme(),
          ),
          FluxoraSurfaceStyle.classic,
        ),
        home: RepaintBoundary(
          key: capture,
          child: MessageManager(key: key, child: const Scaffold()),
        ),
      ),
    );

    unawaited(key.currentState!.message('Connection is ready'));
    unawaited(key.currentState!.message('Connection is ready'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Connection is ready'), findsOneWidget);
    await captureFlutterFrame(
      tester,
      find.byKey(capture),
      'build/bettbox_ui/message-manager-visible.png',
    );

    await tester.drag(find.byType(Dismissible), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Connection is ready'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('toast action remains tappable inside the dismissible card', (
    tester,
  ) async {
    final key = GlobalKey<MessageManagerState>();
    final capture = GlobalKey();
    var actionCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: fluxoraMaterialTheme(
          ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            fontFamily: 'HarmonyOS_Sans',
            textTheme: FluxoraTypography.textTheme(),
          ),
          FluxoraSurfaceStyle.classic,
        ),
        home: RepaintBoundary(
          key: capture,
          child: MessageManager(key: key, child: const Scaffold()),
        ),
      ),
    );

    unawaited(
      key.currentState!.message(
        'Configuration needs attention',
        actionLabel: 'Open',
        onAction: () => actionCalls++,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Configuration needs attention'), findsOneWidget);
    await captureFlutterFrame(
      tester,
      find.byKey(capture),
      'build/bettbox_ui/message-manager-action-visible.png',
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(actionCalls, 1);
    expect(find.text('Configuration needs attention'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });
}
