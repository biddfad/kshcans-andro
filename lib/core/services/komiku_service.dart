import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../models/manga.dart';
import '../models/chapter.dart';

class KomikuService {
  static const String baseUrl = 'https://komiku.org';
  static const String searchApiUrl = 'https://api.komiku.org';

  static const Map<String, String> defaultHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Referer': '$baseUrl/',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
  };

  /// 1. Mengambil komik terpopuler di Komiku
  static Future<List<Manga>> getPopularManga({int page = 1}) async {
    final pagePath = page > 1 ? 'page/$page/' : '';
    final url = Uri.parse('$baseUrl/p/ranking/$pagePath');
    return _parseMangaList(url, category: 'Populer');
  }

  /// 2. Mengambil komik rilis terbaru di Komiku
  static Future<List<Manga>> getLatestUpdates({int page = 1}) async {
    final pagePath = page > 1 ? 'page/$page/' : '';
    final url = Uri.parse('$baseUrl/pustaka/$pagePath');
    return _parseMangaList(url, category: 'Terbaru');
  }

  /// 3. Pencarian komik di Komiku (menggunakan HTMX direct search endpoint)
  static Future<List<Manga>> searchManga(String query, {int page = 1}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return getPopularManga(page: page);
    final pagePath = page > 1 ? 'page/$page/' : '';
    final encoded = Uri.encodeComponent(cleanQuery);
    final url = Uri.parse('$searchApiUrl/$pagePath?post_type=manga&s=$encoded');
    return _parseMangaList(url, category: 'Pencarian');
  }

  /// Helper parser daftar kartu komik dari HTML Komiku
  static Future<List<Manga>> _parseMangaList(Uri url, {required String category}) async {
    try {
      final response = await http.get(url, headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final document = html_parser.parse(response.body);
      final List<Manga> list = [];
      final Set<String> seenUrls = {};

      // Kartu komik Komiku bertipe <article class="ls4">, <div class="bge">, atau <div class="bsh">
      final articles = document.querySelectorAll('article.ls4, div.bge, div.bsh, div.animepost');

      for (final article in articles) {
        final linkEl = article.querySelector('a[href*="/manga/"], a[href*="/komik/"]');
        if (linkEl == null) continue;

        String href = linkEl.attributes['href'] ?? '';
        if (href.isEmpty) continue;
        if (!href.startsWith('http')) {
          href = '$baseUrl${href.startsWith('/') ? '' : '/'}$href';
        }

        if (seenUrls.contains(href)) continue;
        seenUrls.add(href);

        // Judul
        final titleEl = article.querySelector('h3, h4, .tt, .judul');
        String title = titleEl?.text.trim() ?? linkEl.attributes['title'] ?? 'Tanpa Judul';
        title = title.replaceAll(RegExp(r'^Baca\s+Komik\s+|^Komik\s+', caseSensitive: false), '').trim();

        // Thumbnail
        final imgEl = article.querySelector('img');
        String thumb = imgEl?.attributes['data-src'] ??
            imgEl?.attributes['src'] ??
            imgEl?.attributes['data-lazy-src'] ??
            '';
        if (thumb.startsWith('//')) {
          thumb = 'https:$thumb';
        } else if (thumb.startsWith('/') && !thumb.startsWith('/asset/')) {
          thumb = '$baseUrl$thumb';
        } else if (thumb.contains('lazy.jpg')) {
          thumb = imgEl?.attributes['data-src'] ?? '';
        }
        thumb = thumb.replaceAll(RegExp(r'\?resize=.*$'), '');

        // Genre / Tipe
        final genreEl = article.querySelector('.tpe1_inf, .ls4s, .type, .genres');
        final genre = genreEl?.text.trim().replaceAll(RegExp(r'\s+'), ' ') ?? 'Manga';

        list.add(
          Manga(
            title: title,
            url: href,
            sourceId: 'komiku',
            author: 'Komiku Author',
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

  /// 4. Mengambil detail komik (sinopsis, status, genre, chapters)
  static Future<Map<String, dynamic>> getMangaDetails(String mangaUrl) async {
    try {
      final response =
          await http.get(Uri.parse(mangaUrl), headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return {};

      final document = html_parser.parse(response.body);

      // Sinopsis
      final descEl = document.querySelector('p.desc, div.sinopsis, [itemprop="description"]');
      final description = descEl?.text.trim() ?? 'Belum ada sinopsis.';

      // Cover Thumbnail
      final imgEl = document.querySelector('#Informasi img, .ims img, .thumb img');
      String thumb = imgEl?.attributes['src'] ?? imgEl?.attributes['data-src'] ?? '';
      if (thumb.startsWith('//')) thumb = 'https:$thumb';
      thumb = thumb.replaceAll(RegExp(r'\?resize=.*$'), '');

      // Status & Genre dari tabel informasi
      String status = 'Ongoing';
      String genre = 'Manga';
      final tableRows = document.querySelectorAll('table.inftable tr');
      for (final tr in tableRows) {
        final text = tr.text.toLowerCase();
        if (text.contains('status')) {
          status = tr.querySelectorAll('td').last.text.trim();
        } else if (text.contains('genre') || text.contains('tema')) {
          genre = tr.querySelectorAll('td').last.text.trim().replaceAll(RegExp(r'\s+'), ' ');
        }
      }

      // Daftar Chapter dari <table id="Daftar_Chapter">
      final List<Chapter> chapters = [];
      final chapterRows = document.querySelectorAll('#Daftar_Chapter tr, table.chapter-table tr');

      int chId = 1;
      for (final tr in chapterRows) {
        final linkEl = tr.querySelector('td.judulseries a, a[href*="chapter"]');
        if (linkEl == null) continue;

        String chHref = linkEl.attributes['href'] ?? '';
        if (chHref.isEmpty) continue;
        if (!chHref.startsWith('http')) {
          chHref = '$baseUrl${chHref.startsWith('/') ? '' : '/'}$chHref';
        }

        final nameText = linkEl.text.trim();
        final dateEl = tr.querySelector('td.tanggalseries, .tgl');
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

  /// 5. Mengambil daftar URL lembaran gambar untuk dibaca di reader
  static Future<List<String>> getChapterPages(String chapterUrl) async {
    try {
      final response =
          await http.get(Uri.parse(chapterUrl), headers: defaultHeaders).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];

      final document = html_parser.parse(response.body);
      final List<String> pages = [];

      final container = document.querySelector('#Baca_Komik, #readerarea, div.content-baca');
      final imgElements = container != null ? container.querySelectorAll('img') : document.querySelectorAll('img');

      for (final img in imgElements) {
        String src = img.attributes['src'] ?? img.attributes['data-src'] ?? '';
        if (src.isEmpty) continue;
        if (src.startsWith('//')) src = 'https:$src';

        // Filter iklan & banner promosi
        final lower = src.toLowerCase();
        if (lower.contains('promosi') ||
            lower.contains('iklan') ||
            lower.contains('banner') ||
            lower.contains('logo-komiku') ||
            lower.endsWith('.gif')) {
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
