// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:aplikasibacakomik/core/services/app_http_overrides.dart';
import 'package:aplikasibacakomik/core/services/source_config_service.dart';
import 'package:aplikasibacakomik/core/services/shinigami_service.dart';
import 'package:aplikasibacakomik/core/services/komikindo_service.dart';
import 'package:aplikasibacakomik/core/services/kiryuu_service.dart';
import 'package:aplikasibacakomik/core/services/bacakomik_service.dart';
import 'package:aplikasibacakomik/core/services/komiku_service.dart';
import 'package:aplikasibacakomik/core/services/doujindesu_service.dart';
import 'package:aplikasibacakomik/core/services/mangadex_service.dart';
import 'package:aplikasibacakomik/core/services/ikiru_service.dart';
import 'package:aplikasibacakomik/core/services/luvyaa_service.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = AppHttpOverrides();
  });

  test('Audit 9 Sources Full Lifecycle (Catalog -> Detail -> Chapter -> Images)', () async {
    // 1. Shinigami
    print('\n[1. SHINIGAMI]');
    try {
      final list = await ShinigamiService.getPopularManga();
      print('Catalog: ${list.length} items');
      if (list.isNotEmpty) {
        final chs = await ShinigamiService.getMangaChapters(list.first.url);
        print('Chapters: ${chs.length}');
        if (chs.isNotEmpty) {
          final pages = await ShinigamiService.getChapterPages(chs.first.url);
          print('Pages: ${pages.length}');
          if (pages.isNotEmpty) {
            final res = await http.get(Uri.parse(pages.first), headers: SourceConfigService.getImageHeaders('shinigami', pages.first));
            print('Image test: ${res.statusCode}');
          }
        }
      }
    } catch (e) {
      print('ERROR: $e');
    }

    // 2. KomikIndo
    print('\n[2. KOMIKINDO]');
    try {
      final list = await KomikIndoService.getPopularManga();
      print('Catalog: ${list.length} items');
      if (list.isNotEmpty) {
        final d = await KomikIndoService.getMangaDetails(list.first.url);
        final chs = d['chapters'] as List?;
        print('Chapters: ${chs?.length}');
        if (chs != null && chs.isNotEmpty) {
          final pages = await KomikIndoService.getChapterPages(chs.first.url);
          print('Pages: ${pages.length}');
          if (pages.isNotEmpty) {
            final res = await http.get(Uri.parse(pages.first), headers: SourceConfigService.getImageHeaders('komikindo', pages.first));
            print('Image test: ${res.statusCode}');
          }
        }
      }
    } catch (e) {
      print('ERROR: $e');
    }

    // 3. Kiryuu
    print('\n[3. KIRYUU]');
    try {
      final list = await KiryuuService.getPopularManga();
      print('Catalog: ${list.length} items');
      if (list.isNotEmpty) {
        final d = await KiryuuService.getMangaDetails(list.first.url);
        final chs = d['chapters'] as List?;
        print('Chapters: ${chs?.length}');
        if (chs != null && chs.isNotEmpty) {
          final pages = await KiryuuService.getChapterPages(chs.first.url);
          print('Pages: ${pages.length}');
          if (pages.isNotEmpty) {
            final res = await http.get(Uri.parse(pages.first), headers: SourceConfigService.getImageHeaders('kiryuu', pages.first));
            print('Image test: ${res.statusCode}');
          }
        }
      }
    } catch (e) {
      print('ERROR: $e');
    }

    // 4. BacaKomik
    print('\n[4. BACAKOMIK]');
    try {
      final list = await BacaKomikService.getPopularManga();
      print('Catalog: ${list.length} items');
      if (list.isNotEmpty) {
        final d = await BacaKomikService.getMangaDetails(list.first.url);
        final chs = d['chapters'] as List?;
        print('Chapters: ${chs?.length}');
        if (chs != null && chs.isNotEmpty) {
          final pages = await BacaKomikService.getChapterPages(chs.first.url);
          print('Pages: ${pages.length}');
          if (pages.isNotEmpty) {
            final res = await http.get(Uri.parse(pages.first), headers: SourceConfigService.getImageHeaders('bacakomik', pages.first));
            print('Image test: ${res.statusCode}');
          }
        }
      }
    } catch (e) {
      print('ERROR: $e');
    }

    // 5. Komiku
    print('\n[5. KOMIKU]');
    try {
      final list = await KomikuService.getPopularManga();
      print('Catalog: ${list.length} items');
      if (list.isNotEmpty) {
        final d = await KomikuService.getMangaDetails(list.first.url);
        final chs = d['chapters'] as List?;
        print('Chapters: ${chs?.length}');
        if (chs != null && chs.isNotEmpty) {
          final pages = await KomikuService.getChapterPages(chs.first.url);
          print('Pages: ${pages.length}');
          if (pages.isNotEmpty) {
            final res = await http.get(Uri.parse(pages.first), headers: SourceConfigService.getImageHeaders('komiku', pages.first));
            print('Image test: ${res.statusCode}');
          }
        }
      }
    } catch (e) {
      print('ERROR: $e');
    }

    // 6. DoujinDesu
    print('\n[6. DOUJINDESU]');
    try {
      final list = await DoujinDesuService.getPopularManga();
      print('Catalog: ${list.length} items');
      if (list.isNotEmpty) {
        final d = await DoujinDesuService.getMangaDetails(list.first.url);
        final chs = d['chapters'] as List?;
        print('Chapters: ${chs?.length}');
        if (chs != null && chs.isNotEmpty) {
          final pages = await DoujinDesuService.getChapterPages(chs.first.url);
          print('Pages: ${pages.length}');
          if (pages.isNotEmpty) {
            final res = await http.get(Uri.parse(pages.first), headers: SourceConfigService.getImageHeaders('doujindesu', pages.first));
            print('Image test: ${res.statusCode}');
          }
        }
      }
    } catch (e) {
      print('ERROR: $e');
    }

    // 7. MangaDex
    print('\n[7. MANGADEX]');
    try {
      final list = await MangaDexService.getPopularManga();
      print('Catalog: ${list.length} items');
      if (list.isNotEmpty) {
        final chs = await MangaDexService.getMangaChapters(list.first.url);
        print('Chapters: ${chs.length}');
        if (chs.isNotEmpty) {
          final pages = await MangaDexService.getChapterPages(chs.first.url);
          print('Pages: ${pages.length}');
          if (pages.isNotEmpty) {
            final res = await http.get(Uri.parse(pages.first), headers: SourceConfigService.getImageHeaders('mangadex', pages.first));
            print('Image test: ${res.statusCode}');
          }
        }
      }
    } catch (e) {
      print('ERROR: $e');
    }

    // 8. Ikiru
    print('\n[8. IKIRU]');
    try {
      final list = await IkiruService.getPopularManga();
      print('Catalog: ${list.length} items');
    } catch (e) {
      print('ERROR: $e');
    }

    // 9. Luvyaa
    print('\n[9. LUVYAA]');
    try {
      final list = await LuvyaaService.getPopularManga();
      print('Catalog: ${list.length} items');
    } catch (e) {
      print('ERROR: $e');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
