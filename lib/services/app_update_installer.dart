import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'app_update_verification_service.dart';

import 'remote_config_service.dart';

class AppUpdateInstaller {
  static const MethodChannel _channel =
      MethodChannel('com.yugecloud.app/update');

  Future<String> downloadAndInstall(
    UpdateCheckResult update, {
    void Function(int received, int total)? onProgress,
    void Function(double bytesPerSecond)? onSpeed,
  }) async {
    final url = update.downloadUrl?.trim() ?? '';
    final expectedHash = update.sha256?.trim().toLowerCase() ?? '';

    if (url.isEmpty) throw Exception('更新下载地址为空');

    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw Exception('更新地址无效或不是 HTTPS 地址');
    }

    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedHash)) {
      throw Exception('更新配置缺少有效的 SHA256，已取消安装');
    }

    final temp = await getTemporaryDirectory();
    final directory = Directory('${temp.path}/updates');
    await directory.create(recursive: true);
    await cleanupOldUpdateFiles();

    final version =
        update.latestVersion.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final apkFile = File('${directory.path}/yugecloud-$version.apk');
    final partFile = File('${apkFile.path}.part');

    await _downloadWithResume(
      uri,
      partFile,
      onProgress: onProgress,
      onSpeed: onSpeed,
    );

    if (!await partFile.exists() || await partFile.length() <= 0) {
      throw Exception('下载文件为空');
    }

    final actualHash = await sha256.bind(partFile.openRead()).first;
    if (actualHash.toString().toLowerCase() != expectedHash) {
      await partFile.delete();
      throw Exception('APK SHA256 校验失败，已取消安装');
    }

    if (await apkFile.exists()) await apkFile.delete();
    await partFile.rename(apkFile.path);

    await AppUpdateVerificationService()
        .recordPendingVersion(update.latestVersion);

    final result = await _channel.invokeMethod<String>(
      'installApk',
      {'path': apkFile.path},
    );

    if (result != 'started' && result != 'permission_required') {
      throw Exception('Android 未能启动安装流程');
    }

    return result!;
  }

  /// 查询 Android 是否允许安装未知来源应用。
  Future<bool> canInstallPackages() async {
    final allowed = await _channel.invokeMethod<bool>(
      'canInstallPackages',
    );
    return allowed ?? false;
  }

  /// 安装已经下载并完成 SHA256 校验的 APK。
  Future<String> installDownloadedApk(UpdateCheckResult update) async {
    final temp = await getTemporaryDirectory();
    final version =
        update.latestVersion.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final apkFile = File(
      '${temp.path}/updates/yugecloud-$version.apk',
    );

    if (!await apkFile.exists() || await apkFile.length() <= 0) {
      throw Exception('已下载的 APK 不存在，请重新下载');
    }

    await AppUpdateVerificationService()
        .recordPendingVersion(update.latestVersion);

    final result = await _channel.invokeMethod<String>(
      'installApk',
      {'path': apkFile.path},
    );

    if (result != 'started' && result != 'permission_required') {
      throw Exception('Android 未能启动安装流程');
    }

    return result!;
  }


  /// 清理超过 30 天的旧更新文件。
  Future<void> cleanupOldUpdateFiles({
    Duration maxAge = const Duration(days: 30),
  }) async {
    final temp = await getTemporaryDirectory();
    final directory = Directory('${temp.path}/updates');

    if (!await directory.exists()) return;

    final cutoff = DateTime.now().subtract(maxAge);

    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;

      final name = entity.uri.pathSegments.last;
      if (!name.endsWith('.apk') && !name.endsWith('.apk.part')) {
        continue;
      }

      try {
        final modified = await entity.lastModified();
        if (modified.isBefore(cutoff)) {
          await entity.delete();
        }
      } catch (e) {
        // 单个文件清理失败不影响其他文件。
      }
    }
  }

  Future<void> _downloadWithResume(
    Uri uri,
    File partFile, {
    void Function(int received, int total)? onProgress,
    void Function(double bytesPerSecond)? onSpeed,
  }) async {
    const maxAttempts = 3;
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final client = http.Client();

      try {
        final existing = await partFile.exists() ? await partFile.length() : 0;
        final request = http.Request('GET', uri)
          ..headers['Accept'] = 'application/vnd.android.package-archive';

        if (existing > 0) {
          request.headers['Range'] = 'bytes=$existing-';
        }

        final response = await client.send(request).timeout(
              const Duration(seconds: 30),
            );

        final finalUri = response.request?.url;
        if (finalUri == null || finalUri.scheme != 'https') {
          throw Exception('下载发生了不安全的 HTTP 跳转');
        }

        late final bool append;
        late final int total;

        if (existing > 0 && response.statusCode == 206) {
          final range = response.headers['content-range'];
          final match = range == null
              ? null
              : RegExp(r'^bytes\s+\d+-\d+/(\d+)$', caseSensitive: false)
                  .firstMatch(range);

          if (match == null) {
            throw Exception('服务器返回了无效的断点续传范围');
          }

          append = true;
          total = int.parse(match.group(1)!);
        } else if (response.statusCode == 200) {
          append = false;
          total = response.contentLength ?? 0;
        } else if (response.statusCode == 416 && existing > 0) {
          await partFile.delete();
          throw Exception('服务器拒绝断点续传，准备重新下载');
        } else {
          throw Exception('APK 下载失败，HTTP ${response.statusCode}');
        }

        final sink = partFile.openWrite(
          mode: append ? FileMode.append : FileMode.write,
        );

        var receivedThisAttempt = 0;
        var lastBytes = existing;
        var lastTime = DateTime.now();

        try {
          await for (final chunk in response.stream.timeout(
            const Duration(seconds: 45),
          )) {
            sink.add(chunk);
            receivedThisAttempt += chunk.length;

            final current = (append ? existing : 0) + receivedThisAttempt;
            final now = DateTime.now();
            final elapsed = now.difference(lastTime).inMilliseconds / 1000;
            final speed = elapsed > 0 ? (current - lastBytes) / elapsed : 0.0;

            onProgress?.call(current, total);
            onSpeed?.call(speed);

            if (elapsed >= 0.5) {
              lastBytes = current;
              lastTime = now;
            }
          }

          await sink.flush();
        } finally {
          await sink.close();
        }

        final actualLength = await partFile.length();

        if (total > 0 && actualLength < total) {
          throw Exception('下载未完成：$actualLength/$total 字节');
        }

        if (total > 0 && actualLength > total) {
          await partFile.delete();
          throw Exception('下载文件大小异常，已清理临时文件');
        }

        return;
      } catch (e) {
        lastError = e;

        if (attempt == maxAttempts) break;

        await Future.delayed(Duration(seconds: attempt * 2));
      } finally {
        client.close();
      }
    }

    throw Exception('下载失败，已重试 $maxAttempts 次：$lastError');
  }
}
