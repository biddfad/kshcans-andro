import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:aplikasibacakomik/core/services/app_update_service.dart';

void main() {
  group('AppUpdateService Logic Tests', () {
    test('Version comparison logic correctly identifies newer semver', () {
      expect(AppUpdateService.isNewerVersion('1.0.3', 0), isTrue);
      expect(AppUpdateService.isNewerVersion('1.1.0', 0), isTrue);
      expect(AppUpdateService.isNewerVersion('2.0.0', 0), isTrue);
      expect(AppUpdateService.isNewerVersion('1.0.2', 2006), isTrue);

      expect(AppUpdateService.isNewerVersion('1.0.2', 2005), isFalse);
      expect(AppUpdateService.isNewerVersion('1.0.2', 0), isFalse);
      expect(AppUpdateService.isNewerVersion('1.0.1', 0), isFalse);
      expect(AppUpdateService.isNewerVersion('0.9.9', 0), isFalse);
    });

    test('AppUpdateInfo correctly parses from standard version manifest JSON', () {
      final jsonStr = '''
      {
        "version": "1.0.3",
        "versionCode": 2006,
        "releaseDate": "2026-11-01",
        "title": "KsHcans v1.0.3",
        "changelog": "- Fitur baru\\n- Peningkatan performa",
        "downloadUrl": "https://example.com/KsHcans.apk",
        "browserUrl": "https://example.com"
      }
      ''';

      final data = jsonDecode(jsonStr);
      final info = AppUpdateInfo.fromJson(data);

      expect(info.latestVersion, '1.0.3');
      expect(info.latestBuildNumber, 2006);
      expect(info.releaseTitle, 'KsHcans v1.0.3');
      expect(info.downloadUrl, 'https://example.com/KsHcans.apk');
      expect(info.changelog, contains('Fitur baru'));
    });

    test('AppUpdateInfo correctly parses from GitHub release API response', () {
      final jsonStr = '''
      {
        "tag_name": "v1.0.4",
        "name": "KsHcans Flagship v1.0.4",
        "body": "Catatan rilis dari GitHub",
        "published_at": "2026-11-01T12:00:00Z",
        "assets": [
          {
            "name": "KsHcans-arm64-v8a.apk",
            "browser_download_url": "https://github.com/biddfad/kshcans-andro/releases/download/v1.0.4/KsHcans.apk"
          }
        ]
      }
      ''';

      final data = jsonDecode(jsonStr);
      final info = AppUpdateInfo.fromGitHubRelease(data);

      expect(info.latestVersion, '1.0.4');
      expect(info.releaseTitle, 'KsHcans Flagship v1.0.4');
      expect(info.changelog, 'Catatan rilis dari GitHub');
      expect(info.downloadUrl, contains('KsHcans.apk'));
      expect(info.releaseDate, '2026-11-01');
    });
  });
}
