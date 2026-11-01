import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aplikasibacakomik/core/database/db_helper.dart';
import 'package:aplikasibacakomik/core/models/chapter.dart';
import 'package:aplikasibacakomik/core/models/manga.dart';
import 'package:aplikasibacakomik/core/services/chapter_update_service.dart';

Manga _manga(String slug) => Manga(
      title: 'Komik $slug',
      url: 'https://contoh.com/$slug',
      sourceId: 'komiku',
      author: '',
      description: '',
      genre: '',
      status: 'Ongoing',
      thumbnailUrl: '',
      inLibrary: true,
    );

List<Chapter> _chapters(String slug, int count) => [
      for (var i = count; i >= 1; i--)
        Chapter(mangaId: 0, url: 'https://contoh.com/$slug/bab-$i', name: 'Bab $i', chapterNumber: i.toDouble(), dateUpload: ''),
    ];

void main() {
  // Simulasi isi sumber: slug -> jumlah bab saat ini
  final sourceState = <String, int>{};
  Future<List<Chapter>> fakeFetcher(Manga manga) async {
    final slug = manga.url.split('/').last;
    if (slug == 'rusak') throw const SocketException('sumber error');
    return _chapters(slug, sourceState[slug] ?? 0);
  }

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    final dir = await Directory.systemTemp.createTemp('kshcans_update_test_');
    await databaseFactory.setDatabasesPath(dir.path);
  });

  setUp(() async {
    final db = await DBHelper.instance.database;
    await db.delete('manga');
    await db.delete('known_chapters');
    sourceState.clear();
  });

  test('pengecekan pertama hanya mencatat, tanpa notifikasi palsu', () async {
    await DBHelper.instance.saveMangaToLibrary(_manga('a'));
    sourceState['a'] = 10;
    final results = await ChapterUpdateService.checkLibrary(fetcher: fakeFetcher);
    expect(results, isEmpty);
    expect((await DBHelper.instance.getKnownChapterUrls('https://contoh.com/a')).length, 10);
  });

  test('bab baru terdeteksi, terbaru lebih dulu, dan tidak dinotifikasi dua kali', () async {
    await DBHelper.instance.saveMangaToLibrary(_manga('a'));
    sourceState['a'] = 10;
    await ChapterUpdateService.checkLibrary(fetcher: fakeFetcher);

    sourceState['a'] = 12;
    final results = await ChapterUpdateService.checkLibrary(fetcher: fakeFetcher);
    expect(results.single.manga.title, 'Komik a');
    expect(results.single.newChapters.map((c) => c.name), ['Bab 12', 'Bab 11']);

    final again = await ChapterUpdateService.checkLibrary(fetcher: fakeFetcher);
    expect(again, isEmpty);
  });

  test('satu sumber error tidak menghentikan pengecekan komik lain', () async {
    await DBHelper.instance.saveMangaToLibrary(_manga('rusak'));
    await DBHelper.instance.saveMangaToLibrary(_manga('b'));
    sourceState['b'] = 3;
    await ChapterUpdateService.checkLibrary(fetcher: fakeFetcher);

    sourceState['b'] = 4;
    final results = await ChapterUpdateService.checkLibrary(fetcher: fakeFetcher);
    expect(results.single.newChapters.single.name, 'Bab 4');
  });

  test('sumber kosong sementara tidak menghapus catatan bab', () async {
    await DBHelper.instance.saveMangaToLibrary(_manga('c'));
    sourceState['c'] = 5;
    await ChapterUpdateService.checkLibrary(fetcher: fakeFetcher);

    sourceState['c'] = 0; // mis. halaman sumber gagal di-parse
    expect(await ChapterUpdateService.checkLibrary(fetcher: fakeFetcher), isEmpty);

    sourceState['c'] = 5; // pulih: tidak boleh dianggap 5 bab baru
    expect(await ChapterUpdateService.checkLibrary(fetcher: fakeFetcher), isEmpty);
  });
}
