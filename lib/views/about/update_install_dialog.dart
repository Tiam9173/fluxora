import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fluxora/common/common.dart';
import 'package:fluxora/plugins/app.dart';
import 'package:fluxora/state.dart';
import 'package:fluxora/widgets/dialog.dart';
import 'package:flutter/material.dart';

class UpdateInstallDialog extends StatefulWidget {
  const UpdateInstallDialog({
    super.key,
    required this.tag,
    required this.notes,
    required this.assetSuffix,
  });

  final String tag;
  final List<String> notes;
  final String assetSuffix;

  @override
  State<UpdateInstallDialog> createState() => _UpdateInstallDialogState();
}

class _UpdateInstallDialogState extends State<UpdateInstallDialog> {
  CancelToken? _cancelToken;
  int _received = 0;
  int _total = 0;
  String? _error;
  bool _working = false;
  File? _verifiedInstaller;

  Future<void> _downloadAndInstall() async {
    setState(() {
      _working = true;
      _error = null;
      _received = 0;
      _total = 0;
    });
    final token = CancelToken();
    _cancelToken = token;
    try {
      var installer = _verifiedInstaller;
      if (installer == null || !await installer.exists()) {
        final asset = await request.getReleaseAsset(
          widget.tag,
          widget.assetSuffix,
          cancelToken: token,
        );
        _total = asset['size'] as int;
        installer = await request.downloadVerifiedReleaseAsset(
          asset,
          cancelToken: token,
          onProgress: (received, total) {
            if (!mounted || token.isCancelled) return;
            setState(() {
              _received = received;
              _total = total;
            });
          },
        );
        _verifiedInstaller = installer;
        _received = _total;
      }
      if (token.isCancelled || !mounted) return;

      if (system.isAndroid) {
        final result = await app.installApk(installer.path);
        if (result == 'permission-required') {
          setState(() {
            _working = false;
            _error = appLocalizations.installPermissionRequired;
          });
          return;
        }
        if (result != 'started') {
          throw StateError('Android package installer did not start');
        }
      } else if (system.isWindows) {
        if (windows?.runas(installer.path, '', showWindow: true) != true) {
          throw StateError('Windows installer could not be started');
        }
      } else {
        throw UnsupportedError('In-app installation is not supported here');
      }

      _verifiedInstaller = null;
      globalState.navigatorKey.currentState?.pop();
      globalState.showNotifier(appLocalizations.preparingInstall);
    } catch (error) {
      if (!token.isCancelled && mounted) {
        setState(() {
          _working = false;
          _error =
              error is DioException && error.type == DioExceptionType.cancel
              ? null
              : appLocalizations.updateDownloadFailed;
        });
      }
    } finally {
      if (identical(_cancelToken, token)) _cancelToken = null;
    }
  }

  void _cancelOrClose() {
    final token = _cancelToken;
    if (token != null) {
      token.cancel('Update download cancelled');
      _cancelToken = null;
    }
    globalState.navigatorKey.currentState?.pop();
  }

  @override
  Widget build(BuildContext context) {
    final double? progress = _total > 0
        ? (_received / _total).clamp(0.0, 1.0).toDouble()
        : null;
    return CommonDialog(
      title: widget.tag,
      actions: [
        TextButton(
          onPressed: _cancelOrClose,
          child: Text(appLocalizations.cancel),
        ),
        FilledButton.icon(
          onPressed: _working ? null : _downloadAndInstall,
          icon: const Icon(Icons.download_rounded),
          label: Text(appLocalizations.downloadAndInstall),
        ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 310),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final note in widget.notes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('• $note'),
                    ),
                ],
              ),
            ),
            if (_working) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 6),
              Text(
                progress == null
                    ? appLocalizations.preparingInstall
                    : '${(progress * 100).round()}%  ·  '
                          '${_formatBytes(_received)} / ${_formatBytes(_total)}',
                textAlign: TextAlign.center,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
