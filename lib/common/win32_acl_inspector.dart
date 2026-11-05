import 'dart:convert';
import 'dart:io';

import 'package:fluxora/common/print.dart';

import 'protected_helper.dart';

/// Rights that let the holder change what lives in a directory or in a file.
///
/// `Modify` and `FullControl` subsume these, but Windows frequently reports the
/// granular form instead — a directory ACE of `CreateFiles, Synchronize` is a
/// write grant even though the word "Write" never appears.
const Set<String> _writeClassTokens = <String>{
  'Write',
  'WriteData',
  'AppendData',
  'CreateFiles',
  'CreateDirectories',
  'DeleteSubdirectoriesAndFiles',
  'WriteAttributes',
  'WriteExtendedAttributes',
  'Delete',
  'Modify',
  'FullControl',
};

/// Reads real Windows security facts for a path.
///
/// Deliberately not FFI: the shape needed here (owner SID, ACE list, reparse
/// flag, resolved final path) is exactly what `Get-Acl` already returns, and
/// `FileSystemRights.ToString()` and SIDs are **locale-independent**, so the
/// parser works on a Chinese or English Windows alike.
///
/// Any failure — PowerShell missing, non-zero exit, malformed JSON, unexpected
/// shape — yields [PathSecurityFacts.unknown], which the guard treats as unsafe.
/// A check that cannot be performed must never be read as "fine".
class Win32AclInspector implements AclInspector {
  Win32AclInspector({this.runner = _defaultRunner});

  final Future<ProcessResult> Function(
    List<String> args,
    Map<String, String> env,
  )
  runner;

  static Future<ProcessResult> _defaultRunner(
    List<String> args,
    Map<String, String> env,
  ) => Process.run('powershell', args, environment: env);

  static const String _script = r'''
$ErrorActionPreference = "Stop"
$p = $env:FLUXORA_ACL_TARGET
$out = [ordered]@{ exists = $false; isReparse = $false; finalPath = ""; ownerSid = ""; aces = @() }
if (Test-Path -LiteralPath $p) {
  $out.exists = $true
  $item = Get-Item -LiteralPath $p -Force
  $out.isReparse = [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
  $out.finalPath = (Resolve-Path -LiteralPath $p).ProviderPath
  $acl = Get-Acl -LiteralPath $p
  $out.ownerSid = $acl.Owner
  try { $out.ownerSid = (New-Object System.Security.Principal.NTAccount($acl.Owner)).Translate([System.Security.Principal.SecurityIdentifier]).Value } catch {}
  $aces = @()
  foreach ($ace in $acl.Access) {
    $sid = ""
    try { $sid = $ace.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value } catch { $sid = $ace.IdentityReference.Value }
    $aces += [ordered]@{
      sid = $sid
      allow = ($ace.AccessControlType -eq "Allow")
      rights = $ace.FileSystemRights.ToString()
    }
  }
  $out.aces = $aces
}
$out | ConvertTo-Json -Depth 4 -Compress
''';

  @override
  Future<PathSecurityFacts> inspect(String path) async {
    if (!Platform.isWindows) return const PathSecurityFacts.unknown();
    try {
      final result = await runner(
        <String>[
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          _script,
        ],
        <String, String>{'FLUXORA_ACL_TARGET': path},
      );
      if (result.exitCode != 0) return const PathSecurityFacts.unknown();
      final raw = (result.stdout as String).trim();
      if (raw.isEmpty) return const PathSecurityFacts.unknown();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const PathSecurityFacts.unknown();
      return _fromJson(decoded);
    } catch (e) {
      commonPrint.log('SEC-P0-01: ACL inspection failed for "$path": $e');
      return const PathSecurityFacts.unknown();
    }
  }

  /// Exposed for tests: the same mapping the process path uses.
  static PathSecurityFacts factsFromJson(Map<dynamic, dynamic> json) =>
      _fromJson(json);

  static PathSecurityFacts _fromJson(Map<dynamic, dynamic> json) {
    final exists = json['exists'] == true;
    final isReparse = json['isReparse'] == true;
    final finalPath = (json['finalPath'] as String?) ?? '';
    final ownerSid = (json['ownerSid'] as String?) ?? '';
    final rawAces = json['aces'];
    final entries = <AclEntry>[];
    if (rawAces is List) {
      for (final raw in rawAces) {
        if (raw is! Map) continue;
        final sid = raw['sid'];
        if (sid is! String || sid.isEmpty) continue;
        final allow = raw['allow'] == true;
        final rights = (raw['rights'] as String?) ?? '';
        // `FileSystemRights.ToString()` is a comma-separated list of English
        // enum names — split and match exactly, so `WriteDac` never counts as
        // a plain `Write`.
        final tokens = rights
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toSet();
        entries.add(
          AclEntry(
            sid: sid,
            allow: allow,
            // Directory ACEs are often expressed as granular rights rather than
            // `Modify`; `CreateFiles` on a directory is exactly as dangerous as
            // `Write` on a file — it is how a planted EXE gets in.
            write: tokens.any(_writeClassTokens.contains),
            modify: tokens.contains('Modify'),
            delete: tokens.contains('Delete'),
            writeDac: tokens.contains('WriteDac'),
            writeOwner: tokens.contains('WriteOwner'),
            fullControl: tokens.contains('FullControl'),
          ),
        );
      }
    }
    return PathSecurityFacts(
      exists: exists,
      isReparsePoint: isReparse,
      finalPath: finalPath,
      ownerSid: ownerSid,
      entries: entries,
    );
  }
}
