
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/remote_config_service.dart';
import '../services/update_service.dart';

Future<void> showAppUpdateDialog(
  BuildContext context,
  UpdateCheckResult update,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !update.isForced,
    builder: (_) => _AppUpdateDialog(update: update),
  );
}

class _AppUpdateDialog extends StatefulWidget {
  final UpdateCheckResult update;

  const _AppUpdateDialog({required this.update});

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  final _service = UpdateService.instance;

  bool _isDownloading = false;
  bool _isInstalling = false;
  int _received = 0;
  int? _total;
  String? _apkPath;
  String? _error;

  bool get _isBusy => _isDownloading || _isInstalling;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _downloadAndInstall() async {
    if (_isBusy) return;

    setState(() {
      _isDownloading = true;
      _received = 0;
      _total = null;
      _error = null;
    });

    try {
      final path = await _service.downloadUpdate(
        widget.update,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _received = received;
            _total = total;
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _apkPath = path;
        _isDownloading = false;
      });

      await _installDownloadedApk();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _error = '下载失败：$e';
      });
    }
  }

  Future<void> _installDownloadedApk() async {
    final path = _apkPath;
    if (path == null || _isBusy) return;

    setState(() {
      _isInstalling = true;
      _error = null;
    });

    try {
      final canInstall = await _service.canInstallPackages();

      if (!mounted) return;

      if (!canInstall) {
        setState(() {
          _isInstalling = false;
          _error = '请先允许屿哥云安装未知应用，然后返回此页面继续安装。';
        });
        await _service.openInstallSettings();
        return;
      }

      await _service.installApk(path);

      if (!mounted) return;
      setState(() {
        _isInstalling = false;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _isInstalling = false;
        _error = '安装启动失败：${e.message ?? e.code}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInstalling = false;
        _error = '安装失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;
    final progress = _total != null && _total! > 0
        ? (_received / _total!).clamp(0.0, 1.0)
        : null;

    return PopScope(
      canPop: !update.isForced && !_isBusy,
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update_alt_rounded),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                update.isForced ? '需要更新' : '发现新版本',
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '屿哥云 ${update.latestVersion}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (update.isForced) ...[
                const SizedBox(height: 8),
                const Text(
                  '此版本为强制更新，请完成更新后继续使用。',
                ),
              ],
              if (update.changelog?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 16),
                Text(
                  '更新内容',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(update.changelog!),
              ],
              if (_isDownloading) ...[
                const SizedBox(height: 20),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 8),
                Text(
                  _total != null && _total! > 0
                      ? '${(progress! * 100).toStringAsFixed(1)}%  '
                          '${_formatBytes(_received)} / ${_formatBytes(_total!)}'
                      : '已下载 ${_formatBytes(_received)}',
                ),
              ],
              if (_isInstalling) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                const Text('正在打开系统安装界面…'),
              ],
              if (_apkPath != null && !_isBusy) ...[
                const SizedBox(height: 12),
                const Text('APK 已下载并通过 SHA-256 校验。'),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!update.isForced)
            TextButton(
              onPressed: _isBusy ? null : () => Navigator.of(context).pop(),
              child: const Text('稍后更新'),
            ),
          FilledButton(
            onPressed: _isBusy
                ? null
                : _apkPath == null
                    ? _downloadAndInstall
                    : _installDownloadedApk,
            child: Text(
              _isDownloading
                  ? '正在下载'
                  : _isInstalling
                      ? '正在启动安装'
                      : _apkPath == null
                          ? '立即更新'
                          : '继续安装',
            ),
          ),
        ],
      ),
    );
  }
}
