import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chapter.dart';
import '../models/manga.dart';

/// Service ekstraktor resmi DoujinDesu (sumber dewasa 18+ ekosistem Keiyoushi)
/// Mendukung dekripsi payload dinamis berkecepatan tinggi dengan bypass DNS.
class DoujinDesuService {
  static const String baseUrl = 'https://doujin.desu.xxx';
  static const String apiUrl = '$baseUrl/api';
  static const String appSecret = 'dfdf72051dbfdc7d76889ebd31324e74';
  static const String salt = 'doujindesu-scrapers-cannot-read-this-super-secret-salt-2026-v2';
  static const int hourMs = 3600000;
  static const int limit = 24;

  static const Map<String, String> defaultHeaders = {
    'x-app-secret': appSecret,
    'Referer': '$baseUrl/',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
  };

  // --- Algoritma Dekripsi Keiyoushi DoujinDesu ---

  static int _toSigned32(int x) {
    var y = x & 0xFFFFFFFF;
    if (y >= 0x80000000) {
      y -= 0x100000000;
    }
    return y;
  }

  static String _wH(int e) {
    final t = '${salt}_$e';
    int a = 0;
    for (int i = 0; i < t.length; i++) {
      final code = t.codeUnitAt(i);
      a = (a << 5) - a + code;
      a = _toSigned32(a);
    }
    int l = a != 0 ? a.abs() : 123456789;
    final buffer = StringBuffer();
    for (int i = 0; i < 32; i++) {
      l = (l * 1664525 + 1013904223) % 4294967296;
      buffer.writeCharCode(33 + (l % 93));
    }
    return buffer.toString();
  }

