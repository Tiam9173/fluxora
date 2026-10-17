import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora/views/profiles/scripts.dart';

/// Upstream c0cce973 — the export file name rule. The save dialog itself goes
/// through the platform picker, so this pure rule is the part worth pinning:
/// a wrong suffix or a hidden `.js` are the only ways export can annoy.
void main() {
  group('scriptExportFileName', () {
    test('appends .js to a plain label', () {
      expect(scriptExportFileName('my rules'), 'my rules.js');
    });

    test('keeps an existing .js suffix', () {
      expect(scriptExportFileName('my rules.js'), 'my rules.js');
    });

    test('trims surrounding whitespace', () {
      expect(scriptExportFileName('  spaced  '), 'spaced.js');
    });

    test('falls back to a default for a blank label', () {
      // The editor prevents this, but a blank label must not produce a
      // hidden `.js` file.
      expect(scriptExportFileName('   '), 'script.js');
      expect(scriptExportFileName(''), 'script.js');
    });
  });
}
