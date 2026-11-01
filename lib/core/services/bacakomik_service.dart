import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../models/manga.dart';
import '../models/chapter.dart';
import 'source_config_service.dart';

class BacaKomikService {
  static String get baseUrl => SourceConfigService.bacakomikBaseUrl;
  static Map<String, String> get defaultHeaders => {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Referer': '$baseUrl/',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      };

  /// Membersihkan URL thumbnail dari proxy WordPress Jetpack (i*.wp.com) yang error 404
  static String cleanThumbnailUrl(String rawUrl) {
    if (rawUrl.isEmpty) return '';
    String cleaned = rawUrl;
    cleaned = cleaned.replaceAll(RegExp(r'https?://i\d+\.wp\.com/'), 'https://');
    cleaned = cleaned.replaceAll(RegExp(r'\?resize=.*$'), '');
    return cleaned.trim();
  }

  /// 1. Mengambil komik populer (Popular Manga)
  static Future<List<Manga>> getPopularManga({int page = 1}) async {
    final pagePath = page > 1 ? 'page/$page/' : '';
    final url = Uri.parse('$baseUrl/daftar-komik/$pagePath?order=popular');
    return _parseMangaList(url, category: 'Populer');
  }

  /// 1b. Mengambil komik rilis terbaru / baru diupload (Latest Updates)
  static Future<List<Manga>> getLatestUpdates({int page = 1}) async {
    final pagePath = page > 1 ? 'page/$page/' : '';
    final url = Uri.parse('$baseUrl/daftar-komik/$pagePath?order=update');
    return _parseMangaList(url, category: 'Terbaru');
  }

  /// Helper parser daftar komik
  static Future<List<Manga>> _parseMangaList(Uri url, {required String category}) async {
    try {
      final response = await http.get(url, headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final document = html_parser.parse(response.body);
      final elements = document.querySelectorAll('div.animepost');

      final List<Manga> list = [];
      for (final el in elements) {
        final linkEl = el.querySelector('div.animposx > a');
        if (linkEl == null) continue;

        final rawUrl = linkEl.attributes['href'] ?? '';
        final title = (el.querySelector('.animposx .tt h4')?.text ??
                linkEl.attributes['title'] ??
                'Tanpa Judul')
            .replaceAll('Komik ', '')
            .trim();

        final imgEl = el.querySelector('div.limit img');
        final thumb = imgEl?.attributes['data-lazy-src'] ??
            imgEl?.attributes['data-src'] ??
            imgEl?.attributes['src'] ??
            '';

        list.add(
          Manga(
            sourceId: 'bacakomik',
            url: rawUrl,
            title: title,
            author: 'BacaKomik',
            description: '',
            genre: 'Manga / Manhwa',
            status: 'Ongoing',
            thumbnailUrl: cleanThumbnailUrl(thumb),
            inLibrary: false,
            category: category,
            unreadCount: 0,
          ),
        );
      }
      return list;
    } catch (e) {
      return [];
    }
  }

  /// 2. Pencarian Komik (Search Manga)
  static Future<List<Manga>> searchManga(String query, {int page = 1}) async {
    final url = Uri.parse('$baseUrl/daftar-komik/page/$page/?title=${Uri.encodeComponent(query)}');

    try {
      final response = await http.get(url, headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final document = html_parser.parse(response.body);
      final elements = document.querySelectorAll('div.animepost');

      final List<Manga> list = [];
      for (final el in elements) {
        final linkEl = el.querySelector('div.animposx > a');
        if (linkEl == null) continue;

        final rawUrl = linkEl.attributes['href'] ?? '';
        final title = (el.querySelector('.animposx .tt h4')?.text ??
                linkEl.attributes['title'] ??
                'Tanpa Judul')
            .replaceAll('Komik ', '')
            .trim();

        final imgEl = el.querySelector('div.limit img');
        final thumb = imgEl?.attributes['data-lazy-src'] ??
            imgEl?.attributes['data-src'] ??
            imgEl?.attributes['src'] ??
            '';

        list.add(
          Manga(
            sourceId: 'bacakomik',
            url: rawUrl,
            title: title,
            author: 'BacaKomik',
            description: '',
            genre: 'Manga / Manhwa',
            status: 'Ongoing',
            thumbnailUrl: cleanThumbnailUrl(thumb),
            inLibrary: false,
            category: 'Pencarian',
            unreadCount: 0,
          ),
        );
      }
      return list;
    } catch (e) {
      return [];
    }
  }

  /// 3. Mengambil Detail & Seluruh Bab Komik Asli
  static Future<Map<String, dynamic>> getMangaDetails(String mangaUrl) async {
    try {
      final response = await http.get(Uri.parse(mangaUrl), headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return {'description': '', 'chapters': <Chapter>[]};

      final document = html_parser.parse(response.body);

      // Sinopsis
      final pText = document.querySelector('.desc p')?.text ??
          document.querySelector('.sinopsis p')?.text ??
          document.querySelector('div[itemprop="description"] p')?.text ??
          '';

      // Parse Bab (Chapters)
      final chapterElements = document.querySelectorAll('#chapter_list li');
      final List<Chapter> chapters = [];

      for (int i = 0; i < chapterElements.length; i++) {
        final el = chapterElements[i];
        final link = el.querySelector('.lchx a');
        if (link == null) continue;

        final chUrl = link.attributes['href'] ?? '';
        final chName = link.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        final chDate = el.querySelector('.dt a')?.text.trim() ?? '';

        final numberMatch = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(chName);
        final chNumber = numberMatch != null ? double.tryParse(numberMatch.group(1)!) ?? (i + 1.0) : (i + 1.0);

        chapters.add(
          Chapter(
            id: i + 1,
            mangaId: 0,
            url: chUrl,
            name: chName,
            chapterNumber: chNumber,
            dateUpload: chDate,
            isRead: false,
          ),
        );
      }

      return {
        'description': pText.trim(),
        'chapters': chapters,
      };
    } catch (e) {
      return {'description': '', 'chapters': <Chapter>[]};
    }
  }

  /// 4. Mengambil Seluruh Lembaran Gambar Komik Asli dari Bab (Page List)
  static Future<List<String>> getChapterPages(String chapterUrl) async {
    try {
      final response = await http.get(Uri.parse(chapterUrl), headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final document = html_parser.parse(response.body);
      final List<String> imageUrls = [];

      // Sesuai logika parser Keiyoushi: cari div penampung gambar bab
      final imgElements = document.querySelectorAll('div#chimg-auh img, div.chimg-auh img, #reader-area img, .chapter-image img');

      for (final el in imgElements) {
        if (el.parent?.localName == 'noscript') continue;

        final onerror = el.attributes['onerror'] ?? el.attributes['onError'] ?? '';
        String finalUrl = '';

        if (onerror.contains("src='")) {
          final start = onerror.indexOf("src='") + 5;
          final end = onerror.indexOf("'", start);
          if (end > start) {
            finalUrl = onerror.substring(start, end);
          }
        }

        if (finalUrl.isEmpty) {
          finalUrl = el.attributes['data-lazy-src'] ??
              el.attributes['data-src'] ??
              el.attributes['src'] ??
              '';
        }

        if (finalUrl.isNotEmpty &&
            !finalUrl.startsWith('data:image/svg') &&
            !finalUrl.contains('loader') &&
            !finalUrl.contains('loading')) {
          if (!finalUrl.startsWith('http')) {
            finalUrl = 'https:$finalUrl';
          }
          imageUrls.add(finalUrl);
        }
      }

      return imageUrls;
    } catch (e) {
      return [];
    }
  }
}