  static List<String> _lU() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final t = now ~/ hourMs;
    return [_wH(t), _wH(t - 1), _wH(t + 1)];
  }

  static String _yre(String encryptedHex, String key) {
    final bytes = <int>[];
    for (int i = 0; i < encryptedHex.length; i += 2) {
      final sub = encryptedHex.substring(i, i + 2);
      final val = int.tryParse(sub, radix: 16);
      if (val != null) bytes.add(val);
    }
    int d = 42;
    final keyLen = key.length;
    final buffer = StringBuffer();
    for (int idx = 0; idx < bytes.length; idx++) {
      final byteVal = bytes[idx];
      final keyChar = key.codeUnitAt(idx % keyLen);
      final k = byteVal ^ keyChar ^ (idx * 13) ^ d;
      buffer.writeCharCode(k & 0xFF);
      d = (d + byteVal) % 256;
    }
    return buffer.toString();
  }

  static String? _decrypt(String encryptedHex) {
    for (final key in _lU()) {
      try {
        final decoded = _yre(encryptedHex, key);
        return Uri.decodeComponent(decoded);
      } catch (_) {}
    }
    return null;
  }

  // --- Endpoint Layanan ---

  /// 1. Mengambil komik terpopuler di DoujinDesu
  static Future<List<Manga>> getPopularManga({int page = 1}) async {
    final offset = (page - 1) * limit;
    final url = Uri.parse('$apiUrl/manga?limit=$limit&offset=$offset&sort=rating');
    return _fetchMangaList(url);
  }

  /// 2. Mengambil komik rilis terbaru di DoujinDesu
  static Future<List<Manga>> getLatestUpdates({int page = 1}) async {
    final offset = (page - 1) * limit;
    final url = Uri.parse('$apiUrl/manga?limit=$limit&offset=$offset&sort=latest_chapter');
    return _fetchMangaList(url);
  }

  /// 3. Pencarian komik di DoujinDesu
  static Future<List<Manga>> searchManga(String query, {int page = 1}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return getPopularManga(page: page);
    final offset = (page - 1) * limit;
    final encoded = Uri.encodeComponent(cleanQuery);
    final url = Uri.parse('$apiUrl/manga?limit=$limit&offset=$offset&search=$encoded');
    return _fetchMangaList(url);
  }

  /// Helper untuk mengambil dan mendekripsi daftar komik
  static Future<List<Manga>> _fetchMangaList(Uri url) async {
    try {
      final response = await http.get(url, headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final rawJson = jsonDecode(response.body);
      final encrypted = rawJson['_enc_resp_'] as String?;
      if (encrypted == null) return [];

      final decrypted = _decrypt(encrypted);
      if (decrypted == null) return [];

      final parsed = jsonDecode(decrypted);
      if (parsed is! List) return [];

      final List<Manga> list = [];
      for (final item in parsed) {
        if (item is Map<String, dynamic>) {
          final slug = item['slug']?.toString() ?? '';
          if (slug.isEmpty) continue;

          var cover = item['cover_url']?.toString() ?? '';
          if (cover.startsWith('/')) {
            cover = '$baseUrl$cover';
          }

          final status = (item['status']?.toString() ?? 'Ongoing').toLowerCase();
          final formattedStatus = (status == 'completed' || status == 'finished') ? 'Selesai' : 'Ongoing';

          list.add(Manga(
            sourceId: 'doujindesu',
            url: '$baseUrl/manga/$slug',
            title: item['title']?.toString() ?? 'Tanpa Judul',
            author: item['author']?.toString() ?? 'DoujinDesu',
            description: item['description']?.toString() ?? '',
            genre: (item['type']?.toString() ?? 'Doujin 18+').toUpperCase(),
            status: formattedStatus,
            thumbnailUrl: cover,
          ));
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  /// 4. Mengambil detail komik beserta daftar seluruh babnya
  static Future<Map<String, dynamic>> getMangaDetails(String urlOrSlug) async {
    final slug = _extractSlug(urlOrSlug);
    final url = Uri.parse('$apiUrl/manga/$slug');

    try {
      final response = await http.get(url, headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        return {'description': '', 'status': 'Ongoing', 'genre': '18+', 'chapters': <Chapter>[]};
      }

      final rawJson = jsonDecode(response.body);
      final encrypted = rawJson['_enc_resp_'] as String?;
      if (encrypted == null) {
        return {'description': '', 'status': 'Ongoing', 'genre': '18+', 'chapters': <Chapter>[]};
      }

      final decrypted = _decrypt(encrypted);
      if (decrypted == null) {
        return {'description': '', 'status': 'Ongoing', 'genre': '18+', 'chapters': <Chapter>[]};
      }

      final item = jsonDecode(decrypted) as Map<String, dynamic>;
      final rawChapters = item['chapters'] as List? ?? [];

      final List<Chapter> chapters = [];
      for (final ch in rawChapters) {
        if (ch is Map<String, dynamic>) {
          final id = ch['id']?.toString() ?? '';
          final numVal = (ch['chapter_number'] as num?)?.toDouble() ?? 1.0;
          final numStr = numVal.toString().replaceAll(RegExp(r'\.0$'), '');
          final title = ch['title']?.toString();
          final chName = title != null && title.isNotEmpty ? 'Chapter $numStr: $title' : 'Chapter $numStr';
          final date = ch['created_at']?.toString() ?? '';

          chapters.add(Chapter(
            mangaId: 1,
            url: 'doujindesu:$id',
            name: chName,
            chapterNumber: numVal,
            dateUpload: date.length >= 10 ? date.substring(0, 10) : date,
          ));
        }
      }

      final status = (item['status']?.toString() ?? 'Ongoing').toLowerCase();
      final formattedStatus = (status == 'completed' || status == 'finished') ? 'Selesai' : 'Ongoing';

      return {
        'description': item['description']?.toString() ?? '',
        'status': formattedStatus,
        'genre': (item['type']?.toString() ?? 'Doujin 18+').toUpperCase(),
        'author': item['author']?.toString() ?? 'DoujinDesu',
        'chapters': chapters,
      };
    } catch (_) {
      return {'description': '', 'status': 'Ongoing', 'genre': '18+', 'chapters': <Chapter>[]};
    }
  }

  /// 5. Mengambil daftar URL gambar lembaran bab
  static Future<List<String>> getChapterPages(String chapterUrlOrId) async {
    final chapterId = chapterUrlOrId.replaceFirst('doujindesu:', '').trim();
    final url = Uri.parse('$apiUrl/chapters/$chapterId');

    try {
      final response = await http.get(url, headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final rawJson = jsonDecode(response.body);
      final encrypted = rawJson['_enc_resp_'] as String?;
      if (encrypted == null) return [];

      final decrypted = _decrypt(encrypted);
      if (decrypted == null) return [];

      final json = jsonDecode(decrypted) as Map<String, dynamic>;
      final rawUrls = json['content_urls'] as List? ?? [];

      final List<String> pages = [];
      for (final p in rawUrls) {
        var str = p.toString();
        if (str.contains('/uploads/') && !str.contains('/storage/uploads/')) {
          str = str.replaceFirst('/uploads/', '/storage/uploads/');
        } else if (str.contains('/upload/') && !str.contains('/storage/upload/')) {
          str = str.replaceFirst('/upload/', '/storage/upload/');
        }
        pages.add(str);
      }
      return pages;
    } catch (_) {
      return [];
    }
  }

  static String _extractSlug(String urlOrSlug) {
    var clean = urlOrSlug.trim();
    if (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    return clean.split('/').last;
  }
}
