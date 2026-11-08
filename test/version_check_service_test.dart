import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ggcc_mobile/src/services/version_check_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VersionCheckService - Version String Sanitization', () {
    test('cleanVersion strips "v" or "V" prefix', () {
      expect(VersionCheckService.cleanVersion('v1.0.1'), '1.0.1');
      expect(VersionCheckService.cleanVersion('V2.3.4'), '2.3.4');
    });

    test('cleanVersion strips build numbers (+...)', () {
      expect(VersionCheckService.cleanVersion('1.0.1+8'), '1.0.1');
      expect(VersionCheckService.cleanVersion('2.0.0+105'), '2.0.0');
    });

    test('cleanVersion strips whitespace and pre-release metadata', () {
      expect(VersionCheckService.cleanVersion('  1.0.5  '), '1.0.5');
      expect(VersionCheckService.cleanVersion('1.2.0-beta.1'), '1.2.0');
    });

    test('cleanVersion handles empty or invalid strings safely', () {
      expect(VersionCheckService.cleanVersion(''), '0');
      expect(VersionCheckService.cleanVersion('   '), '0');
    });
  });

  group('VersionCheckService - Version Comparison', () {
    test('older version is less than newer version', () {
      expect(VersionCheckService.compareVersions('1.0.0', '1.0.1') < 0, isTrue);
      expect(VersionCheckService.compareVersions('1.0.0', '1.1.0') < 0, isTrue);
      expect(VersionCheckService.compareVersions('1.9.9', '2.0.0') < 0, isTrue);
    });

    test('same versions are equal', () {
      expect(VersionCheckService.compareVersions('1.0.1', '1.0.1'), 0);
      expect(VersionCheckService.compareVersions('v1.0.1', '1.0.1'), 0);
      expect(VersionCheckService.compareVersions('1.0.1+8', '1.0.1'), 0);
      expect(VersionCheckService.compareVersions('1.0', '1.0.0'), 0);
      expect(VersionCheckService.compareVersions('1.0.0.0', '1.0'), 0);
    });

    test('newer version is greater than older version', () {
      expect(VersionCheckService.compareVersions('1.0.2', '1.0.1') > 0, isTrue);
      expect(VersionCheckService.compareVersions('2.0.0', '1.9.9') > 0, isTrue);
      expect(VersionCheckService.compareVersions('1.10.0', '1.2.0') > 0, isTrue);
    });
  });

  group('VersionCheckService - SharedPreferences Dismissal', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('marks version as dismissed and checks correctly', () async {
      expect(await VersionCheckService.isVersionDismissed('1.0.1'), isFalse);

      await VersionCheckService.markVersionDismissed('1.0.1');
      expect(await VersionCheckService.isVersionDismissed('1.0.1'), isTrue);

      // A newer version (1.0.2) should NOT be considered dismissed
      expect(await VersionCheckService.isVersionDismissed('1.0.2'), isFalse);

      // Clearing should reset dismissal
      await VersionCheckService.clearDismissedVersion();
      expect(await VersionCheckService.isVersionDismissed('1.0.1'), isFalse);
    });
  });

  group('AppUpdateInfo Model', () {
    test('parses json with numeric and boolean is_force properly', () {
      final json1 = {
        'update_available': true,
        'latest_version': '1.0.1',
        'is_force': 0,
        'update_url': 'https://play.google.com/store/apps/details?id=in.org.ggcc.mobile',
        'release_notes': 'Bug fixes and performance improvements.',
      };
      final info1 = AppUpdateInfo.fromJson(json1, installedVersion: '1.0.0');
      expect(info1.updateAvailable, isTrue);
      expect(info1.latestVersion, '1.0.1');
      expect(info1.isForce, isFalse);

      final json2 = {
        'update_available': true,
        'latest_version': '1.0.2',
        'is_force': 1,
        'update_url': 'https://play.google.com/store/apps/details?id=in.org.ggcc.mobile',
        'release_notes': '',
      };
      final info2 = AppUpdateInfo.fromJson(json2, installedVersion: '1.0.1');
      expect(info2.isForce, isTrue);
    });
  });
}

