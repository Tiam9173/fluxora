/// item 6 进程图标提取与加载性能（上游 v1.19.6 `lib/common/process_icon.dart`）
///
/// The connection list scrolls past dozens of processes, each wanting its
/// icon. Two things go wrong without a coordinator: every row fires its own
/// extraction the moment it appears (an extraction storm settles on the
/// platform channel), and nothing is remembered between scroll passes.
///
/// Ported in spirit from upstream `process_icon.dart` (+295 lines), with the
/// scope kept to what this project can verify end to end:
///
/// * **serial queue** — at most one extraction in flight (upstream's `_tail`);
/// * **LRU cache** — 50 entries, hits skip extraction entirely (migrated from
///   `connection/item.dart`, where it lived as file-private state);
/// * **Windows extraction in Dart FFI** — `PrivateExtractIcons` → `GetDIBits`
///   → `decodeImageFromPixels` at 96px, instead of a native round-trip per
///   icon. This is the half that runs without a device: it is asserted
///   against a real executable on Windows CI and on the developer machine.
/// * **channel fallback** — macOS / Linux / Android (and Windows misses) go
///   through `app.getPackageIcon`, exactly as before.
///
/// Deliberately NOT ported (would be unverifiable here): upstream's macOS
/// `.app` bundle resolution (needs their `window_ext` extension) and their
/// Linux `.desktop` index (needs the `image` package for a second decoder).
library;

import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/plugins/app.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

/// Resolves a process path (or name) to icon bytes. Injectable so the queue
/// and cache can be tested without touching FFI or the platform channel.
typedef ProcessIconExtractor = Future<Uint8List?> Function(String path);

class ProcessIcon {
  ProcessIcon({ProcessIconExtractor? extractor})
    : _extractor = extractor ?? _extractByPlatform;

  /// Icons are displayed at <= 48 logical px, so 96 device px covers 2x.
  static const size = 96;

  /// Windows extraction source size before the Dart-side downscale.
  static const _windowsSource = 128;

  /// Enough for a full screen of connections with room to scroll.
  static const maxCacheSize = 50;

  final ProcessIconExtractor _extractor;

  /// The serial queue: each extraction waits for the previous one, so a fast
  /// scroll degrades to a slow trickle of native calls instead of a stampede.
  Future<void> _tail = Future.value();

  final Map<String, Uint8List?> _cache = {};
  final List<String> _lru = <String>[];

  /// Test/diagnostic seam: how many entries the LRU currently holds.
  int get cacheLength => _cache.length;

  /// [path] is a process path on desktop (`metadata.processPath`) and falls
  /// back to a bare process name on platforms that only send one. Returns
  /// null when nothing could be resolved — callers substitute a default icon.
  Future<Uint8List?> get(String path) async {
    if (path.isEmpty) return null;
    if (_cache.containsKey(path)) {
      _touch(path);
      return _cache[path];
    }
    // Upstream swallows inside its loader; the equivalent here is that a
    // throwing extractor yields null to its caller — one bad icon must not
    // take the row's future down with it.
    final task = _tail
        .then((_) => _extractor(path))
        .catchError((Object _) => null);
    _tail = task.then((_) {}, onError: (_) {});
    final result = await task;
    // Negative results are cached too: a process whose icon cannot be
    // resolved (or whose exe is locked) would otherwise be re-extracted on
    // every scroll pass — the exact storm this class exists to prevent.
    _put(path, result);
    return result;
  }

  void _touch(String key) {
    _lru
      ..remove(key)
      ..add(key);
  }

  void _put(String key, Uint8List? value) {
    if (_cache.containsKey(key)) {
      _cache[key] = value;
      _touch(key);
      return;
    }
    _cache[key] = value;
    _lru.add(key);
    while (_lru.length > maxCacheSize) {
      _cache.remove(_lru.removeAt(0));
    }
  }

  static Future<Uint8List?> _extractByPlatform(String path) async {
    if (system.isWindows) {
      final icon = await _extractWindowsIcon(path);
      if (icon != null) return icon;
    }
    // Fallback (and the primary path everywhere else): the native channel
    // resolves by process *name*, so strip the path down first.
    return app.getPackageIcon(p.basename(path));
  }

  // ---------------------------------------------------------------------------
  // Windows: PrivateExtractIcons → SHGetFileInfo fallback → GetDIBits → PNG
  // ---------------------------------------------------------------------------

