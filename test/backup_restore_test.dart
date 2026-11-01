import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aplikasibacakomik/core/database/db_helper.dart';
import 'package:aplikasibacakomik/core/models/manga.dart';
import 'package:aplikasibacakomik/providers/manga_provider.dart';

Future<void> _clearDb() async {
  final db = await DBHelper.instance.database;
  await db.delete('manga');
  await db.delete('reading_history');
  await db.delete('read_chapters');
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    final dir = await Directory.systemTemp.createTemp('kshcans_test_');
    await databaseFactory.setDatabasesPath(dir.path);
  });

  setUp(_clearDb);

  test('ekspor lalu pulihkan mengembalikan pustaka, riwayat, dan bab terbaca', () async {
    await DBHelper.instance.saveMangaToLibrary(Manga(
      title: 'Komik A',
      url: 'https://contoh.com/komik-a',
      sourceId: 'komiku',
      author: 'X',
      description: '',
      genre: 'Action',
      status: 'Ongoing',
      thumbnailUrl: '',
      category: 'Favorit',
      inLibrary: true,
    ));
    await DBHelper.instance.saveReadingHistory(
      mangaTitle: 'Komik A',
      mangaUrl: 'https://contoh.com/komik-a',
      sourceId: 'komiku',
      thumbnailUrl: '',
      chapterName: 'Bab 5',
      chapterUrl: 'https://contoh.com/komik-a/bab-5',
      chapterNumber: 5,
    );
    await DBHelper.instance.markChapterRead('https://contoh.com/komik-a/bab-4', true);
    await DBHelper.instance.markChapterRead('https://contoh.com/komik-a/bab-5', true);

    final provider = MangaProvider();
    final backup = await provider.exportLibraryJson();
    final decoded = jsonDecode(backup) as Map;
    expect((decoded['library'] as List).length, 1);
    expect((decoded['history'] as List).length, 1);
    expect((decoded['readChapters'] as List).length, 2);

    // Simulasi uninstall: database kosong
    await _clearDb();
    expect(await DBHelper.instance.getLibraryManga(), isEmpty);

    final result = await provider.importLibraryJson(backup);
    expect(result.library, 1);
    expect(result.history, 1);
    expect(result.readChapters, 2);
    expect((await DBHelper.instance.getLibraryManga()).single.title, 'Komik A');
    expect((await DBHelper.instance.getReadingHistory()).single['chapter_name'], 'Bab 5');
    expect(await DBHelper.instance.getReadChapterUrls(), {
      'https://contoh.com/komik-a/bab-4',
      'https://contoh.com/komik-a/bab-5',
    });
  });

  test('cadangan format lama (hanya pustaka) tetap bisa dipulihkan', () async {
    const oldBackup = '{"app":"KsHcans","version":"1.0.0","library":[{"title":"Lama","url":"https://contoh.com/lama","sourceId":"kiryuu"}]}';
    final result = await MangaProvider().importLibraryJson(oldBackup);
    expect(result.library, 1);
    expect(result.history, 0);
    expect((await DBHelper.instance.getLibraryManga()).single.title, 'Lama');
  });

  test('riwayat yang lebih baru di HP tidak ditimpa cadangan lama', () async {
    await DBHelper.instance.saveReadingHistory(
      mangaTitle: 'Komik B',
      mangaUrl: 'https://contoh.com/komik-b',
      sourceId: 'komiku',
      thumbnailUrl: '',
      chapterName: 'Bab 10',
      chapterUrl: 'https://contoh.com/komik-b/bab-10',
      chapterNumber: 10,
    );
    final oldBackup = jsonEncode({
      'library': [],
      'history': [
        {
          'manga_title': 'Komik B',
          'manga_url': 'https://contoh.com/komik-b',
          'chapter_name': 'Bab 2',
          'chapter_url': 'https://contoh.com/komik-b/bab-2',
          'chapter_number': 2,
          'read_at': '2020-01-01T00:00:00.000',
        },
      ],
    });
    await MangaProvider().importLibraryJson(oldBackup);
    expect((await DBHelper.instance.getReadingHistory()).single['chapter_name'], 'Bab 10');
  });

  test('file rusak atau bukan cadangan ditolak tanpa crash', () async {
    expect((await MangaProvider().importLibraryJson('bukan json')).isEmpty, isTrue);
    expect((await MangaProvider().importLibraryJson('[1,2,3]')).isEmpty, isTrue);
    expect((await MangaProvider().importLibraryJson('{"history":[{"manga_url":""}]}')).isEmpty, isTrue);
  });
}
