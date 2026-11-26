import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'remote_config_service.dart';

class AppUpdateInstaller {
  static const MethodChannel _channel =
      MethodChannel('com.yugecloud.app/update');

  /// 下载 APK、校验 SHA256，然后请求 Android 系统安装。
  /// 返回值：started 或 permission_required。
  Future<String> downloadAndInstall(
    UpdateCheckResult update, {
    void Function(int received, int total)? onProgress,
  }) async {
    final url = update.downloadUrl?.trim() ?? '';
    final expectedHash = update.sha256?.trim().toLowerCase() ?? '';

    if (url.isEmpty) {
      throw Exception('更新下载地址为空');
    }

    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw Exception('更新地址无效或不是 HTTPS 地址');
    }

    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedHash)) {
      throw Exception('更新配置缺少有效的 SHA256，已取消安装');
    }

    final directory = await getTemporaryDirectory();
    final updateDirectory = Directory('${directory.path}/updates');
    await updateDirectory.create(recursive: true);

    final safeVersion =
        update.latestVersion.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final apkFile = File('${updateDirectory.path}/yugecloud-$safeVersion.apk');

    final client = http.Client();

    try {
      final request = http.Request('GET', uri);
      request.headers['Accept'] = 'application/vnd.android.package-archive';

      final response = await client.send(request).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode != 200) {
        throw Exception('APK 下载失败，HTTP ${response.statusCode}');
      }

      final finalUri = response.request?.url;
      if (finalUri == null || finalUri.scheme != 'https') {
        throw Exception('下载发生了不安全的 HTTP 跳转');
      }

      final total = response.contentLength ?? 0;
      var received = 0;

      final sink = apkFile.openWrite();
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 45),
        )) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (received <= 0 || !await apkFile.exists()) {
        throw Exception('下载文件为空');
      }

      final actualHash = await sha256.bind(apkFile.openRead()).first;
      if (actualHash.toString().toLowerCase() != expectedHash) {
        throw Exception('APK SHA256 校验失败，已取消安装');
      }

      final result = await _channel.invokeMethod<String>(
        'installApk',
        {'path': apkFile.path},
      );

      if (result != 'started' && result != 'permission_required') {
        throw Exception('Android 未能启动安装流程');
      }

      return result!;
    } catch (_) {
      if (await apkFile.exists()) {
        await apkFile.delete();
      }
      rethrow;
    } finally {
      client.close();
    }
  }
}
