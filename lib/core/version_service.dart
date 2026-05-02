import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

const _versionCheckUrl = 'https://voxa.gigalixirapp.com/api/version-check';

class VersionCheckResult {
  final bool forceUpdate;
  final bool hasUpdate;
  final String message;
  final String storeUrl;

  const VersionCheckResult({
    required this.forceUpdate,
    required this.hasUpdate,
    required this.message,
    required this.storeUrl,
  });

  static const noUpdate = VersionCheckResult(
    forceUpdate: false,
    hasUpdate: false,
    message: '',
    storeUrl: '',
  );
}

class VersionService {
  static Future<VersionCheckResult> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;

      final response = await http
          .get(Uri.parse(_versionCheckUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return VersionCheckResult.noUpdate;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final minimum = data['minimum_version'] as String? ?? '1.0.0';
      final latest = data['latest_version'] as String? ?? '1.0.0';
      final forceUpdate = data['force_update'] as bool? ?? false;
      final message = data['message'] as String? ?? 'Update available';
      final storeUrl = data['store_url'] as String? ?? '';

      final isBelowMinimum = _compare(current, minimum) < 0;
      final isBelowLatest = _compare(current, latest) < 0;

      return VersionCheckResult(
        forceUpdate: forceUpdate || isBelowMinimum,
        hasUpdate: isBelowLatest,
        message: message,
        storeUrl: storeUrl,
      );
    } catch (_) {
      return VersionCheckResult.noUpdate;
    }
  }

  static int _compare(String a, String b) {
    final ap = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final bp = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final av = i < ap.length ? ap[i] : 0;
      final bv = i < bp.length ? bp[i] : 0;
      if (av != bv) return av - bv;
    }
    return 0;
  }
}
