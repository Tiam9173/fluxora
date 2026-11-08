import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/clash/clash.dart';
import 'package:fluxora/clash/interface.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/common/theme.dart';
import 'package:fluxora/l10n/l10n.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/views/dashboard/widgets/memory_info.dart';

class _MemoryCore extends Fake implements ClashHandlerInterface {
  final result = Completer<String>();
  int reads = 0;
  @override
  Future<String> getMemory() {
    reads++;
    return result.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ClashHandlerInterface previous;
  late _MemoryCore core;
  setUpAll(() async => AppLocalizations.load(const Locale('en')));
  setUp(() {
    previous = clashCore.clashInterface;
    core = _MemoryCore();
    clashCore.clashInterface = core;
    globalState.appState = AppState(
      viewSize: const Size(390, 844),
      brightness: Brightness.dark,
      version: 1,
      requests: FixedList(10),
      logs: FixedList(10),
      traffics: FixedList(10),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
  });
  tearDown(() => clashCore.clashInterface = previous);
  Widget scene(bool enabled) => MaterialApp(
    home: Builder(
      builder: (context) {
        globalState.theme = CommonTheme.of(context, 1);
        globalState.measure = Measure.of(context, 1);
        return TickerMode(
          enabled: enabled,
          child: const Scaffold(body: MemoryInfo()),
        );
      },
    ),
  );

  testWidgets('closing during an IPC read does not schedule another retry', (
    tester,
  ) async {
    await tester.pumpWidget(scene(true));
    await tester.pump(const Duration(milliseconds: 1));
    expect(core.reads, 1);
    await tester.pumpWidget(const SizedBox());
    core.result.complete('0');
    await tester.pump();
    expect(core.reads, 1);
  });
  testWidgets('hidden pages do not poll memory or schedule initial retries', (
    tester,
  ) async {
    await tester.pumpWidget(scene(false));
    await tester.pump(const Duration(seconds: 3));
    dashboardRefreshManager.tick2s.value++;
    await tester.pump();
    expect(core.reads, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
