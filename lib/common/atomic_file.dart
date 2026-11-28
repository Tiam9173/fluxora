import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

final _windowsKernel32 = DynamicLibrary.open('kernel32.dll');
final _moveFileEx = _windowsKernel32
    .lookupFunction<
      Int32 Function(Pointer<Utf16>, Pointer<Utf16>, Uint32),
      int Function(Pointer<Utf16>, Pointer<Utf16>, int)
    >('MoveFileExW');
final _getLastError = _windowsKernel32
    .lookupFunction<Uint32 Function(), int Function()>('GetLastError');

/// Publish the complete file, leaving the last good copy intact on failure.
Future<void> writeTextAtomically(File file, String content) async {
  await file.parent.create(recursive: true);
  final staging = await file.parent.createTemp('.fluxora-write-');
  try {
    final temp = File(p.join(staging.path, 'data'));
    await temp.writeAsString(content, flush: true);
    if (Platform.isWindows) {
      final source = temp.path.toNativeUtf16();
      final destination = file.path.toNativeUtf16();
      try {
        if (_moveFileEx(source, destination, 0x1 | 0x8) == 0) {
          final errorCode = _getLastError();
          throw FileSystemException(
            'Unable to atomically replace file',
            file.path,
            OSError('MoveFileExW failed', errorCode),
          );
        }
      } finally {
        calloc.free(source);
        calloc.free(destination);
      }
    } else {
      await temp.rename(file.path);
    }
  } finally {
    try {
      final temp = File(p.join(staging.path, 'data'));
      if (await temp.exists()) await temp.delete();
      await staging.delete();
    } on FileSystemException {
      // Cleanup cannot mask a write failure or undo a successful replacement.
    }
  }
}
