import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../database/db_helper.dart';

class SourceConfigService {
  static const String configUrl =
      'https://raw.githubusercontent.com/biddfad/kshcans-andro/main/sources_config.json';
  static const String dbSettingKey = 'remote_sources_config';

  // Fallback domain default jika perangkat offline
  static const String _defaultShinigamiApi = 'https://api.shinigami.io';
  static const String _defaultShinigamiAssets = 'https://cdn.shinigami.gg';
  static const String _defaultShinigamiReferer = 'https://s1.shinigami.mx/';
  static const String _defaultKomikindoBase = 'https://komikindo.ch';
  static const String _defaultKiryuuBase = 'https://v7.kiryuu.to';
  static const String _defaultBacakomikBase = 'https://bacakomik.my';
  static const String _defaultKomikuBase = 'https://komiku.org';
  static const String _defaultDoujindesuBase = 'https://doujin.desu.xxx';
  static const String _defaultMangadexBase = 'https://api.mangadex.org';
  static const String _defaultIkiruBase = 'https://09.ikiru.wtf';
  static const String _defaultLuvyaaBase = 'https://v5.luvyaa.co';

  static Map<String, dynamic> _config = {};

  /// Inisialisasi awal saat aplikasi dibuka: memuat domain dari SQLite
  static Future<void> initialize() async {
    try {
      final cachedJson = await DBHelper.instance.getSetting(dbSettingKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final data = jsonDecode(cachedJson);
        if (data is Map<String, dynamic> && data.containsKey('sources')) {
          _config = data;
          debugPrint('SourceConfigService: Berhasil memuat domain dari cache lokal.');
        }
      }
    } catch (e) {
      debugPrint('SourceConfigService: Gagal memuat cache domain: $e');
    }
  }

  /// Sinkronisasi hening di latar belakang untuk mengecek perubahan domain dari GitHub
  static Future<bool> syncRemoteConfig() async {
    try {
      final response = await http.get(Uri.parse(configUrl), headers: {
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('sources')) {
          _config = data;
          await DBHelper.instance.saveSetting(dbSettingKey, response.body);
          debugPrint('SourceConfigService: Berhasil sinkronisasi domain terbaru dari remote.');
          return true;
        }
      }
    } catch (e) {
      debugPrint('SourceConfigService: Sinkronisasi remote dilewati (offline/fallback): $e');
    }
    return false;
  }

  /// Mengatur konfigurasi secara manual (digunakan untuk unit test)
  @visibleForTesting
  static void setConfigForTesting(Map<String, dynamic> testConfig) {
    _config = testConfig;
  }

  /// Reset konfigurasi ke kondisi awal
  @visibleForTesting
  static void resetForTesting() {
    _config = {};
  }

  // --- Dynamic Getters untuk Seluruh Sumber ---

  static String get shinigamiApiUrl {
    return _config['sources']?['shinigami']?['apiUrl']?.toString() ?? _defaultShinigamiApi;
  }

  static String get shinigamiAssetsUrl {
    return _config['sources']?['shinigami']?['assetsUrl']?.toString() ?? _defaultShinigamiAssets;
  }

  static String get shinigamiReferer {
    return _config['sources']?['shinigami']?['referer']?.toString() ?? _defaultShinigamiReferer;
  }

  static String get komikindoBaseUrl {
    return _config['sources']?['komikindo']?['baseUrl']?.toString() ?? _defaultKomikindoBase;
  }

  static String get kiryuuBaseUrl {
    return _config['sources']?['kiryuu']?['baseUrl']?.toString() ?? _defaultKiryuuBase;
  }

  static String get bacakomikBaseUrl {
    return _config['sources']?['bacakomik']?['baseUrl']?.toString() ?? _defaultBacakomikBase;
  }

  static String get komikuBaseUrl {
    return _config['sources']?['komiku']?['baseUrl']?.toString() ?? _defaultKomikuBase;
  }

  static String get doujindesuBaseUrl {
    return _config['sources']?['doujindesu']?['baseUrl']?.toString() ?? _defaultDoujindesuBase;
  }

  static String get mangadexBaseUrl {
    return _config['sources']?['mangadex']?['baseUrl']?.toString() ?? _defaultMangadexBase;
  }

  static String get ikiruBaseUrl {
    return _config['sources']?['ikiru']?['baseUrl']?.toString() ?? _defaultIkiruBase;
  }

  static String get luvyaaBaseUrl {
    return _config['sources']?['luvyaa']?['baseUrl']?.toString() ?? _defaultLuvyaaBase;
  }

  /// Utilitas sentral penentuan header referer gambar untuk CachedNetworkImage
  static Map<String, String> getImageHeaders(String sourceId, String url) {
    if (sourceId == 'shinigami' || url.contains('shngm') || url.contains('shinigami')) {
      return {
        'Referer': shinigamiReferer,
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
    } else if (sourceId == 'komiku' || url.contains('komiku')) {
      return {
        'Referer': '$komikuBaseUrl/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      };
    } else if (sourceId == 'komikindo' || url.contains('komikindo')) {
      return {
        'Referer': '$komikindoBaseUrl/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      };
    } else if (sourceId == 'doujindesu' || url.contains('desu.')) {
      return {
        'Referer': '$doujindesuBaseUrl/',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
      };
    } else if (sourceId == 'kiryuu' || url.contains('kiryuu')) {
      return {
        'Referer': '$kiryuuBaseUrl/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
    } else if (sourceId == 'bacakomik' || url.contains('bacakomik')) {
      return {
        'Referer': '$bacakomikBaseUrl/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
    } else if (sourceId == 'mangadex' || url.contains('mangadex')) {
      return {
        'Referer': 'https://mangadex.org/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
    } else if (sourceId == 'ikiru' || url.contains('ikiru.id') || url.contains('ikiru.wtf')) {
      return {
        'Referer': '$ikiruBaseUrl/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
    } else if (sourceId == 'luvyaa' || url.contains('luvyaa') || url.contains('cdn-nyaa.link')) {
      return {
        'Referer': '$luvyaaBaseUrl/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
    }
    return const {};
  }
}
