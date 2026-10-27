import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import '../database/db_helper.dart';
import 'bacakomik_service.dart';
import 'doujindesu_service.dart';
import 'kiryuu_service.dart';
import 'komiku_service.dart';
import 'komikindo_service.dart';
import 'mangadex_service.dart';
import 'shinigami_service.dart';

class DownloadService {
  /// Mendapatkan direktori dasar untuk seluruh unduhan komik
  static Future<Directory> getDownloadsDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory(p.join(docsDir.path, 'downloads'));
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir;
  }

  /// Membersihkan nama folder agar aman di file system Android & anti path-traversal
  static String sanitizeFolderName(String name) {
    String safe = name
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'^\.+|\.+$'), '')
        .trim();
    if (safe.length > 80) {
      safe = safe.substring(0, 80).trim();
    }
    return safe.isEmpty ? 'untitled' : safe;
  }

  /// Mendapatkan direktori spesifik untuk suatu bab komik
  static Future<Directory> getChapterDirectory(String mangaTitle, Chapter chapter) async {
    final baseDir = await getDownloadsDirectory();
    final safeManga = sanitizeFolderName(mangaTitle);
    final safeChapter = sanitizeFolderName(chapter.name.isNotEmpty ? chapter.name : 'bab_${chapter.chapterNumber}');
    final chapterDir = Directory(p.join(baseDir.path, safeManga, safeChapter));
    return chapterDir;
  }

  /// Memeriksa apakah suatu bab sudah terunduh secara offline
  static Future<bool> isChapterDownloaded(String mangaTitle, Chapter chapter) async {
    try {
      final dir = await getChapterDirectory(mangaTitle, chapter);
      if (!await dir.exists()) return false;
      final files = dir.listSync().whereType<File>().where((f) {
        final ext = p.extension(f.path).toLowerCase();
        return ext == '.jpg' || ext == '.png' || ext == '.webp' || ext == '.jpeg';
      }).toList();
      return files.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Mengambil daftar path file lembaran lokal dari bab yang terunduh
  static Future<List<String>> getDownloadedPages(String mangaTitle, Chapter chapter) async {
    try {
      final dir = await getChapterDirectory(mangaTitle, chapter);
      if (!await dir.exists()) return [];
      final files = dir.listSync().whereType<File>().where((f) {
        final ext = p.extension(f.path).toLowerCase();
        return ext == '.jpg' || ext == '.png' || ext == '.webp' || ext == '.jpeg';
      }).toList();

      files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
      return files.map((f) => f.path).toList();
    } catch (_) {
      return [];
    }
  }

  /// Header HTTP referer sesuai sumber
  static Map<String, String> _getHeadersForSource(Manga manga) {
    if (manga.sourceId == 'shinigami' || manga.thumbnailUrl.contains('shngm')) {
      return const {
        'Referer': 'https://shinigami.asia/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
    } else if (manga.sourceId == 'komiku' || manga.thumbnailUrl.contains('komiku')) {
      return const {
        'Referer': 'https://komiku.org/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      };
    } else if (manga.sourceId == 'komikindo' || manga.thumbnailUrl.contains('komikindo')) {
      return const {
        'Referer': 'https://komikindo.ch/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      };
    } else if (manga.sourceId == 'doujindesu' || manga.thumbnailUrl.contains('desu.')) {
      return const {
        'Referer': 'https://doujin.desu.xxx/',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
      };
    } else if (manga.sourceId == 'kiryuu' || manga.thumbnailUrl.contains('kiryuu')) {
      return const {
        'Referer': 'https://v7.kiryuu.to/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
    } else if (manga.sourceId == 'mangadex' || manga.thumbnailUrl.contains('mangadex')) {
      return const {
        'User-Agent': 'KsHcans/1.0.0',
      };
    } else {
      return const {
        'Referer': 'https://bacakomik.my/',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      };
    }
  }

  /// Mengunduh seluruh lembaran komik dari satu bab ke penyimpanan lokal
  static Future<bool> downloadChapter({
    required Manga manga,
    required Chapter chapter,
    Function(int current, int total)? onProgress,
  }) async {
    try {
      // 1. Ambil URL lembaran dari service yang bersangkutan
      List<String> pageUrls = [];
      final url = chapter.url;
      if (url.startsWith('shinigami:')) {
        pageUrls = await ShinigamiService.getChapterPages(url);
      } else if (url.startsWith('doujindesu:') || manga.sourceId == 'doujindesu') {
        pageUrls = await DoujinDesuService.getChapterPages(url);
      } else if (url.contains('komiku') || manga.sourceId == 'komiku') {
        pageUrls = await KomikuService.getChapterPages(url);
      } else if (url.contains('komikindo') || manga.sourceId == 'komikindo') {
        pageUrls = await KomikIndoService.getChapterPages(url);
      } else if (url.contains('kiryuu') || manga.sourceId == 'kiryuu') {
        pageUrls = await KiryuuService.getChapterPages(url);
      } else if (manga.sourceId == 'mangadex' || !url.startsWith('http')) {
        pageUrls = await MangaDexService.getChapterPages(url);
      } else {
        pageUrls = await BacaKomikService.getChapterPages(url);
      }

      if (pageUrls.isEmpty) return false;

      // 2. Siapkan folder penyimpanan lokal
      final dir = await getChapterDirectory(manga.title, chapter);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final headers = _getHeadersForSource(manga);

      // 3. Unduh lembaran demi lembaran dengan verifikasi integritas & auto-retry
      int successfulPages = 0;
      for (int i = 0; i < pageUrls.length; i++) {
        final imgUrl = pageUrls[i];
        final fileNumber = (i + 1).toString().padLeft(3, '0');
        final targetPath = p.join(dir.path, 'page_$fileNumber.jpg');
        final partPath = p.join(dir.path, 'page_$fileNumber.part');

        // Jika file final sudah ada dan valid (>500 byte), lewati
        final targetFile = File(targetPath);
        if (await targetFile.exists() && await targetFile.length() > 500) {
          successfulPages++;
          onProgress?.call(i + 1, pageUrls.length);
          continue;
        }

        // Coba unduh dengan toleransi auto-retry maksimal 2 kali
        bool pageSuccess = false;
        for (int attempt = 1; attempt <= 2; attempt++) {
          try {
            final response = await http
                .get(Uri.parse(imgUrl), headers: headers)
                .timeout(const Duration(seconds: 25));
            if (response.statusCode == 200 && response.bodyBytes.length > 500) {
              final partFile = File(partPath);
              await partFile.writeAsBytes(response.bodyBytes, flush: true);
              if (await partFile.exists()) {
                if (await targetFile.exists()) await targetFile.delete();
                await partFile.rename(targetPath);
                pageSuccess = true;
                break;
              }
            }
          } catch (_) {
            if (attempt < 2) {
              await Future.delayed(const Duration(milliseconds: 600));
            }
          }
        }

        if (pageSuccess) {
          successfulPages++;
        }
        onProgress?.call(i + 1, pageUrls.length);
      }

      // Bersihkan sisa file .part sementara yang tertinggal
      try {
        final remainingParts = dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.part'));
        for (final pf in remainingParts) {
          await pf.delete();
        }
      } catch (_) {}

      // 4. Verifikasi apakah seluruh halaman sukses 100%
      if (successfulPages == pageUrls.length) {
        await DBHelper.instance.setChapterDownloaded(chapter.url, true);
        chapter.isDownloaded = true;
        return true;
      } else {
        // Jangan tandai downloaded jika masih ada halaman yang bolong
        await DBHelper.instance.setChapterDownloaded(chapter.url, false);
        chapter.isDownloaded = false;
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  /// Menghapus bab komik yang terunduh dari penyimpanan lokal
  static Future<void> deleteDownloadedChapter(String mangaTitle, Chapter chapter) async {
    try {
      final dir = await getChapterDirectory(mangaTitle, chapter);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      await DBHelper.instance.setChapterDownloaded(chapter.url, false);
      chapter.isDownloaded = false;
    } catch (_) {}
  }

  /// Menghitung total ukuran file unduhan komik dalam format MB
  static Future<double> getTotalDownloadSizeMb() async {
    try {
      final baseDir = await getDownloadsDirectory();
      if (!await baseDir.exists()) return 0.0;

      int totalBytes = 0;
      await for (final entity in baseDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalBytes += await entity.length();
        }
      }
      return totalBytes / (1024 * 1024);
    } catch (_) {
      return 0.0;
    }
  }

  /// Menghapus seluruh unduhan komik dari memori HP
  static Future<void> deleteAllDownloads() async {
    try {
      final baseDir = await getDownloadsDirectory();
      if (await baseDir.exists()) {
        await baseDir.delete(recursive: true);
      }
      await DBHelper.instance.resetAllDownloads();
    } catch (_) {}
  }
}
