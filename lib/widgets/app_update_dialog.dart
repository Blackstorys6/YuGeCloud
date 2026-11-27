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
    final changelog = widget.update.changelog
        ?.replaceAll(r'\n', '\n')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    const accent = Color(0xFFA78BFA);
    const surface = Color(0xFF191D30);
    const border = Color(0xFF383451);
    const primaryText = Color(0xFFF4F1FF);
    const secondaryText = Color(0xFFAAA6BF);

    return PopScope(
      canPop: !forced || _installStarted,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF292640),
                Color(0xFF191D30),
                Color(0xFF111522),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: border.withValues(alpha: 0.85)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.38),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(17),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF9B7CF6), Color(0xFF6652C8)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.25),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.system_update_alt_rounded,
                          color: Colors.white,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              forced ? '需要更新' : '发现新版本',
                              style: const TextStyle(
                                color: primaryText,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '屿哥云 · 全新体验',
                              style: TextStyle(
                                color: secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (forced)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFEF9A65).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFEF9A65)
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Text(
                            '重要更新',
                            style: TextStyle(
                              color: Color(0xFFFFB77D),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surface.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(
                        color: border.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '最新版本',
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '屿哥云 ${widget.update.latestVersion}',
                          style: const TextStyle(
                            color: primaryText,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (forced) ...[
                          const SizedBox(height: 10),
                          const Text(
                            '此版本为必要更新，请完成更新后继续使用。',
                            style: TextStyle(
                              color: Color(0xFFFFB77D),
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (changelog?.isNotEmpty == true) ...[
                    const SizedBox(height: 18),
                    const Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: accent,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '更新说明',
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 190),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: surface.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: border.withValues(alpha: 0.6),
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          changelog!,
                          softWrap: true,
                          style: const TextStyle(
                            color: secondaryText,
                            fontSize: 13,
                            height: 1.75,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_downloading) ...[
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '正在下载更新',
                          style: TextStyle(
                            color: primaryText,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          progress == null
                              ? '准备中'
                              : '${(progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor: const Color(0xFF34334B),
                        valueColor: const AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      _total > 0
                          ? '${_formatBytes(_received)} / ${_formatBytes(_total)}'
                          : '已下载：${_formatBytes(_received)}',
                      style: const TextStyle(
                        color: secondaryText,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '下载速度：${_formatSpeed(_downloadSpeed)}',
                      style: const TextStyle(
                        color: secondaryText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text(
                        _message!,
                        style: TextStyle(
                          color: _message!.startsWith('更新失败')
                              ? const Color(0xFFFF8585)
                              : secondaryText,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      if (!forced && !_downloading && !_installStarted)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: secondaryText,
                              side: const BorderSide(color: border),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('稍后更新'),
                          ),
                        ),
                      if (!forced && !_downloading && !_installStarted)
                        const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _downloading
                              ? null
                              : _installStarted
                                  ? () => Navigator.of(context).pop()
                                  : _startUpdate,
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: const Color(0xFF171326),
                            disabledBackgroundColor:
                                accent.withValues(alpha: 0.4),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _installStarted
                                ? '知道了'
                                : _downloading
                                    ? '正在下载…'
                                    : _message?.contains('系统设置') == true
                                        ? '重新尝试安装'
                                        : '下载并安装',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
