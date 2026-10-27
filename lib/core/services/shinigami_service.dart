import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/manga.dart';
import '../models/chapter.dart';

class ShinigamiService {
  static const String apiUrl = 'https://api.shngm.io';
  static const Map<String, String> defaultHeaders = {
    'Accept': 'application/json',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'DNT': '1',
    'Referer': 'https://shinigami.asia/',
  };

  /// 1. Mengambil komik terpopuler di Shinigami
  static Future<List<Manga>> getPopularManga({int page = 1}) async {
    final url = Uri.parse('$apiUrl/v1/manga/list?page=$page&page_size=20&sort=popularity');
    return _parseMangaList(url, category: 'Populer');
  }

  /// 2. Mengambil komik rilis terbaru di Shinigami
  static Future<List<Manga>> getLatestUpdates({int page = 1}) async {
    final url = Uri.parse('$apiUrl/v1/manga/list?page=$page&page_size=20&sort=latest');
    return _parseMangaList(url, category: 'Terbaru');
  }

  /// 3. Pencarian komik di Shinigami
  static Future<List<Manga>> searchManga(String query, {int page = 1}) async {
    final url = Uri.parse('$apiUrl/v1/manga/list?page=$page&page_size=20&q=${Uri.encodeComponent(query)}');
    return _parseMangaList(url, category: 'Pencarian');
  }

  static Future<List<Manga>> _parseMangaList(Uri url, {required String category}) async {
    try {
      final response = await http.get(url, headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final List items = data['data'] ?? [];

      final List<Manga> result = [];
      for (final item in items) {
        final mangaId = item['manga_id'] ?? '';
        final title = item['title'] ?? 'Tanpa Judul';
        String thumb = (item['cover_portrait_url']?.toString().trim() ?? '');
        if (thumb.isEmpty) {
          thumb = (item['cover_image_url']?.toString().trim() ?? '');
        }
        if (thumb.startsWith('/')) {
          thumb = 'https://assets.shngm.id$thumb';
        }
        final desc = item['description'] ?? '';

        final genresList = item['taxonomy']?['Genre'] as List? ?? [];
        final genre = genresList.map((g) => g['name']).join(', ');

        result.add(
          Manga(
            sourceId: 'shinigami',
            url: mangaId,
            title: title.toString(),
            author: 'Shinigami ID',
            description: desc.toString(),
            genre: genre.isNotEmpty ? genre : 'Manhwa / Manga',
            status: item['status'] == 2 ? 'Selesai' : 'Ongoing',
            thumbnailUrl: thumb.toString(),
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

  /// 4. Mengambil seluruh bab komik asli dari Shinigami
  static Future<List<Chapter>> getMangaChapters(String mangaId) async {
    final url = Uri.parse('$apiUrl/v1/chapter/$mangaId/list?page_size=3000');
    try {
      final response = await http.get(url, headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final List chapterList = data['data'] ?? [];

      final List<Chapter> chapters = [];
      for (int i = 0; i < chapterList.length; i++) {
        final ch = chapterList[i];
        final chId = ch['chapter_id'] ?? '';
        final chNumber = ch['chapter_number'] ?? '${chapterList.length - i}';
        final chTitle = ch['chapter_title'] != null && ch['chapter_title'].toString().isNotEmpty
            ? ': ${ch['chapter_title']}'
            : '';
        final date = ch['release_date']?.toString().split('T').first ?? '';

        chapters.add(
          Chapter(
            id: i + 1,
            mangaId: 0,
            url: 'shinigami:$chId',
            name: 'Chapter $chNumber$chTitle',
            chapterNumber: double.tryParse(chNumber.toString()) ?? (i + 1.0),
            dateUpload: date,
            isRead: false,
          ),
        );
      }
      return chapters;
    } catch (e) {
      return [];
    }
  }

  /// 5. Mengambil URL lembaran gambar komik asli dari bab Shinigami
  static Future<List<String>> getChapterPages(String chapterId) async {
    final cleanId = chapterId.replaceAll('shinigami:', '');
    final url = Uri.parse('$apiUrl/v1/chapter/detail/$cleanId');
    try {
      final response = await http.get(url, headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final chData = data['data'] ?? {};
      final String baseUrl = chData['base_url'] ?? 'https://assets.shngm.id';
      final ch = chData['chapter'] ?? {};
      final String path = ch['path'] ?? '';
      final List pages = ch['data'] ?? [];

      final List<String> result = [];
      for (final p in pages) {
        result.add('$baseUrl$path$p');
      }
      return result;
    } catch (e) {
      return [];
    }
  }
}
