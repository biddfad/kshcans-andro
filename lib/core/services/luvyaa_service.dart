import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../models/manga.dart';
import '../models/chapter.dart';
import 'source_config_service.dart';

class LuvyaaService {
  static String get baseUrl => SourceConfigService.luvyaaBaseUrl;

  static Map<String, String> get defaultHeaders => {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': '$baseUrl/',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      };

  /// 1. Mengambil komik populer dari Mak Luvya
  static Future<List<Manga>> getPopularManga({int page = 1}) async {
    final url = Uri.parse('$baseUrl/manga/?order=popular&page=$page');
    return _parseMangaList(url, category: 'Populer');
  }

  /// 2. Mengambil komik update terbaru dari Mak Luvya
  static Future<List<Manga>> getLatestUpdates({int page = 1}) async {
    final url = Uri.parse('$baseUrl/manga/?order=update&page=$page');
    return _parseMangaList(url, category: 'Terbaru');
  }

  /// 3. Mencari komik berdasarkan kata kunci di Mak Luvya
  static Future<List<Manga>> searchManga(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return getPopularManga(page: page);
    final encodedQuery = Uri.encodeComponent(query.trim());
    final url = Uri.parse('$baseUrl/?s=$encodedQuery&page=$page');
    return _parseMangaList(url, category: 'Pencarian');
  }

  /// Helper parser daftar kartu komik MangaThemesia (div.bsx) pada Mak Luvya
  static Future<List<Manga>> _parseMangaList(Uri url, {required String category}) async {
    try {
      final response = await http.get(url, headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final document = html_parser.parse(response.body);
      final List<Manga> list = [];
      final Set<String> seenUrls = {};

      final cards = document.querySelectorAll('div.bsx');

      for (final card in cards) {
        final aTag = card.querySelector('a');
        if (aTag == null) continue;

        final href = aTag.attributes['href']?.trim() ?? '';
        if (href.isEmpty || seenUrls.contains(href)) continue;

        final title = aTag.attributes['title']?.trim() ?? card.querySelector('.tt')?.text.trim() ?? '';
        if (title.isEmpty) continue;

        final imgEl = card.querySelector('img');
        final rawThumb = imgEl?.attributes['src'] ?? imgEl?.attributes['data-src'] ?? '';
        if (rawThumb.isEmpty || rawThumb.contains('.svg') || rawThumb.contains('.gif')) continue;

        final typeSpan = card.querySelector('span.type')?.text.trim() ?? 'Manhwa';
        final statusSpan = card.querySelector('span.status')?.text.trim() ?? 'Ongoing';

        seenUrls.add(href);

        list.add(
          Manga(
            id: DateTime.now().millisecondsSinceEpoch + list.length,
            sourceId: 'luvyaa',
            url: href,
            title: title.replaceAll(RegExp(r'\s+'), ' ').trim(),
            author: 'Mak Luvya',
            description: 'Komik Bahasa Indonesia dari Mak Luvya ($typeSpan)',
            genre: typeSpan.isNotEmpty ? typeSpan : 'Manga / Manhwa',
            status: statusSpan.isNotEmpty ? statusSpan : 'Ongoing',
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

  /// 4. Mengambil detail komik dan daftar bab dari Mak Luvya
  static Future<Map<String, dynamic>> getMangaDetails(String mangaUrl) async {
    try {
      final response = await http.get(Uri.parse(mangaUrl), headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return {'chapters': <Chapter>[]};

      final document = html_parser.parse(response.body);

      // Sinopsis & Cover
      final ogDesc = document.querySelector('meta[property="og:description"]')?.attributes['content'] ??
          document.querySelector('div.entry-content')?.text.trim() ??
          '';
      final description = ogDesc.replaceAll(RegExp(r'\s+'), ' ').trim();

      final ogImage = document.querySelector('meta[property="og:image"]')?.attributes['content'] ??
          document.querySelector('div.thumb img')?.attributes['src'] ??
          '';

      // Status & Genre
      String status = 'Ongoing';
      for (final el in document.querySelectorAll('.tsinfo .imptdt')) {
        if (el.text.contains('Status')) {
          status = el.querySelector('i')?.text.trim() ?? el.text.replaceFirst('Status', '').trim();
          break;
        }
      }
      final genres = document.querySelectorAll('.mgen a').map((e) => e.text.trim()).where((g) => g.isNotEmpty).join(', ');

      // Deteksi URL bab yang terkunci VIP via JavaScript lockedUrls
      final Set<String> lockedUrls = {};
      final lockedRegex = RegExp(r'lockedUrls\s*=\s*\[(.*?)\]');
      final match = lockedRegex.firstMatch(response.body);
      if (match != null) {
        final raw = match.group(1) ?? '';
        for (final item in raw.split(',')) {
          final clean = item.trim().replaceAll("'", '').replaceAll('"', '').replaceAll(r'\/', '/');
          if (clean.isNotEmpty) lockedUrls.add(clean);
        }
      }

      // Parsing Daftar Bab dari elemen <li data-num="...">
      final List<Chapter> chapters = [];
      final chapterNodes = document.querySelectorAll('div#chapterlist ul li[data-num]');

      for (int i = 0; i < chapterNodes.length; i++) {
        final node = chapterNodes[i];
        final chNumStr = node.attributes['data-num'] ?? '';
        final chNumber = double.tryParse(chNumStr) ?? (chapterNodes.length - i).toDouble();

        final aTag = node.querySelector('a');
        if (aTag == null) continue;

        final chUrl = aTag.attributes['href']?.trim() ?? '';
        if (chUrl.isEmpty) continue;

        final isLocked = lockedUrls.any((locked) => chUrl.endsWith(locked) || chUrl.contains(locked));
        final rawTitle = aTag.querySelector('.chapternum')?.text.trim() ?? aTag.text.trim();
        final chName = isLocked ? '🔒 $rawTitle' : (rawTitle.isNotEmpty ? rawTitle : 'Chapter $chNumStr');

        final uploadDate = node.querySelector('.chapterdate')?.text.trim() ?? 'Terbaru';

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

      // Fallback jika div#chapterlist kosong: cari semua elemen a yang mengarah ke chapter
      if (chapters.isEmpty) {
        final fallbackLinks = document.querySelectorAll('a[href*="-chapter-"]');
        final Set<String> seenChUrls = {};
        for (int i = 0; i < fallbackLinks.length; i++) {
          final a = fallbackLinks[i];
          final href = a.attributes['href']?.trim() ?? '';
          if (href.isEmpty || seenChUrls.contains(href)) continue;
          seenChUrls.add(href);

          final rawText = a.text.trim();
          final numMatch = RegExp(r'(\d+(\.\d+)?)').firstMatch(rawText);
          final chNum = numMatch != null ? double.tryParse(numMatch.group(1)!) ?? (i + 1).toDouble() : (i + 1).toDouble();

          final isLocked = lockedUrls.any((locked) => href.endsWith(locked) || href.contains(locked));

          chapters.add(
            Chapter(
              id: i + 1,
              mangaId: 1,
              url: href,
              name: (isLocked ? '🔒 ' : '') + (rawText.isNotEmpty ? rawText : 'Chapter $chNum'),
              chapterNumber: chNum,
              dateUpload: 'Terbaru',
            ),
          );
        }
      }

      return {
        'description': description.isNotEmpty ? description : 'Komik Bahasa Indonesia dari Mak Luvya',
        'thumbnailUrl': ogImage,
        'status': status,
        'author': 'Mak Luvya',
        'genre': genres.isNotEmpty ? genres : 'Manhwa / Webtoon',
        'chapters': chapters,
      };
    } catch (_) {
      return {'chapters': <Chapter>[]};
    }
  }

  /// 5. Mengambil lembaran gambar komik dari halaman pembaca Mak Luvya
  static Future<List<String>> getChapterPages(String chapterUrl) async {
    try {
      final response = await http.get(Uri.parse(chapterUrl), headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final document = html_parser.parse(response.body);
      final List<String> pages = [];
      final Set<String> seenPages = {};

      // 1. Prioritas Utama: Ekstraksi dari JSON ts_reader.run (urutan gambar asli & bersih)
      final tsMatch = RegExp(r'ts_reader\.run\((\{.*?\})\);', dotAll: true).firstMatch(response.body);
      if (tsMatch != null) {
        final jsonStr = tsMatch.group(1);
        if (jsonStr != null) {
          try {
            final Map<String, dynamic> data = jsonDecode(jsonStr);
            final List sources = data['sources'] ?? [];
            for (final s in sources) {
              final List imgs = s['images'] ?? [];
              for (final img in imgs) {
                if (img is String && img.isNotEmpty && !seenPages.contains(img)) {
                  seenPages.add(img);
                  pages.add(img);
                }
              }
            }
          } catch (_) {}
        }
      }

      // 2. Standar MangaThemesia: div#readerarea img (jika ts_reader kosong)
      if (pages.isEmpty) {
        final readerArea = document.querySelector('div#readerarea');
        if (readerArea != null) {
          final imgElements = readerArea.querySelectorAll('img');
          for (final img in imgElements) {
            final src = img.attributes['src'] ?? img.attributes['data-src'] ?? '';
            if (src.isEmpty) continue;

            // Abaikan banner iklan dan icon
            if (src.endsWith('.gif') ||
                src.contains('banner') ||
                src.contains('iklan') ||
                src.contains('logo') ||
                src.contains('svg')) {
              continue;
            }

            if (!seenPages.contains(src)) {
              seenPages.add(src);
              pages.add(src);
            }
          }
        }
      }

      // Fallback regex jika readerarea menggunakan lazyload kustom
      if (pages.isEmpty) {
        final regex = RegExp(r'https?://[^\s"<>]+?\.(?:webp|jpg|jpeg|png)(?:\?[^\s"<>]+)?');
        final matches = regex.allMatches(response.body);
        for (final match in matches) {
          final src = match.group(0) ?? '';
          if (src.contains('cdn-nyaa.link') || src.contains('wp-content/uploads')) {
            if (!seenPages.contains(src)) {
              seenPages.add(src);
              pages.add(src);
            }
          }
        }
      }

      return pages;
    } catch (_) {
      return [];
    }
  }
}
