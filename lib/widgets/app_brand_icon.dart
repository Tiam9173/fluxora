import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluxora/common/brand_icons.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/providers/config.dart';
import 'package:fluxora/widgets/app_icon_crop.dart';
import 'package:synchronized/synchronized.dart';

final customAppIconProvider = AsyncNotifierProvider<CustomAppIcon, Uint8List?>(
  CustomAppIcon.new,
);

class CustomAppIcon extends AsyncNotifier<Uint8List?> {
  static const _dataPrefix = 'data:image/png;base64,';
  static const _maxFileBytes = 2 * 1024 * 1024;
  final _writes = Lock();

  @override
  Future<Uint8List?> build() async {
    try {
      final prefs = await preferences.sharedPreferencesCompleter.future;
      final saved = prefs?.getString(customSidebarIconKey);
      if (saved == null || saved.isEmpty) return null;
      if (saved.startsWith(_dataPrefix)) {
        if (saved.length > 220000) return null;
        return base64Decode(saved.substring(_dataPrefix.length));
      }
      // Older desktop builds stored a path to the original user image.
      return await _readIcon(saved);
    } catch (_) {
      return null;
    }
  }

  Future<void> pick({BuildContext? context}) => _writes.synchronized(() async {
    if (state.isLoading) await future;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowCompression: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;
    final image = await _decodeIcon(path, context == null ? 192 : 1536);
    final Uint8List icon;
    try {
      if (context == null) {
        icon = await _encodeIcon(image);
      } else {
        if (!context.mounted) return;
        final crop = await showAppIconCrop(context, image);
        if (crop == null) return;
        final edge = math.min(192, math.max(1, crop.width.floor()));
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawImageRect(
          image,
          crop,
          Rect.fromLTWH(0, 0, edge.toDouble(), edge.toDouble()),
          Paint()..filterQuality = FilterQuality.medium,
        );
        final picture = recorder.endRecording();
        try {
          final cropped = await picture.toImage(edge, edge);
          try {
            icon = await _encodeIcon(cropped);
          } finally {
            cropped.dispose();
          }
        } finally {
          picture.dispose();
        }
      }
    } finally {
      image.dispose();
    }
    final prefs = await preferences.sharedPreferencesCompleter.future;
    if (prefs == null ||
        !await prefs.setString(
          customSidebarIconKey,
          '$_dataPrefix${base64Encode(icon)}',
        )) {
      throw StateError('Unable to save custom icon');
    }
    if (ref.mounted) state = AsyncData(icon);
  });

  Future<void> clear() => _writes.synchronized(() async {
    if (state.isLoading) await future;
    final prefs = await preferences.sharedPreferencesCompleter.future;
    if (prefs == null || !await prefs.remove(customSidebarIconKey)) {
      throw StateError('Unable to remove custom icon');
    }
    if (ref.mounted) state = const AsyncData(null);
  });

  Future<Uint8List> _readIcon(String path) async {
    final image = await _decodeIcon(path, 192);
    try {
      return await _encodeIcon(image);
    } finally {
      image.dispose();
    }
  }

  Future<Uint8List> _encodeIcon(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Future<ui.Image> _decodeIcon(String path, int maxEdge) async {
    final file = await File(path).open();
    final Uint8List bytes;
    try {
      bytes = await file.read(_maxFileBytes + 1);
    } finally {
      await file.close();
    }
    if (bytes.isEmpty || bytes.length > _maxFileBytes) {
      throw const FormatException('Invalid icon size');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        if (descriptor.width > 4096 || descriptor.height > 4096) {
          throw const FormatException('Invalid icon dimensions');
        }
        final landscape = descriptor.width >= descriptor.height;
        final codec = await descriptor.instantiateCodec(
          targetWidth: landscape && descriptor.width > maxEdge ? maxEdge : null,
          targetHeight: !landscape && descriptor.height > maxEdge
              ? maxEdge
              : null,
        );
        try {
          return (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }
}

class AppBrandIcon extends ConsumerWidget {
  const AppBrandIcon({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (style, dark) = ref.watch(
      themeSettingProvider.select((p) => (p.appIconStyle, p.useDarkIcon)),
    );
    final custom = ref.watch(customAppIconProvider).asData?.value;
    Widget fallback() => Image.asset(
      BrandIcons.asset(style, dark),
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
    if (custom == null) return fallback();
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .22),
      child: Image.memory(
        custom,
        width: size,
        height: size,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => fallback(),
      ),
    );
  }
}
