// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:aplikasibacakomik/core/services/app_http_overrides.dart';
import 'package:aplikasibacakomik/core/services/mangadex_service.dart';
import 'package:aplikasibacakomik/core/services/komikindo_service.dart';
import 'package:aplikasibacakomik/core/services/bacakomik_service.dart';
import 'package:aplikasibacakomik/core/services/komiku_service.dart';
import 'package:aplikasibacakomik/core/services/kiryuu_service.dart';
import 'package:aplikasibacakomik/core/services/shinigami_service.dart';
import 'package:aplikasibacakomik/core/services/doujindesu_service.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = AppHttpOverrides();
  });

  test('Test MangaDex Detail & Chapters & Pages', () async {
    // Frieren on MangaDex
    final chapters = await MangaDexService.getMangaChapters('b0b721ff-c388-4486-aa0f-c2b0bb321512');
    print('MangaDex Frieren chapters count: ${chapters.length}');
    expect(chapters.isNotEmpty, true);
    final pages = await MangaDexService.getChapterPages(chapters.first.url);
    print('MangaDex pages: ${pages.length}');
    expect(pages.isNotEmpty, true);
  });

  test('Test KomikIndo Detail & Chapters & Pages', () async {
    final list = await KomikIndoService.getPopularManga(page: 1);
    expect(list.isNotEmpty, true);
    final first = list.first;
    print('KomikIndo: ${first.title} (${first.url})');
    final details = await KomikIndoService.getMangaDetails(first.url);
    final chapters = details['chapters'] as List? ?? [];
    print('KomikIndo chapters count: ${chapters.length}');
    expect(chapters.isNotEmpty, true);
    final pages = await KomikIndoService.getChapterPages(chapters.first.url);
    print('KomikIndo pages: ${pages.length}');
    expect(pages.isNotEmpty, true);
  });

  test('Test BacaKomik Detail & Chapters & Pages', () async {
    final list = await BacaKomikService.getPopularManga(page: 1);
    expect(list.isNotEmpty, true);
    final first = list.first;
    print('BacaKomik: ${first.title} (${first.url})');
    final details = await BacaKomikService.getMangaDetails(first.url);
    final chapters = details['chapters'] as List? ?? [];
    print('BacaKomik chapters count: ${chapters.length}');
    expect(chapters.isNotEmpty, true);
    final pages = await BacaKomikService.getChapterPages(chapters.first.url);
    print('BacaKomik pages: ${pages.length}');
    expect(pages.isNotEmpty, true);
  });

  test('Test Komiku Detail & Chapters & Pages', () async {
    final list = await KomikuService.getPopularManga(page: 1);
    expect(list.isNotEmpty, true);
    final first = list.first;
    print('Komiku: ${first.title} (${first.url})');
    final details = await KomikuService.getMangaDetails(first.url);
    final chapters = details['chapters'] as List? ?? [];
    print('Komiku chapters count: ${chapters.length}');
    expect(chapters.isNotEmpty, true);
    final pages = await KomikuService.getChapterPages(chapters.first.url);
    print('Komiku pages: ${pages.length}');
    expect(pages.isNotEmpty, true);
  });

  test('Test Kiryuu Detail & Chapters & Pages', () async {
    final list = await KiryuuService.getPopularManga(page: 1);
    expect(list.isNotEmpty, true);
    final first = list.first;
    print('Kiryuu: ${first.title} (${first.url})');
    final details = await KiryuuService.getMangaDetails(first.url);
    final chapters = details['chapters'] as List? ?? [];
    print('Kiryuu chapters count: ${chapters.length}');
    expect(chapters.isNotEmpty, true);
    final pages = await KiryuuService.getChapterPages(chapters.first.url);
    print('Kiryuu pages: ${pages.length}');
    expect(pages.isNotEmpty, true);
  });

  test('Test Shinigami Detail & Chapters & Pages', () async {
    final list = await ShinigamiService.getPopularManga(page: 1);
    expect(list.isNotEmpty, true);
    final first = list.first;
    print('Shinigami: ${first.title} (${first.url})');
    final chapters = await ShinigamiService.getMangaChapters(first.url);
    print('Shinigami chapters count: ${chapters.length}');
    expect(chapters.isNotEmpty, true);
    final pages = await ShinigamiService.getChapterPages(chapters.first.url);
    print('Shinigami pages: ${pages.length}');
    expect(pages.isNotEmpty, true);
  });

  test('Test DoujinDesu Detail & Chapters & Pages', () async {
    final list = await DoujinDesuService.getPopularManga(page: 1);
    expect(list.isNotEmpty, true);
    final first = list.first;
    print('DoujinDesu: ${first.title} (${first.url})');
    final details = await DoujinDesuService.getMangaDetails(first.url);
    final chapters = details['chapters'] as List? ?? [];
    print('DoujinDesu chapters count: ${chapters.length}');
    expect(chapters.isNotEmpty, true);
    final pages = await DoujinDesuService.getChapterPages(chapters.first.url);
    print('DoujinDesu pages: ${pages.length}');
    expect(pages.isNotEmpty, true);
  });
}
