// Run with flutter test --no-pub tool/render_brand_icons.dart.
// Uses the project's installed SVG renderer; never initializes the application.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('render reproducible brand masters', () async {
    final output = Directory('build/brand_icons')..createSync(recursive: true);
    final files = [File('${output.path}/status.svg')];
    expect(files.single.existsSync(), isTrue);
    for (final file in files) {
      final loaded = await vg.loadPicture(
        SvgStringLoader(file.readAsStringSync()),
        null,
      );
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)..scale(4);
      canvas.drawPicture(loaded.picture);
      final picture = recorder.endRecording();
      final image = await picture.toImage(1024, 1024);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(data, isNotNull);
      final name = file.uri.pathSegments.last
          .replaceFirst('brand_', '')
          .replaceFirst('.svg', '.png');
      File('${output.path}/$name').writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
      loaded.picture.dispose();
    }
  });
}
