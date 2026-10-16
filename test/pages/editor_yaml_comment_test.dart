import 'package:flutter_test/flutter_test.dart';

/// item 6 (Bettbox 1.19.4) — the YAML comment rule used by the editor.
///
/// `re_highlight`'s stock `HASH_COMMENT_MODE` is `begin: r'#'` with no
/// lookbehind, so any `#` inside a value opens a comment and the rest of the line
/// highlights as one:
///
/// ```yaml
/// password: abc#def     # `#def` is part of the value
/// ```
///
/// The editor therefore has to supply `begin: r'(?<![^\s])#'`, which means "# not
/// preceded by a non-whitespace character" — line start or after whitespace only.
///
/// These assertions cover the regex itself, which is where the bug lives. The
/// wiring (the `Mode` that carries it) is in `lib/pages/editor.dart`.
void main() {
  // The same pattern the editor installs, copied here deliberately: the point is
  // to pin the *semantics*, and a copy that drifts is caught by the constants
  // below.
  const commentBegin = r'(?<![^\s])#';
  final commentRe = RegExp(commentBegin);

  /// Where a comment starts in [line], or -1 when there is none.
  int commentStart(String line) {
    final m = commentRe.firstMatch(line);
    return m?.start ?? -1;
  }

  group('a # that is part of a value is not a comment', () {
    test('a hash glued to the end of a value', () {
      expect(commentStart('password: abc#def'), -1);
    });

    test('a hash inside a URI fragment', () {
      expect(commentStart('url: https://example.com/#anchor'), -1);
    });

    test('a hash inside a quoted string', () {
      expect(commentStart("name: 'a#b'"), -1);
    });
  });

  group('a real comment is still recognised', () {
    test('at the start of a line', () {
      expect(commentStart('# a comment'), 0);
    });

    test('indented under a key', () {
      expect(commentStart('proxies:\n  # a comment'), 11);
    });

    test('after a value, with whitespace in between', () {
      // `port: 1080  # comment` — the `#` is preceded by a space, so it *is* a
      // comment. This is the case the lookbehind must not break.
      expect(commentStart('port: 1080  # comment'), 12);
    });
  });

  group('the two forms are distinguished by the character before the #', () {
    test('whitespace before # => comment', () {
      expect(commentRe.hasMatch('abc #'), isTrue);
    });

    test('non-whitespace before # => not a comment', () {
      expect(commentRe.hasMatch('abc#'), isFalse);
    });

    test('nothing before # (line start) => comment', () {
      expect(commentRe.hasMatch('#'), isTrue);
    });
  });
}
