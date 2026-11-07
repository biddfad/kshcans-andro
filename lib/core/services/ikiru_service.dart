import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../models/manga.dart';
import '../models/chapter.dart';
import 'source_config_service.dart';

class IkiruService {
  static String get baseUrl => SourceConfigService.ikiruBaseUrl;

  static Map<String, String> get defaultHeaders => {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': '$baseUrl/',
        'Accept': 'application/json, text/html, */*',
      };

  /// 1. Mengambil komik populer dari Ikiru
  static Future<List<Manga>> getPopularManga({int page = 1}) async {
    final url = Uri.parse('$baseUrl/api/public/library/search?sortBy=popular&sort=desc&page=$page');
    return _parseSearchApi(url, category: 'Populer');
  }

  /// 2. Mengambil komik update terbaru dari Ikiru
  static Future<List<Manga>> getLatestUpdates({int page = 1}) async {
    final url = Uri.parse('$baseUrl/api/public/library/search?sortBy=updated&sort=desc&page=$page');
    return _parseSearchApi(url, category: 'Terbaru');
  }

  /// 3. Mencari komik berdasarkan kata kunci di Ikiru
  static Future<List<Manga>> searchManga(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return getPopularManga(page: page);
    final encodedQuery = Uri.encodeComponent(query.trim());
    final url = Uri.parse('$baseUrl/api/public/library/search?query=$encodedQuery&page=$page');
    return _parseSearchApi(url, category: 'Pencarian');
  }

  /// Helper pemroses respon REST API katalog Ikiru
  static Future<List<Manga>> _parseSearchApi(Uri url, {required String category}) async {
    try {
      final response = await http.get(url, headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || data['success'] != true) return [];

      final mangas = data['data']?['mangas'] as List?;
      if (mangas == null || mangas.isEmpty) return [];

      final List<Manga> list = [];
      for (final item in mangas) {
        if (item is! Map<String, dynamic>) continue;

        final title = item['title']?.toString().trim() ?? '';
        final slug = item['slug']?.toString().trim() ?? '';
        if (title.isEmpty || slug.isEmpty) continue;

        final thumbnailUrl = item['featuredImage']?.toString().trim() ?? '';
        final mangaUrl = '$baseUrl/manga/$slug';

        String genre = 'Manga / Manhwa';
        final genresList = item['metadata']?['genre'] as List?;
        if (genresList != null && genresList.isNotEmpty) {
          genre = genresList.map((g) => g['name']?.toString() ?? '').where((g) => g.isNotEmpty).join(', ');
        }

        list.add(
          Manga(
            id: DateTime.now().millisecondsSinceEpoch + list.length,
            sourceId: 'ikiru',
            url: mangaUrl,
            title: title,
            author: 'Ikiru',
            description: item['description'] != null ? _cleanHtml(item['description'].toString()) : 'Komik Bahasa Indonesia dari Ikiru',
            genre: genre.isNotEmpty ? genre : 'Manga / Manhwa',
            status: 'Ongoing',
            thumbnailUrl: thumbnailUrl,
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

  /// 4. Mengambil detail komik dan bab dari REST API Ikiru
  static Future<Map<String, dynamic>> getMangaDetails(String mangaUrl) async {
    try {
      String slug = mangaUrl.trim();
      if (slug.contains('/manga/')) {
        slug = slug.split('/manga/').last.replaceAll('/', '').trim();
      } else {
        slug = slug.replaceAll(baseUrl, '').replaceAll('/', '').trim();
      }

      final apiUrl = Uri.parse('$baseUrl/api/public/manga/$slug');
      final response = await http.get(apiUrl, headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return {'chapters': <Chapter>[]};

      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic> || json['success'] != true) return {'chapters': <Chapter>[]};

      final data = json['data'] as Map<String, dynamic>? ?? {};

      // Deskripsi & Cover
      final description = _cleanHtml(data['description']?.toString() ?? '');
      final thumbnailUrl = data['featuredImage']?.toString() ?? '';
      final status = data['status']?.toString().toUpperCase() == 'COMPLETED' ? 'Tamat' : 'Ongoing';

      String author = 'Ikiru';
      final authorList = data['metadata']?['author'] as List?;
      if (authorList != null && authorList.isNotEmpty) {
        author = authorList.map((a) => a['name']?.toString() ?? '').where((s) => s.isNotEmpty).join(', ');
      }

      String genre = 'Manhwa';
      final genreList = data['metadata']?['genre'] as List?;
      if (genreList != null && genreList.isNotEmpty) {
        genre = genreList.map((g) => g['name']?.toString() ?? '').where((s) => s.isNotEmpty).join(', ');
      }

      // Parsing Daftar Bab
      final List<Chapter> chapters = [];
      final rawChapters = data['chapters']?['chapters'] as List?;
      if (rawChapters != null) {
        for (int i = 0; i < rawChapters.length; i++) {
          final item = rawChapters[i];
          if (item is! Map<String, dynamic>) continue;

          final number = (item['number'] as num?)?.toDouble() ?? (rawChapters.length - i).toDouble();
          final numberFormatted = number % 1 == 0 ? number.toInt().toString() : number.toString();
          final chapterUrl = '$baseUrl/manga/$slug/chapter-$numberFormatted';

          String chapterTitle = item['title']?.toString().trim() ?? '';
          if (chapterTitle.isEmpty) {
            chapterTitle = 'Chapter $numberFormatted';
          }

          chapters.add(
            Chapter(
              id: i + 1,
              mangaId: 1,
              url: chapterUrl,
              name: chapterTitle,
              chapterNumber: number,
              dateUpload: item['createdAt']?.toString().split('T').first ?? 'Terbaru',
            ),
          );
        }
      }

      return {
        'description': description.isNotEmpty ? description : 'Komik Bahasa Indonesia dari Ikiru',
        'thumbnailUrl': thumbnailUrl,
        'status': status,
        'author': author,
        'genre': genre,
        'chapters': chapters,
      };
    } catch (_) {
      return {'chapters': <Chapter>[]};
    }
  }

  /// 5. Mengambil lembaran gambar komik dari halaman bab Ikiru (SSR HTML)
  static Future<List<String>> getChapterPages(String chapterUrl) async {
    try {
      final response = await http.get(Uri.parse(chapterUrl), headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final List<String> pages = [];
      final Set<String> seenPages = {};

      // Ekstraksi langsung URL gambar cdn.ikiru.id/t/
      final regex = RegExp(r'https?://cdn\.ikiru\.id/t/[^\s"''<>]+');
      final matches = regex.allMatches(response.body);

      for (final match in matches) {
        var imgUrl = match.group(0) ?? '';
        imgUrl = imgUrl.replaceAll('&amp;', '&');

        if (imgUrl.isNotEmpty && !seenPages.contains(imgUrl)) {
          seenPages.add(imgUrl);
          pages.add(imgUrl);
        }
      }

      // Fallback jika regex tidak menangkap: coba parsing DOM img tag
      if (pages.isEmpty) {
        final document = html_parser.parse(response.body);
        final imgElements = document.querySelectorAll('img[src*="cdn.ikiru.id"]');
        for (final img in imgElements) {
          final src = (img.attributes['src'] ?? '').replaceAll('&amp;', '&');
          if (src.contains('/t/') && !seenPages.contains(src)) {
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

  /// Helper untuk membersihkan tag HTML dari teks deskripsi
  static String _cleanHtml(String htmlString) {
    if (htmlString.isEmpty) return '';
    final document = html_parser.parse(htmlString);
    return document.body?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  }
}
