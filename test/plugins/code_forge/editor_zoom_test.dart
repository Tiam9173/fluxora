import 'dart:io';

import 'package:code_forge/code_forge.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
// `flutter_rust_bridge` arrives transitively through `code_forge`; the import
// exists only to construct the ExternalLibrary for the prebuilt DLL.
// ignore: depend_on_referenced_packages
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart'
    show ExternalLibrary;
import 'package:flutter_test/flutter_test.dart';

/// item 6 ④ — editor zoom gestures. The gesture *rules* are pure functions and
/// the gesture *plumbing* is covered with synthetic pointers (the approach
/// upstream's zoom_test.dart takes); the visual result — that the editor
/// re-renders larger — needs a device and is not asserted here.
///
/// The widget tests need the Rust-backed controller (`CodeForgeController`
/// builds a `Rope` through flutter_rust_bridge), so they load the DLL left by
/// the last desktop build. A fresh clone without a build artifact skips them
/// instead of failing — the pure-function groups still run.
const _prebuiltRustLib =
    'build/windows/x64/plugins/code_forge/cargokit_build/'
    'x86_64-pc-windows-msvc/release/code_forge.dll';

void main() {
  final rustLibFile = File(_prebuiltRustLib);
  final hasRustLib = rustLibFile.existsSync();

  setUpAll(() async {
    if (hasRustLib) {
      await RustLib.init(
        externalLibrary: ExternalLibrary.open(rustLibFile.absolute.path),
      );
    }
  });
  group('clampEditorZoom', () {
    test('keeps the zoom inside the shared bounds', () {
      expect(clampEditorZoom(1), 1);
      expect(clampEditorZoom(0.1), kEditorMinZoom);
      expect(clampEditorZoom(9), kEditorMaxZoom);
    });
  });

  group('editorWheelTargetZoom', () {
    test('scroll up (dy < 0) steps in, scroll down steps out', () {
      expect(editorWheelTargetZoom(1, -10), closeTo(1.1, 1e-9));
      expect(editorWheelTargetZoom(1, 10), closeTo(1 / 1.1, 1e-9));
    });

    test('a zero delta is a no-op, not a jitter', () {
      expect(editorWheelTargetZoom(1, 0), 1);
    });

    test('the result is always clamped', () {
      expect(editorWheelTargetZoom(kEditorMaxZoom, -10), kEditorMaxZoom);
      expect(editorWheelTargetZoom(kEditorMinZoom, 10), kEditorMinZoom);
    });
  });

  group('focalZoomMatrix', () {
    test('the focal point maps to itself', () {
      const focal = Offset(120, 240);

      final mapped = MatrixUtils.transformPoint(
        focalZoomMatrix(focal, 1.37),
        focal,
      );

      expect(mapped.dx, closeTo(focal.dx, 1e-6));
      expect(mapped.dy, closeTo(focal.dy, 1e-6));
    });

    test('a point beyond the focal point is pushed further out', () {
      const focal = Offset(100, 100);

      final mapped = MatrixUtils.transformPoint(
        focalZoomMatrix(focal, 2),
        const Offset(200, 100),
      );

      expect(mapped.dx, closeTo(300, 1e-6));
      expect(mapped.dy, closeTo(100, 1e-6));
    });
  });

  group('gestures through the real widget', () {
    double? committed;

    Future<void> pumpEditor(WidgetTester tester, {double zoom = 1}) async {
      if (!hasRustLib) {
        markTestSkipped('no prebuilt code_forge.dll — run a desktop build first');
        return;
      }
      committed = null;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: CodeForge(
                controller: CodeForgeController(),
                zoom: zoom,
                onZoomEnd: (value) => committed = value,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Offset centerOf(WidgetTester tester) =>
        tester.getCenter(find.byType(CodeForge));

    testWidgets('ctrl + wheel up commits a zoom-in', (tester) async {
      await pumpEditor(tester);
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(centerOf(tester)));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -20)));
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(committed, closeTo(1.1, 1e-9));
    });

    testWidgets('ctrl + wheel down commits a zoom-out', (tester) async {
      await pumpEditor(tester, zoom: 1.2);
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(centerOf(tester)));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 20)));
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(committed, closeTo(1.2 / 1.1, 1e-9));
    });

    testWidgets('a plain wheel is not a zoom', (tester) async {
      await pumpEditor(tester);
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(centerOf(tester)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -20)));
      await tester.pump();

      expect(committed, isNull);
    });

    testWidgets('two fingers spreading commit a zoom-in', (tester) async {
      await pumpEditor(tester);
      final center = centerOf(tester);
      final p1 = await tester.startGesture(center.translate(-20, 0));
      final p2 = await tester.startGesture(center.translate(20, 0));
      await tester.pump();
      await p1.moveTo(center.translate(-70, 0));
      await p2.moveTo(center.translate(70, 0));
      await tester.pump();
      await p1.up();
      await p2.up();
      await tester.pump(kDoubleTapTimeout);

      // 40 → 140 apart is 3.5×, clamped to the shared maximum.
      expect(committed, kEditorMaxZoom);
    });

    testWidgets('a gesture at the upper bound commits nothing', (tester) async {
      await pumpEditor(tester, zoom: kEditorMaxZoom);
      final center = centerOf(tester);
      final p1 = await tester.startGesture(center.translate(-20, 0));
      final p2 = await tester.startGesture(center.translate(20, 0));
      await tester.pump();
      await p1.moveTo(center.translate(-70, 0));
      await p2.moveTo(center.translate(70, 0));
      await tester.pump();
      await p1.up();
      await p2.up();
      await tester.pump(kDoubleTapTimeout);

      expect(committed, isNull);
    });
  });
}