  static Future<Uint8List?> _extractWindowsIcon(String path) async {
    final bitmap = _readWindowsIcon(path);
    if (bitmap == null) return null;
    final (pixels, width, height) = bitmap;
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.bgra8888,
      completer.complete,
      targetWidth: size,
      targetHeight: size,
      // Small icons must not be blown up to 96px: the crop keeps them crisp.
      allowUpscaling: false,
    );
    final image = await completer.future;
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  /// Raw BGRA pixels of the file's icon, or null. Every GDI handle opened
  /// here is released before returning — an icon leak per connection row
  /// would be worse than the problem being fixed.
  static (Uint8List, int, int)? _readWindowsIcon(String path) {
    return using((arena) {
      final pathPtr = path.toNativeUtf16(allocator: arena);
      final iconPtr = arena<IntPtr>();
      final count = PrivateExtractIcons(
        pathPtr,
        0,
        _windowsSource,
        _windowsSource,
        iconPtr,
        nullptr,
        1,
        0,
      );
      var hIcon = count > 0 && count != 0xFFFFFFFF
          ? iconPtr.value
          : 0;
      if (hIcon == 0) {
        // No embedded icon resource: fall back to the shell's mapped icon.
        final info = arena<SHFILEINFO>();
        final res = SHGetFileInfo(
          pathPtr,
          0,
          info,
          sizeOf<SHFILEINFO>(),
          _shgfiIcon, // SHGFI_LARGEICON (0) is implied by a 0 low bit.
        );
        if (res != 0) {
          hIcon = info.ref.hIcon;
        }
      }
      if (hIcon == 0) return null;

      final iconInfo = arena<ICONINFO>();
      if (GetIconInfo(hIcon, iconInfo) == 0) {
        DestroyIcon(hIcon);
        return null;
      }
      final hbmColor = iconInfo.ref.hbmColor;
      final hbmMask = iconInfo.ref.hbmMask;
      final hdc = GetDC(0);
      try {
        if (hbmColor == 0) return null;
        final bitmap = arena<BITMAP>();
        if (GetObject(hbmColor, sizeOf<BITMAP>(), bitmap) == 0) return null;
        final width = bitmap.ref.bmWidth;
        final height = bitmap.ref.bmHeight;
        if (width <= 0 || height <= 0) return null;
        final bmi = arena<BITMAPINFO>();
        bmi.ref.bmiHeader
          ..biSize = sizeOf<BITMAPINFOHEADER>()
          ..biWidth = width
          // Negative height: top-down rows, which is what
          // decodeImageFromPixels expects.
          ..biHeight = -height
          ..biPlanes = 1
          ..biBitCount = 32
          ..biCompression = 0; // BI_RGB
        final length = width * height * 4;
        final bits = arena<Uint8>(length);
        final lines = GetDIBits(
          hdc,
          hbmColor,
          0,
          height,
          bits,
          bmi,
          0, // DIB_RGB_COLORS
        );
        if (lines == 0) return null;
        final pixels = Uint8List.fromList(bits.asTypedList(length));
        _premultiplyAlpha(pixels);
        return (pixels, width, height);
      } finally {
        ReleaseDC(0, hdc);
        if (hbmColor != 0) DeleteObject(hbmColor);
        if (hbmMask != 0) DeleteObject(hbmMask);
        DestroyIcon(hIcon);
      }
    });
  }

  /// GetDIBits hands back straight (non-premultiplied) BGRA; a mostly
  /// transparent icon would composite against black without this fix-up.
  static void _premultiplyAlpha(Uint8List pixels) {
    var hasAlpha = false;
    for (var i = 3; i < pixels.length; i += 4) {
      if (pixels[i] != 0) {
        hasAlpha = true;
        break;
      }
    }
    for (var i = 0; i < pixels.length; i += 4) {
      if (!hasAlpha) {
        pixels[i + 3] = 255;
        continue;
      }
      final alpha = pixels[i + 3];
      if (alpha == 255) continue;
      pixels[i] = pixels[i] * alpha ~/ 255;
      pixels[i + 1] = pixels[i + 1] * alpha ~/ 255;
      pixels[i + 2] = pixels[i + 2] * alpha ~/ 255;
    }
  }
}

/// shgfiIcon — the named constant is absent from win32's exported set.
const _shgfiIcon = 0x00000100;

/// Process-wide coordinator. Stateless beyond the cache, so a single
/// instance serves every list.
final processIcon = ProcessIcon();
