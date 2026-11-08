import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/models/models.dart';
import 'package:fluxora/state.dart';

class _FormPage extends StatefulWidget {
  const _FormPage(this.onInit);
  final VoidCallback onInit;
  @override
  State<_FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<_FormPage> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const Text('Form'),
        const TextField(),
        TextButton(
          onPressed: () =>
              BaseNavigator.push(context, const Scaffold(body: Text('Detail'))),
          child: const Text('Detail'),
        ),
      ],
    ),
  );
}

void main() {
  for (final mobile in [true, false]) {
    testWidgets(
      'return retains form state and uses the current motion policy, mobile=$mobile',
      (tester) async {
        globalState.appState = AppState(
          viewSize: mobile ? const Size(400, 800) : const Size(1200, 800),
          brightness: Brightness.dark,
          version: 1,
          requests: FixedList(10),
          logs: FixedList(10),
          traffics: FixedList(10),
          totalTraffic: Traffic(),
          systemUiOverlayStyle: const SystemUiOverlayStyle(),
        );
        var off = false;
        var inits = 0;
        late StateSetter update;
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, set) {
              update = set;
              return MaterialApp(
                navigatorKey: navigator,
                themeAnimationDuration: Duration.zero,
                theme: ThemeData(
                  extensions: [
                    FluxoraMaterial(
                      motionStyle: off
                          ? FluxoraMotionStyle.off
                          : FluxoraMotionStyle.system,
                    ),
                  ],
                ),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () =>
                          BaseNavigator.push(context, _FormPage(() => inits++)),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              );
            },
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final route = ModalRoute.of(tester.element(find.text('Form')))!;
        expect(route.transitionDuration, FluxoraMotion.base);
        expect(route.reverseTransitionDuration, FluxoraMotion.fast);
        await tester.enterText(find.byType(TextField), 'keep my input');
        await tester.tap(find.text('Detail'));
        await tester.pump(const Duration(milliseconds: 350));
        navigator.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('keep my input'), findsOneWidget);
        expect(inits, 1);
        update(() => off = true);
        await tester.pump();
        expect(inits, 1);
        expect(find.text('keep my input'), findsOneWidget);
        expect(route.reverseTransitionDuration, Duration.zero);
        navigator.currentState!.pop();
        await tester.pump();
        expect(find.text('Open'), findsOneWidget);
        expect(find.text('Form'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
