import 'package:flutter/material.dart';

import '../services/app_update_installer.dart';
import '../services/remote_config_service.dart';

class AppUpdateDialog extends StatefulWidget {
  final UpdateCheckResult update;

  const AppUpdateDialog({
    super.key,
    required this.update,
  });

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  final AppUpdateInstaller _installer = AppUpdateInstaller();

  bool _downloading = false;
  bool _installStarted = false;
  int _received = 0;
  int _total = 0;
  double _downloadSpeed = 0;
  String? _message;
  bool _waitingForPermission = false;
  bool _resumingInstall = false;
  late final AppLifecycleListener _appLifecycleListener;

  @override
  void initState() {
    super.initState();
    _appLifecycleListener = AppLifecycleListener(
      onResume: _handleAppResumed,
    );
  }

  @override
  void dispose() {
    _appLifecycleListener.dispose();
    super.dispose();
  }

  void _handleAppResumed() {
    _continueInstallIfAuthorized();
  }

  Future<void> _continueInstallIfAuthorized() async {
    if (!_waitingForPermission || _resumingInstall || !mounted) return;

    _resumingInstall = true;
    try {
      final allowed = await _installer.canInstallPackages();
      if (!allowed || !mounted) return;

      final result = await _installer.installDownloadedApk(widget.update);

      if (!mounted) return;
      setState(() {
        _waitingForPermission = result == 'permission_required';
        _installStarted = result == 'started';
        _waitingForPermission = result == 'permission_required';
        _message = result == 'permission_required'
            ? '尚未获得安装权限，请在系统设置中允许后返回。'
            : '已打开 Android 系统安装界面，请按照系统提示完成更新。';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = '继续安装失败：$e';
      });
    } finally {
      _resumingInstall = false;
    }
  }

  Future<void> _startUpdate() async {
    setState(() {
      _downloading = true;
      _message = null;
      _waitingForPermission = false;
      _received = 0;
      _total = 0;
      _downloadSpeed = 0;
    });

    try {
      final result = await _installer.downloadAndInstall(
        widget.update,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _received = received;
            _total = total;
          });
        },
        onSpeed: (bytesPerSecond) {
          if (!mounted) return;
          setState(() {
            _downloadSpeed = bytesPerSecond;
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _downloading = false;
        _installStarted = result == 'started';
        _waitingForPermission = result == 'permission_required';
        _message = result == 'permission_required'
            ? '请在系统设置中允许屿哥云安装未知来源应用，然后返回此页面重新点击安装。'
            : '已打开 Android 系统安装界面，请按照系统提示完成更新。';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _message = '更新失败：$e';
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    }
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  @override
  Widget build(BuildContext context) {
    final forced = widget.update.isForced;
    final progress = _total > 0 ? (_received / _total).clamp(0.0, 1.0) : null;

    return PopScope(
      canPop: !forced || _installStarted,
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update_alt, color: Colors.deepPurple),
            const SizedBox(width: 10),
            Expanded(
              child: Text(forced ? '需要更新' : '发现新版本'),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '屿哥云 ${widget.update.latestVersion}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (forced) ...[
                const SizedBox(height: 8),
                const Text(
                  '此版本为必要更新，请完成更新后继续使用。',
                  style: TextStyle(color: Colors.orange),
                ),
              ],
              if (widget.update.changelog?.isNotEmpty == true) ...[
                const SizedBox(height: 14),
                const Text(
                  '更新内容',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(widget.update.changelog!),
              ],
              if (_downloading) ...[
                const SizedBox(height: 20),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 8),
                Text(
                  _total > 0
                      ? '${_formatBytes(_received)} / ${_formatBytes(_total)}'
                      : '正在下载：${_formatBytes(_received)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '下载速度：${_formatSpeed(_downloadSpeed)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 14),
                Text(
                  _message!,
                  style: TextStyle(
                    color: _message!.startsWith('更新失败')
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!forced && !_downloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('稍后更新'),
            ),
          if (_installStarted)
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            )
          else
            FilledButton(
              onPressed: _downloading ? null : _startUpdate,
              child: Text(
                _downloading
                    ? '正在下载…'
                    : _message?.contains('系统设置') == true
                        ? '重新尝试安装'
                        : '下载并安装',
              ),
            ),
        ],
      ),
    );
  }
}
