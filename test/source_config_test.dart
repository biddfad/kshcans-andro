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

      // Unmodified sources should still return safe defaults!
      expect(SourceConfigService.bacakomikBaseUrl, 'https://bacakomik.my');
      expect(SourceConfigService.komikuBaseUrl, 'https://komiku.org');
    });

    test('getImageHeaders properly resolves dynamic referer and user-agent', () {
      final shinigamiHeaders = SourceConfigService.getImageHeaders('shinigami', 'https://assets.shngm.id/1.jpg');
      expect(shinigamiHeaders['Referer'], 'https://shinigami.asia/');
      expect(shinigamiHeaders['User-Agent'], isNotEmpty);

      final komikuHeaders = SourceConfigService.getImageHeaders('komiku', 'https://img.komiku.org/2.jpg');
      expect(komikuHeaders['Referer'], 'https://komiku.org/');

      final doujinHeaders = SourceConfigService.getImageHeaders('doujindesu', 'https://desu.xxx/3.jpg');
      expect(doujinHeaders['Referer'], 'https://doujin.desu.xxx/');
    });
  });
}
