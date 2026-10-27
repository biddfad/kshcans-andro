import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../models/manga.dart';
import '../models/chapter.dart';

class KomikIndoService {
  static const String baseUrl = 'https://komikindo.ch';
  static const Map<String, String> defaultHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Referer': '$baseUrl/',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
  };

  /// Pembersih URL thumbnail dari query resize WordPress
  static String cleanThumbnailUrl(String rawUrl) {
    if (rawUrl.isEmpty) return '';
    String cleaned = rawUrl;
    cleaned = cleaned.replaceAll(RegExp(r'https?://i\d+\.wp\.com/'), 'https://');
    cleaned = cleaned.replaceAll(RegExp(r'\?resize=.*$'), '');
    return cleaned.trim();
  }

  /// 1. Mengambil komik terpopuler di KomikIndo
  static Future<List<Manga>> getPopularManga({int page = 1}) async {
    final pagePath = page > 1 ? 'page/$page/' : '';
    final url = Uri.parse('$baseUrl/manga/$pagePath?order=popular');
    return _parseMangaList(url, category: 'Populer');
  }

  /// 2. Mengambil komik rilis terbaru di KomikIndo
  static Future<List<Manga>> getLatestUpdates({int page = 1}) async {
    final pagePath = page > 1 ? 'page/$page/' : '';
    final url = Uri.parse('$baseUrl/manga/$pagePath?order=update');
    return _parseMangaList(url, category: 'Terbaru');
  }

  /// 3. Pencarian komik di KomikIndo
  static Future<List<Manga>> searchManga(String query, {int page = 1}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return getPopularManga(page: page);
    final pagePath = page > 1 ? 'page/$page/' : '';
    final encoded = Uri.encodeComponent(cleanQuery);
    final url = Uri.parse('$baseUrl/$pagePath?s=$encoded');
    return _parseMangaList(url, category: 'Pencarian');
  }

  /// Helper parser daftar kartu komik dari HTML KomikIndo
  static Future<List<Manga>> _parseMangaList(Uri url, {required String category}) async {
    try {
      final response = await http.get(url, headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final document = html_parser.parse(response.body);
      final List<Manga> list = [];
      final Set<String> seenUrls = {};

      final elements = document.querySelectorAll('div.animepost, div.bsx');

      for (final el in elements) {
        final linkEl = el.querySelector('div.animposx > a, a[href*="/komik/"], a[href*="/manga/"]');
        if (linkEl == null) continue;

        String href = linkEl.attributes['href'] ?? '';
        if (href.isEmpty) continue;
        if (!href.startsWith('http')) {
          href = '$baseUrl${href.startsWith('/') ? '' : '/'}$href';
        }

        if (seenUrls.contains(href)) continue;
        seenUrls.add(href);

        // Judul
        final titleEl = el.querySelector('div.tt > h4, div.title, .tt, h4');
        String title = titleEl?.text.trim() ?? linkEl.attributes['title'] ?? 'Tanpa Judul';
        title = title.replaceAll(RegExp(r'^Komik\s+', caseSensitive: false), '').trim();

        // Thumbnail
        final imgEl = el.querySelector('img');
        String thumb = imgEl?.attributes['data-src'] ??
            imgEl?.attributes['src'] ??
            imgEl?.attributes['data-lazy-src'] ??
            '';
        thumb = cleanThumbnailUrl(thumb);

        // Type / Genre
        final typeEl = el.querySelector('div.typearm, span.type, .type');
        final genre = typeEl?.text.trim() ?? 'Manga';

        list.add(
          Manga(
            title: title,
            url: href,
            sourceId: 'komikindo',
            author: 'KomikIndo Author',
            description: '',
            genre: genre,
            status: 'Ongoing',
            thumbnailUrl: thumb,
            category: category,
            inLibrary: false,
            unreadCount: 0,
          ),
        );
      }

      return list;
    } catch (_) {
      return [];
    }
  }

  /// 4. Mengambil detail komik KomikIndo
  static Future<Map<String, dynamic>> getMangaDetails(String mangaUrl) async {
    try {
      final response =
          await http.get(Uri.parse(mangaUrl), headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return {};

      final document = html_parser.parse(response.body);

      // Sinopsis
      final descEl = document.querySelector('div.entry-content[itemprop="description"], div.sinopsis, div.desc');
      final description = descEl?.text.trim() ?? 'Belum ada sinopsis.';

      // Thumbnail
      final imgEl = document.querySelector('div.thumb img');
      String thumb = imgEl?.attributes['src'] ?? imgEl?.attributes['data-src'] ?? '';
      thumb = cleanThumbnailUrl(thumb);

      // Status & Genre
      String status = 'Ongoing';
      String genre = 'Manga';
      final speSpans = document.querySelectorAll('div.spe span, .info-content span');
      for (final sp in speSpans) {
        final text = sp.text.toLowerCase();
        if (text.contains('status:')) {
          status = sp.text.replaceAll(RegExp(r'status:\s*', caseSensitive: false), '').trim();
        } else if (text.contains('jenis komik:') || text.contains('tipe:')) {
          genre = sp.text.replaceAll(RegExp(r'(jenis komik:|tipe:)\s*', caseSensitive: false), '').trim();
        }
      }

      final genreLinks = document.querySelectorAll('div.genre-info a, a[rel="tag"]');
      if (genreLinks.isNotEmpty) {
        genre = genreLinks.map((g) => g.text.trim()).join(', ');
      }

      // Chapters dari <div id="chapter_list">
      final List<Chapter> chapters = [];
      final chElements = document.querySelectorAll('div#chapter_list ul li, ul.clstyle li');

      int chId = 1;
      for (final li in chElements) {
        final aTag = li.querySelector('span.lchx a, a');
        if (aTag == null) continue;

        String chHref = aTag.attributes['href'] ?? '';
        if (chHref.isEmpty) continue;
        if (!chHref.startsWith('http')) {
          chHref = '$baseUrl${chHref.startsWith('/') ? '' : '/'}$chHref';
        }

        final nameText = aTag.text.trim();
        final dateEl = li.querySelector('span.dt a, span.dt');
        final dateUpload = dateEl?.text.trim() ?? '';

        final numMatch = RegExp(r'(\d+(\.\d+)?)').firstMatch(nameText);
        final chNumber = numMatch != null ? double.tryParse(numMatch.group(1)!) ?? chId.toDouble() : chId.toDouble();

        chapters.add(
          Chapter(
            id: chId++,
            mangaId: 0,
            url: chHref,
            name: nameText.isEmpty ? 'Bab $chId' : nameText,
            chapterNumber: chNumber,
            dateUpload: dateUpload,
          ),
        );
      }

      return {
        'description': description,
        'status': status,
        'genre': genre,
        'thumbnailUrl': thumb,
        'chapters': chapters,
      };
    } catch (_) {
      return {};
    }
  }

  /// 5. Mengambil daftar lembaran gambar komik KomikIndo
  static Future<List<String>> getChapterPages(String chapterUrl) async {
    try {
      final response =
          await http.get(Uri.parse(chapterUrl), headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final document = html_parser.parse(response.body);
      final List<String> pages = [];

      final container = document.querySelector('div.chapter-image, div#chimg-auh, div#Baca_Komik');
      final imgElements = container != null ? container.querySelectorAll('img') : document.querySelectorAll('img');

      for (final img in imgElements) {
        String src = img.attributes['src'] ?? img.attributes['data-src'] ?? '';
        if (src.isEmpty) continue;
        if (src.startsWith('//')) src = 'https:$src';

        // Filter out ads
        final lower = src.toLowerCase();
        if (lower.contains('fav.png') ||
            lower.contains('komikindo-') ||
            lower.endsWith('.gif') ||
            lower.contains('banner') ||
            lower.contains('iklan')) {
          continue;
        }

        if (src.startsWith('http') && !pages.contains(src)) {
          pages.add(src);
        }
      }

      return pages;
    } catch (_) {
      return [];
    }
  }
}
