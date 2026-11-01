import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/manga.dart';
import '../models/chapter.dart';
import 'source_config_service.dart';

class MangaDexService {
  static String get baseUrl => SourceConfigService.mangadexBaseUrl;
  static const String coverBaseUrl = 'https://uploads.mangadex.org/covers';

  static const Map<String, String> defaultHeaders = {
    'User-Agent': 'KsHcans/1.0.0',
    'Accept': 'application/json',
  };

  /// 1. Mengambil komik terpopuler di MangaDex
  static Future<List<Manga>> getPopularManga({int page = 1}) async {
    final offset = (page - 1) * 20;
    final url = Uri.parse('$baseUrl/manga?limit=20&offset=$offset&order[followedCount]=desc&includes[]=cover_art&contentRating[]=safe&contentRating[]=suggestive');
    return _parseMangaResponse(url, category: 'Populer');
  }

  /// 2. Mengambil komik yang baru saja di-upload / update bab baru di MangaDex
  static Future<List<Manga>> getLatestUpdates({int page = 1}) async {
    final offset = (page - 1) * 20;
    final url = Uri.parse('$baseUrl/manga?limit=20&offset=$offset&order[latestUploadedChapter]=desc&includes[]=cover_art&contentRating[]=safe&contentRating[]=suggestive');
    return _parseMangaResponse(url, category: 'Terbaru');
  }

  /// 3. Pencarian komik di MangaDex
  static Future<List<Manga>> searchManga(String query, {int page = 1}) async {
    final offset = (page - 1) * 20;
    final url = Uri.parse('$baseUrl/manga?limit=20&offset=$offset&title=${Uri.encodeComponent(query)}&includes[]=cover_art&contentRating[]=safe&contentRating[]=suggestive');
    return _parseMangaResponse(url, category: 'Pencarian');
  }

  static Future<List<Manga>> _parseMangaResponse(Uri url, {required String category}) async {
    try {
      final response = await http.get(url, headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final List mangaList = data['data'] ?? [];

      final List<Manga> result = [];
      for (final item in mangaList) {
        final id = item['id'] ?? '';
        final attributes = item['attributes'] ?? {};
        final titles = attributes['title'] ?? {};
        final title = titles['en'] ?? titles['ja-ro'] ?? (titles.values.isNotEmpty ? titles.values.first : 'Tanpa Judul');

        final descriptions = attributes['description'] ?? {};
        final description = descriptions['en'] ?? descriptions['id'] ?? (descriptions.values.isNotEmpty ? descriptions.values.first : '');

        // Cover Art
        String coverUrl = 'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=500&auto=format&fit=crop&q=60';
        final relationships = item['relationships'] as List? ?? [];
        for (final rel in relationships) {
          if (rel['type'] == 'cover_art' && rel['attributes'] != null) {
            final fileName = rel['attributes']['fileName'];
            if (fileName != null) {
              coverUrl = '$coverBaseUrl/$id/$fileName.256.jpg';
            }
          }
        }

        result.add(
          Manga(
            sourceId: 'mangadex',
            url: id,
            title: title.toString(),
            author: 'MangaDex Community',
            description: description.toString(),
            genre: 'Manga',
            status: attributes['status'] == 'completed' ? 'Selesai' : 'Ongoing',
            thumbnailUrl: coverUrl,
            inLibrary: false,
            category: category,
            unreadCount: 0,
          ),
        );
      }
      return result;
    } catch (e) {
      return [];
    }
  }

  /// 4. Mengambil daftar bab asli komik dari MangaDex
  static Future<List<Chapter>> getMangaChapters(String mangaId) async {
    try {
      var url = Uri.parse('$baseUrl/manga/$mangaId/feed?limit=100&order[chapter]=desc&translatedLanguage[]=id&translatedLanguage[]=en');
      var response = await http.get(url, headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      var data = jsonDecode(response.body);
      var chapterList = (data['data'] as List?) ?? [];

      // Fallback: Jika tidak ada bab terjemahan ID atau EN, ambil semua bahasa yang ada
      if (chapterList.isEmpty) {
        url = Uri.parse('$baseUrl/manga/$mangaId/feed?limit=100&order[chapter]=desc');
        response = await http.get(url, headers: defaultHeaders).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          data = jsonDecode(response.body);
          chapterList = (data['data'] as List?) ?? [];
        }
      }

      final List<Chapter> chapters = [];
      for (int i = 0; i < chapterList.length; i++) {
        final item = chapterList[i];
        final id = item['id'] ?? '';
        final attr = item['attributes'] ?? {};
        final externalUrl = attr['externalUrl'];
        final pages = (attr['pages'] as num?)?.toInt() ?? 0;

        // Lewati bab eksternal berbayar/lisensi resmi luar (Webnovel/MangaPlus) yang tidak di-host di server MangaDex
        if (externalUrl != null && externalUrl.toString().isNotEmpty) continue;
        if (pages <= 0) continue;

        final chNumber = attr['chapter'] ?? '${chapterList.length - i}';
        final title = attr['title'] != null && attr['title'].toString().isNotEmpty ? ': ${attr['title']}' : '';
        final lang = (attr['translatedLanguage'] ?? '').toString().toUpperCase();

        chapters.add(
          Chapter(
            id: i + 1,
            mangaId: 0,
            url: id,
            name: 'Bab $chNumber$title [$lang]',
            chapterNumber: double.tryParse(chNumber.toString()) ?? (i + 1.0),
            dateUpload: attr['publishAt']?.toString().split('T').first ?? '',
            isRead: false,
          ),
        );
      }
      return chapters;
    } catch (e) {
      return [];
    }
  }

  /// 5. Mengambil URL lembaran gambar komik asli dari bab MangaDex
  static Future<List<String>> getChapterPages(String chapterId) async {
    final url = Uri.parse('$baseUrl/at-home/server/$chapterId');
    try {
      final response = await http.get(url, headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final String host = data['baseUrl'] ?? 'https://uploads.mangadex.org';
      final chapter = data['chapter'] ?? {};
      final String hash = chapter['hash'] ?? '';
      final List files = chapter['data'] ?? [];
      final List dataSaver = chapter['dataSaver'] ?? [];

      final useDataSaver = files.isEmpty && dataSaver.isNotEmpty;
      final targetFiles = useDataSaver ? dataSaver : files;
      final folder = useDataSaver ? 'data-saver' : 'data';

      final List<String> pages = [];
      for (final f in targetFiles) {
        pages.add('$host/$folder/$hash/$f');
      }
      return pages;
    } catch (e) {
      return [];
    }
  }
}
