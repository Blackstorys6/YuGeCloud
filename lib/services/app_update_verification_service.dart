import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUpdateVerificationService {
  static const String _pendingVersionKey = 'yugecloud_pending_update_version';

  static int _compareVersions(String a, String b) {
    List<int> parseVersion(String version) {
      final parts = version.trim().split('+');
      final numbers = parts.first
          .split('.')
          .map((part) => int.tryParse(part) ?? 0)
          .toList();
      final buildNumber = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      numbers.add(buildNumber);
      return numbers;
    }

    final left = parseVersion(a);
    final right = parseVersion(b);

    for (var i = 0; i < 4; i++) {
      final x = i < left.length ? left[i] : 0;
      final y = i < right.length ? right[i] : 0;
      if (x > y) return 1;
      if (x < y) return -1;
    }

    return 0;
  }

  /// 记录准备安装的目标版本。
  Future<void> recordPendingVersion(String version) async {
    final normalized = version.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('目标版本不能为空');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingVersionKey, normalized);
  }

  /// App 再次启动时验证更新是否成功。
  /// 返回 true 表示本次检测确认更新成功。
  Future<bool> verifyPendingUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final targetVersion = prefs.getString(_pendingVersionKey);

    if (targetVersion == null || targetVersion.isEmpty) {
      return false;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

    if (_compareVersions(currentVersion, targetVersion) >= 0) {
      await prefs.remove(_pendingVersionKey);
      return true;
    }

    return false;
  }

  /// 获取尚未验证的目标版本。
  Future<String?> getPendingVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingVersionKey);
  }
}
