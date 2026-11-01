import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/manga.dart';
import '../models/chapter.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('komik_reader.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    final db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createDB(db, version);
        await _createReadingHistoryTable(db);
        await _createReadChaptersTable(db);
        await _createSettingsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createReadingHistoryTable(db);
        await _createReadChaptersTable(db);
        await _createSettingsTable(db);
      },
    );

    await _createReadingHistoryTable(db);
    await _createReadChaptersTable(db);
    await _createSettingsTable(db);
    await _createKnownChaptersTable(db);
    return db;
  }

  Future<void> _createReadChaptersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS read_chapters (
        chapter_url TEXT PRIMARY KEY,
        read_at TEXT NOT NULL
      )
    ''');
  }

  /// Bab yang sudah pernah dilihat per komik, untuk mendeteksi bab baru (notifikasi)
  Future<void> _createKnownChaptersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS known_chapters (
        manga_url TEXT NOT NULL,
        chapter_url TEXT NOT NULL,
        PRIMARY KEY (manga_url, chapter_url)
      )
    ''');
  }

  Future<void> _createSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createReadingHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reading_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        manga_title TEXT NOT NULL,
        manga_url TEXT NOT NULL,
        source_id TEXT NOT NULL,
        thumbnail_url TEXT NOT NULL,
        chapter_name TEXT NOT NULL,
        chapter_url TEXT NOT NULL,
        chapter_number REAL NOT NULL,
        read_at TEXT NOT NULL,
        UNIQUE (manga_url)
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_history_read_at ON reading_history (read_at DESC)');
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE manga (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_id TEXT NOT NULL,
        url TEXT NOT NULL,
        title TEXT NOT NULL,
        author TEXT,
        description TEXT,
        genre TEXT,
        status TEXT,
        thumbnail_url TEXT,
        in_library INTEGER NOT NULL DEFAULT 0,
        category TEXT DEFAULT 'Default',
        UNIQUE (source_id, url)
      )
    ''');

    await db.execute('''
      CREATE TABLE chapters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        manga_id INTEGER NOT NULL,
        url TEXT NOT NULL,
        name TEXT NOT NULL,
        chapter_number REAL NOT NULL,
        date_upload TEXT,
        is_read INTEGER NOT NULL DEFAULT 0,
        last_page_read INTEGER NOT NULL DEFAULT 0,
        is_downloaded INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (manga_id) REFERENCES manga (id) ON DELETE CASCADE,
        UNIQUE (manga_id, url)
      )
    ''');

    await db.execute('''
      CREATE TABLE history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chapter_id INTEGER NOT NULL UNIQUE,
        last_read_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (chapter_id) REFERENCES chapters (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_manga_library ON manga (in_library, title)');
    await db.execute('CREATE INDEX idx_chapters_manga ON chapters (manga_id, chapter_number DESC)');
  }

  Future<int> insertManga(Manga manga) async {
    final db = await instance.database;
    return await db.insert(
      'manga',
      manga.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Manga>> getLibraryManga() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT m.*,
        (SELECT COUNT(*) FROM chapters c WHERE c.manga_id = m.id AND c.is_read = 0) as unread_count
      FROM manga m
      WHERE m.in_library = 1
      ORDER BY m.title ASC
    ''');
    return result.map((json) => Manga.fromMap(json)).toList();
  }

  Future<int> toggleLibraryStatus(int id, bool inLibrary) async {
    final db = await instance.database;
    return await db.update(
      'manga',
      {'in_library': inLibrary ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> saveMangaToLibrary(Manga manga) async {
    final db = await instance.database;
    await db.insert(
      'manga',
      {
        'source_id': manga.sourceId,
        'url': manga.url,
        'title': manga.title,
        'author': manga.author,
        'description': manga.description,
        'genre': manga.genre,
        'status': manga.status,
        'thumbnail_url': manga.thumbnailUrl,
        'in_library': 1,
        'category': manga.category,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeMangaFromLibrary(String url) async {
    final db = await instance.database;
    await db.update(
      'manga',
      {'in_library': 0},
      where: 'url = ?',
      whereArgs: [url],
    );
  }

  Future<bool> isMangaInLibrary(String url) async {
    final db = await instance.database;
    final res = await db.query(
      'manga',
      where: 'url = ? AND in_library = 1',
      whereArgs: [url],
      limit: 1,
    );
    return res.isNotEmpty;
  }

  Future<void> setChapterDownloaded(String chapterUrl, bool isDownloaded) async {
    final db = await instance.database;
    await db.rawUpdate('''
      UPDATE chapters SET is_downloaded = ? WHERE url = ?
    ''', [isDownloaded ? 1 : 0, chapterUrl]);
  }

  Future<void> resetAllDownloads() async {
    final db = await instance.database;
    await db.rawUpdate('UPDATE chapters SET is_downloaded = 0');
  }

  Future<void> saveReadingHistory({
    required String mangaTitle,
    required String mangaUrl,
    required String sourceId,
    required String thumbnailUrl,
    required String chapterName,
    required String chapterUrl,
    required double chapterNumber,
  }) async {
    final db = await instance.database;
    await db.insert(
      'reading_history',
      {
        'manga_title': mangaTitle,
        'manga_url': mangaUrl,
        'source_id': sourceId,
        'thumbnail_url': thumbnailUrl,
        'chapter_name': chapterName,
        'chapter_url': chapterUrl,
        'chapter_number': chapterNumber,
        'read_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getReadingHistory() async {
    try {
      final db = await instance.database;
      return await db.query(
        'reading_history',
        orderBy: 'read_at DESC',
      );
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteHistoryItem(String mangaUrl) async {
    try {
      final db = await instance.database;
      await db.delete(
        'reading_history',
        where: 'manga_url = ?',
        whereArgs: [mangaUrl],
      );
    } catch (_) {}
  }

  Future<void> clearReadingHistory() async {
    try {
      final db = await instance.database;
      await db.delete('reading_history');
    } catch (_) {}
  }

  Future<void> markChapterRead(String chapterUrl, bool isRead) async {
    try {
      final db = await instance.database;
      if (isRead) {
        await db.insert(
          'read_chapters',
          {
            'chapter_url': chapterUrl,
            'read_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        await db.delete(
          'read_chapters',
          where: 'chapter_url = ?',
          whereArgs: [chapterUrl],
        );
      }
      await db.rawUpdate('UPDATE chapters SET is_read = ? WHERE url = ?', [isRead ? 1 : 0, chapterUrl]);
    } catch (_) {}
  }

  Future<void> markMultipleChaptersRead(List<String> chapterUrls, bool isRead) async {
    try {
      final db = await instance.database;
      final batch = db.batch();
      for (final url in chapterUrls) {
        if (isRead) {
          batch.insert(
            'read_chapters',
            {
              'chapter_url': url,
              'read_at': DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } else {
          batch.delete(
            'read_chapters',
            where: 'chapter_url = ?',
            whereArgs: [url],
          );
        }
        batch.rawUpdate('UPDATE chapters SET is_read = ? WHERE url = ?', [isRead ? 1 : 0, url]);
      }
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  Future<void> syncMangaChapters(int mangaId, List<Chapter> chapters) async {
    try {
      final db = await instance.database;
      final readUrls = await getReadChapterUrls();
      final batch = db.batch();
      for (final ch in chapters) {
        final isRead = readUrls.contains(ch.url) || ch.isRead;
        batch.rawInsert('''
          INSERT INTO chapters (manga_id, url, name, chapter_number, date_upload, is_read, is_downloaded)
          VALUES (?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(manga_id, url) DO UPDATE SET
            name = excluded.name,
            chapter_number = excluded.chapter_number,
            date_upload = excluded.date_upload,
            is_read = CASE WHEN chapters.is_read = 1 THEN 1 ELSE excluded.is_read END
        ''', [
          mangaId,
          ch.url,
          ch.name,
          ch.chapterNumber,
          ch.dateUpload,
          isRead ? 1 : 0,
          ch.isDownloaded ? 1 : 0,
        ]);
      }
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  Future<Set<String>> getReadChapterUrls() async {
    try {
      final db = await instance.database;
      final results = await db.query('read_chapters', columns: ['chapter_url']);
      return results.map((row) => row['chapter_url'] as String).toSet();
    } catch (_) {
      return {};
    }
  }

  /// Seluruh bab yang sudah dibaca beserta waktunya (untuk file cadangan)
  Future<List<Map<String, dynamic>>> getReadChaptersForBackup() async {
    final db = await instance.database;
    return await db.query('read_chapters');
  }

  /// Pulihkan bab terbaca dari cadangan tanpa menimpa data yang sudah ada
  Future<int> restoreReadChapters(List<Map<String, dynamic>> rows) async {
    final db = await instance.database;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert('read_chapters', row, conflictAlgorithm: ConflictAlgorithm.ignore);
      batch.rawUpdate('UPDATE chapters SET is_read = 1 WHERE url = ?', [row['chapter_url']]);
    }
    await batch.commit(noResult: true);
    return rows.length;
  }

  /// Pulihkan riwayat bacaan; per komik hanya entri yang lebih baru yang disimpan
  Future<int> restoreReadingHistory(List<Map<String, dynamic>> rows) async {
    final db = await instance.database;
    final existing = {
      for (final row in await db.query('reading_history', columns: ['manga_url', 'read_at']))
        row['manga_url'] as String: row['read_at'] as String,
    };
    final batch = db.batch();
    var restored = 0;
    for (final row in rows) {
      final current = existing[row['manga_url']];
      if (current != null && current.compareTo(row['read_at'] as String) >= 0) continue;
      batch.insert('reading_history', row, conflictAlgorithm: ConflictAlgorithm.replace);
      restored++;
    }
    await batch.commit(noResult: true);
    return restored;
  }

  Future<Set<String>> getKnownChapterUrls(String mangaUrl) async {
    final db = await instance.database;
    final rows = await db.query(
      'known_chapters',
      columns: ['chapter_url'],
      where: 'manga_url = ?',
      whereArgs: [mangaUrl],
    );
    return rows.map((row) => row['chapter_url'] as String).toSet();
  }

  Future<void> addKnownChapters(String mangaUrl, Iterable<String> chapterUrls) async {
    final db = await instance.database;
    final batch = db.batch();
    for (final url in chapterUrls) {
      batch.insert(
        'known_chapters',
        {'manga_url': mangaUrl, 'chapter_url': url},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<String?> getSetting(String key, {String? defaultValue}) async {
    try {
      final db = await instance.database;
      final result = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (result.isNotEmpty) {
        return result.first['value'] as String?;
      }
    } catch (_) {}
    return defaultValue;
  }

  Future<void> saveSetting(String key, String value) async {
    try {
      final db = await instance.database;
      await db.insert(
        'app_settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }
}
