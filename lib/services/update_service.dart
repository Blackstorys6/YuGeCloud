import 'dart:io';

import 'package:flutter/services.dart';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'remote_config_service.dart';

/// YuGeCloud Android 自动更新服务。
///
/// 负责检查版本、下载 APK、报告下载进度和校验 SHA-256。
/// APK 安装交由后续 Android 原生接口处理。
class UpdateService {
  UpdateService._();

  static final UpdateService instance = UpdateService._();

  bool _isDownloading = false;

  static const MethodChannel _updateChannel =
      MethodChannel('com.yugenb/app_update');

  /// 检查 Android 是否允许安装外部 APK。
  Future<bool> canInstallPackages() async {
    if (!Platform.isAndroid) return false;
    return await _updateChannel.invokeMethod<bool>(
          'canInstallPackages',
        ) ??
        false;
  }

  /// 打开 Android 安装未知应用的授权设置。
  Future<void> openInstallSettings() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('仅支持 Android');
    }
    await _updateChannel.invokeMethod<bool>('openInstallSettings');
  }

  /// 将已校验的 APK 交给 Android 系统安装。
  Future<void> installApk(String apkPath) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('仅支持 Android');
    }
    if (apkPath.trim().isEmpty) {
      throw ArgumentError('APK 路径不能为空');
    }
    await _updateChannel.invokeMethod<bool>(
      'installApk',
      {'path': apkPath},
    );
  }

  /// 获取当前 App 版本并检查远程更新。
  Future<UpdateCheckResult?> checkForUpdate() async {
    if (!Platform.isAndroid) return null;

    final packageInfo = await PackageInfo.fromPlatform();
    return RemoteConfigService().checkForUpdate(packageInfo.version);
  }

  /// 下载更新 APK。
  ///
  /// 返回校验通过后的 APK 文件路径。
  /// 下载期间通过 onProgress 回调传递已下载字节数和总字节数。
  Future<String> downloadUpdate(
    UpdateCheckResult update, {
    required void Function(int received, int? total) onProgress,
  }) async {
    if (_isDownloading) {
      throw StateError('已有更新任务正在下载');
    }

    if (!update.hasUpdate) {
      throw StateError('当前没有可下载的更新');
    }

    final downloadUrl = update.downloadUrl?.trim();
    if (downloadUrl == null || downloadUrl.isEmpty) {
      throw StateError('远程更新配置缺少下载地址');
    }

    final uri = Uri.tryParse(downloadUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw StateError('下载地址无效或不是 HTTPS 地址');
    }

    final expectedHash = update.sha256?.trim().toLowerCase();
    if (expectedHash == null ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedHash)) {
      throw StateError('远程配置缺少有效的 SHA-256 校验值，已拒绝下载');
    }

    _isDownloading = true;

    final client = http.Client();
    File? temporaryFile;
    IOSink? fileSink;

    try {
      final request = http.Request('GET', uri);
      request.headers['Accept'] = 'application/vnd.android.package-archive';

      final response = await client.send(request).timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('APK 下载失败，HTTP ${response.statusCode}');
      }

      final directory = await getTemporaryDirectory();
      final safeVersion = update.latestVersion.replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]'),
        '_',
      );

      temporaryFile = File(
        '${directory.path}/yugecloud_update_$safeVersion.apk.part',
      );

      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }

      fileSink = temporaryFile.openWrite();

      final digestSink = _DigestCollector();
      final hashSink = sha256.startChunkedConversion(digestSink);

      final total = response.contentLength;
      var received = 0;

      await for (final chunk in response.stream) {
        fileSink.add(chunk);
        hashSink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }

      hashSink.close();
      await fileSink.flush();
      await fileSink.close();
      fileSink = null;

      if (total != null && total > 0 && received != total) {
        throw const FormatException('APK 下载不完整');
      }

      final actualHash = digestSink.value!.toString();

      if (actualHash != expectedHash) {
        throw const FormatException('APK SHA-256 校验失败，已拒绝安装');
      }

      final apkFile = File(
        '${directory.path}/yugecloud_update_$safeVersion.apk',
      );

      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      return (await temporaryFile.rename(apkFile.path)).path;
    } catch (_) {
      if (fileSink != null) {
        await fileSink.close();
      }

      if (temporaryFile != null && await temporaryFile.exists()) {
        await temporaryFile.delete();
      }

      rethrow;
    } finally {
      client.close();
      _isDownloading = false;
    }
  }
}

/// 接收 SHA-256 分块计算结果。
class _DigestCollector implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}
