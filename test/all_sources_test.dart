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
  test('MangaDexService check', () async {
    final pop = await MangaDexService.getPopularManga(page: 1);
    print('MangaDex popular count: ${pop.length}');
    expect(pop, isA<List>());
  });

  test('KomikIndoService check', () async {
    final pop = await KomikIndoService.getPopularManga(page: 1);
    print('KomikIndo popular count: ${pop.length}');
    expect(pop, isA<List>());
  });

  test('BacaKomikService check', () async {
    final pop = await BacaKomikService.getPopularManga(page: 1);
    print('BacaKomik popular count: ${pop.length}');
    expect(pop, isA<List>());
  });

  test('KomikuService check', () async {
    final pop = await KomikuService.getPopularManga(page: 1);
    print('Komiku popular count: ${pop.length}');
    expect(pop, isA<List>());
  });

  test('KiryuuService check', () async {
    final pop = await KiryuuService.getPopularManga(page: 1);
    print('Kiryuu popular count: ${pop.length}');
    expect(pop, isA<List>());
  });

  test('ShinigamiService check', () async {
    final pop = await ShinigamiService.getPopularManga(page: 1);
    print('Shinigami popular count: ${pop.length}');
    expect(pop, isA<List>());
  });

  test('DoujinDesuService check', () async {
    final pop = await DoujinDesuService.getPopularManga(page: 1);
    print('DoujinDesu popular count: ${pop.length}');
    expect(pop, isA<List>());
  });
}
