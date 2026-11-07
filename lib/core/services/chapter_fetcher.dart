import '../models/chapter.dart';
import '../models/manga.dart';
import 'bacakomik_service.dart';
import 'doujindesu_service.dart';
import 'ikiru_service.dart';
import 'kiryuu_service.dart';
import 'komikindo_service.dart';
import 'komiku_service.dart';
import 'luvyaa_service.dart';
import 'mangadex_service.dart';
import 'shinigami_service.dart';

/// Mengambil daftar bab sebuah komik dari sumber yang sesuai.
/// Dipakai oleh layar aplikasi maupun pengecekan bab baru di latar belakang.
class ChapterFetcher {
  static Future<List<Chapter>> fetch(Manga manga) async {
    switch (manga.sourceId) {
      case 'shinigami':
        return ShinigamiService.getMangaChapters(manga.url);
      case 'mangadex':
        return MangaDexService.getMangaChapters(manga.url);
      case 'kiryuu':
        return _chaptersFrom(await KiryuuService.getMangaDetails(manga.url));
      case 'doujindesu':
        return _chaptersFrom(await DoujinDesuService.getMangaDetails(manga.url));
      case 'komiku':
        return _chaptersFrom(await KomikuService.getMangaDetails(manga.url));
      case 'komikindo':
        return _chaptersFrom(await KomikIndoService.getMangaDetails(manga.url));
      case 'ikiru':
        return _chaptersFrom(await IkiruService.getMangaDetails(manga.url));
      case 'luvyaa':
        return _chaptersFrom(await LuvyaaService.getMangaDetails(manga.url));
      default:
        return _chaptersFrom(await BacaKomikService.getMangaDetails(manga.url));
    }
  }

  static List<Chapter> _chaptersFrom(Map<String, dynamic> details) =>
      (details['chapters'] as List?)?.cast<Chapter>() ?? [];
}
