import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../models/manga.dart';
import '../models/chapter.dart';
import 'source_config_service.dart';

class KiryuuService {
  static String get baseUrl => SourceConfigService.kiryuuBaseUrl;
  static Map<String, String> get defaultHeaders => {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': '$baseUrl/',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      };

  /// 1. Mengambil komik populer dari Kiryuu
  static Future<List<Manga>> getPopularManga({int page = 1}) async {
    final pagePath = page > 1 ? 'page/$page/' : '';
    final url = Uri.parse('$baseUrl/manga/$pagePath?order=popular');
    return _parseMangaList(url, category: 'Populer');
  }

  /// 2. Mengambil komik update terbaru dari Kiryuu
  static Future<List<Manga>> getLatestUpdates({int page = 1}) async {
    final pagePath = page > 1 ? 'page/$page/' : '';
    final url = Uri.parse('$baseUrl/manga/$pagePath?order=update');
    return _parseMangaList(url, category: 'Terbaru');
  }

  /// 3. Mencari komik berdasarkan kata kunci di Kiryuu
  static Future<List<Manga>> searchManga(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return getPopularManga(page: page);
    final pagePath = page > 1 ? 'page/$page/' : '';
    final encodedQuery = Uri.encodeComponent(query.trim());
    final url = Uri.parse('$baseUrl/manga/$pagePath?search_term=$encodedQuery');
    return _parseMangaList(url, category: 'Pencarian');
  }

  /// Helper parser daftar komik dari HTML Kiryuu
  static Future<List<Manga>> _parseMangaList(Uri url, {required String category}) async {
    try {
      final response = await http.get(url, headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final document = html_parser.parse(response.body);
      final List<Manga> list = [];
      final Set<String> seenUrls = {};

      // Cari elemen link manga di kartu Kiryuu
      final links = document.querySelectorAll('a[href*="/manga/"]');

      for (final linkEl in links) {
        final href = linkEl.attributes['href'] ?? '';
        if (href.isEmpty || href == '$baseUrl/manga/' || href.contains('/manga/page/')) continue;
        if (!href.startsWith('http')) continue;

        // Ambil elemen img di dalam link atau di parent card
        final imgEl = linkEl.querySelector('img');
        if (imgEl == null) continue;

        final rawThumb = imgEl.attributes['src'] ?? imgEl.attributes['data-src'] ?? '';
        if (rawThumb.isEmpty || rawThumb.contains('.svg') || rawThumb.contains('.gif')) continue;

        // Ambil judul dari alt gambar, h1 terdekat, atau title link
        String title = imgEl.attributes['alt'] ?? '';
        if (title.isEmpty) {
          final parent = linkEl.parent;
          title = parent?.querySelector('h1')?.text.trim() ?? linkEl.attributes['title'] ?? '';
        }
        title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (title.isEmpty) continue;

        if (seenUrls.contains(href)) continue;
        seenUrls.add(href);

        list.add(
          Manga(
            id: DateTime.now().millisecondsSinceEpoch + list.length,
            sourceId: 'kiryuu',
            url: href,
            title: title,
            author: 'Kiryuu ID',
            description: 'Komik Bahasa Indonesia dari Kiryuu',
            genre: 'Manga / Manhwa',
            status: 'Ongoing',
            thumbnailUrl: rawThumb,
            category: category,
            unreadCount: 0,
          ),
        );
      }

      return list;
    } catch (_) {
      return [];
    }
  }

  /// 4. Mengambil detail komik dan daftar bab dari halaman Kiryuu
  static Future<Map<String, dynamic>> getMangaDetails(String mangaUrl) async {
    try {
      final response = await http.get(Uri.parse(mangaUrl), headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return {'chapters': <Chapter>[]};

      final document = html_parser.parse(response.body);

      // Sinopsis
      final ogDesc = document.querySelector('meta[property="og:description"]')?.attributes['content'] ?? '';
      final description = ogDesc.replaceAll(RegExp(r'\s+'), ' ').trim();

      // Cover
      final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'] ?? '';

      // Parsing Daftar Bab
      final List<Chapter> chapters = [];
      final chapterNodes = document.querySelectorAll('div#chapter-list div[data-chapter-number]');

      for (int i = 0; i < chapterNodes.length; i++) {
        final node = chapterNodes[i];
        final chNumStr = node.attributes['data-chapter-number'] ?? '';
        final chNumber = double.tryParse(chNumStr) ?? (chapterNodes.length - i).toDouble();

        final aTag = node.querySelector('a');
        if (aTag == null) continue;

        final chUrl = aTag.attributes['href'] ?? '';
        if (chUrl.isEmpty) continue;

        final chName = 'Bab $chNumStr';
        final timeEl = node.querySelector('time');
        final uploadDate = timeEl?.text.trim() ?? 'Terbaru';

        chapters.add(
          Chapter(
            id: i + 1,
            mangaId: 1,
            url: chUrl,
            name: chName,
            chapterNumber: chNumber,
            dateUpload: uploadDate,
          ),
        );
      }

      // Fallback jika div#chapter-list kosong: cari semua link yang memuat /chapter-
      if (chapters.isEmpty) {
        final fallbackLinks = document.querySelectorAll('a[href*="/chapter-"]');
        final Set<String> seenChUrls = {};
        for (int i = 0; i < fallbackLinks.length; i++) {
          final a = fallbackLinks[i];
          final href = a.attributes['href'] ?? '';
          if (href.isEmpty || seenChUrls.contains(href)) continue;
          seenChUrls.add(href);

          final rawText = a.text.trim();
          final numMatch = RegExp(r'(\d+(\.\d+)?)').firstMatch(rawText);
          final chNum = numMatch != null ? double.tryParse(numMatch.group(1)!) ?? (i + 1).toDouble() : (i + 1).toDouble();

          chapters.add(
            Chapter(
              id: i + 1,
              mangaId: 1,
              url: href,
              name: rawText.isNotEmpty ? rawText : 'Bab $chNum',
              chapterNumber: chNum,
              dateUpload: 'Terbaru',
            ),
          );
        }
      }

      return {
        'description': description,
        'thumbnailUrl': ogImage,
        'chapters': chapters,
      };
    } catch (_) {
      return {'chapters': <Chapter>[]};
    }
  }

  /// 5. Mengambil lembaran gambar komik dari halaman bab Kiryuu
  static Future<List<String>> getChapterPages(String chapterUrl) async {
    try {
      final response = await http.get(Uri.parse(chapterUrl), headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final document = html_parser.parse(response.body);
      final List<String> pages = [];
      final Set<String> seenPages = {};

      final imgElements = document.querySelectorAll('img');

      for (final img in imgElements) {
        final src = img.attributes['src'] ?? img.attributes['data-src'] ?? '';
        if (src.isEmpty) continue;

        // Filter iklan, gif, tracker
        if (src.endsWith('.gif') ||
            src.contains('googleusercontent') ||
            src.contains('banner') ||
            src.contains('iklan') ||
            src.contains('logo') ||
            src.contains('svg')) {
          continue;
        }

        // Gambar lembaran komik Kiryuu ada di cdn.kiryuu atau uploads
        if (src.contains('cdn.kiryuu') || src.contains('wp-content/uploads') || src.endsWith('.jpg') || src.endsWith('.webp') || src.endsWith('.png')) {
          if (!seenPages.contains(src)) {
            seenPages.add(src);
            pages.add(src);
          }
        }
      }

      return pages;
    } catch (_) {
      return [];
    }
  }
}
