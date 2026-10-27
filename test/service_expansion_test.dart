import 'package:flutter_test/flutter_test.dart';
import 'package:aplikasibacakomik/core/services/komiku_service.dart';
import 'package:aplikasibacakomik/core/services/komikindo_service.dart';

void main() {
  test('KomikuService live check', () async {
    final pop = await KomikuService.getPopularManga(page: 1);
    expect(pop, isA<List>());

    final search = await KomikuService.searchManga('Solo', page: 1);
    expect(search, isA<List>());
  });

  test('KomikIndoService live check', () async {
    final pop = await KomikIndoService.getPopularManga(page: 1);
    expect(pop, isA<List>());

    final search = await KomikIndoService.searchManga('Revenge', page: 1);
    expect(search, isA<List>());
  });
}
