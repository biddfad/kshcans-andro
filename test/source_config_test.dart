import 'package:flutter_test/flutter_test.dart';
import 'package:aplikasibacakomik/core/services/source_config_service.dart';

void main() {
  group('SourceConfigService Tests', () {
    setUp(() {
      SourceConfigService.resetForTesting();
    });

    tearDown(() {
      SourceConfigService.resetForTesting();
    });

    test('Returns default fallback domains when unconfigured', () {
      expect(SourceConfigService.shinigamiApiUrl, 'https://api.shngm.io');
      expect(SourceConfigService.shinigamiAssetsUrl, 'https://assets.shngm.id');
      expect(SourceConfigService.shinigamiReferer, 'https://shinigami.asia/');
      expect(SourceConfigService.komikindoBaseUrl, 'https://komikindo.ch');
      expect(SourceConfigService.kiryuuBaseUrl, 'https://v7.kiryuu.to');
      expect(SourceConfigService.bacakomikBaseUrl, 'https://bacakomik.my');
      expect(SourceConfigService.komikuBaseUrl, 'https://komiku.org');
      expect(SourceConfigService.doujindesuBaseUrl, 'https://doujin.desu.xxx');
      expect(SourceConfigService.mangadexBaseUrl, 'https://api.mangadex.org');
      expect(SourceConfigService.ikiruBaseUrl, 'https://09.ikiru.wtf');
      expect(SourceConfigService.luvyaaBaseUrl, 'https://v5.luvyaa.co');
    });

    test('Dynamic override updates domain getters instantly', () {
      final mockRemoteConfig = {
        'version': 2,
        'sources': {
          'shinigami': {
            'apiUrl': 'https://api.shinigami.me',
            'assetsUrl': 'https://cdn.shinigami.me',
            'referer': 'https://shinigami.me/',
          },
          'komikindo': {
            'baseUrl': 'https://komikindo.tv',
          },
          'kiryuu': {
            'baseUrl': 'https://kiryuu.id',
          },
          'ikiru': {
            'baseUrl': 'https://10.ikiru.wtf',
          },
          'luvyaa': {
            'baseUrl': 'https://v6.luvyaa.co',
          },
        }
      };

      SourceConfigService.setConfigForTesting(mockRemoteConfig);

      // Shinigami domain should immediately update to new domain!
      expect(SourceConfigService.shinigamiApiUrl, 'https://api.shinigami.me');
      expect(SourceConfigService.shinigamiAssetsUrl, 'https://cdn.shinigami.me');
      expect(SourceConfigService.shinigamiReferer, 'https://shinigami.me/');

      // Komikindo & Kiryuu domain should also update!
      expect(SourceConfigService.komikindoBaseUrl, 'https://komikindo.tv');
      expect(SourceConfigService.kiryuuBaseUrl, 'https://kiryuu.id');

      // Ikiru & Luvyaa domain should also update instantly!
      expect(SourceConfigService.ikiruBaseUrl, 'https://10.ikiru.wtf');
      expect(SourceConfigService.luvyaaBaseUrl, 'https://v6.luvyaa.co');

      // Unmodified sources should still return safe defaults!
      expect(SourceConfigService.bacakomikBaseUrl, 'https://bacakomik.my');
      expect(SourceConfigService.komikuBaseUrl, 'https://komiku.org');
    });

    test('getImageHeaders properly resolves dynamic referer and user-agent', () {
      // Shinigami
      final shiniHeaders = SourceConfigService.getImageHeaders('shinigami', 'https://assets.shngm.id/cover.jpg');
      expect(shiniHeaders['Referer'], SourceConfigService.shinigamiReferer);
      expect(shiniHeaders.containsKey('User-Agent'), true);

      // Komiku
      final komikuHeaders = SourceConfigService.getImageHeaders('komiku', 'https://komiku.org/img.jpg');
      expect(komikuHeaders['Referer'], '${SourceConfigService.komikuBaseUrl}/');

      // Kiryuu
      final kiryuuHeaders = SourceConfigService.getImageHeaders('kiryuu', 'https://v7.kiryuu.to/img.jpg');
      expect(kiryuuHeaders['Referer'], '${SourceConfigService.kiryuuBaseUrl}/');

      // Ikiru
      final ikiruHeaders = SourceConfigService.getImageHeaders('ikiru', 'https://cdn.ikiru.id/t/cover.jpg');
      expect(ikiruHeaders['Referer'], '${SourceConfigService.ikiruBaseUrl}/');

      // Luvyaa
      final luvyaaHeaders = SourceConfigService.getImageHeaders('luvyaa', 'https://img2.cdn-nyaa.link/cover.jpg');
      expect(luvyaaHeaders['Referer'], '${SourceConfigService.luvyaaBaseUrl}/');
    });
  });
}
