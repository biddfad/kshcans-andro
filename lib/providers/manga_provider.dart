import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/models/manga.dart';
import '../core/models/chapter.dart';
import '../core/database/db_helper.dart';
import '../core/services/chapter_fetcher.dart';

class MangaProvider with ChangeNotifier {
  String _selectedCategory = 'Semua';
  String _searchQuery = '';
  bool _isLoading = false;
  String _errorMessage = '';

  final List<String> _categories = [
    'Semua',
    'Favorit',
    'Sedang Dibaca',
    'Selesai',
  ];

  List<Manga> _savedLibrary = [];
  final Map<String, List<Chapter>> _chaptersCache = {};

  MangaProvider() {
    loadInitialData();
  }

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  List<String> get categories => _categories;
  bool get isLibraryEmpty => _savedLibrary.isEmpty;
  List<Manga> get savedLibrary => _savedLibrary;

  List<Manga> get libraryManga {
    final query = _searchQuery.trim().toLowerCase();
    return _savedLibrary.where((manga) {
      final matchesCategory = _selectedCategory == 'Semua' ||
          manga.category == _selectedCategory ||
          (_selectedCategory == 'Favorit' && (manga.category == 'Favorit' || manga.inLibrary)) ||
          (_selectedCategory == 'Sedang Dibaca' && manga.inLibrary);
      final matchesSearch = query.isEmpty || manga.title.toLowerCase().contains(query);

      return matchesCategory && matchesSearch;
    }).toList();
  }

  Future<void> loadInitialData() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _savedLibrary = await DBHelper.instance.getLibraryManga();
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  void searchLive(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void selectCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Menambahkan kategori pustaka kustom
  void addCustomCategory(String category) {
    final clean = category.trim();
    if (clean.isNotEmpty && !_categories.contains(clean)) {
      _categories.add(clean);
      notifyListeners();
    }
  }

  /// Memperbarui kategori komik tertentu di pustaka
  Future<void> updateMangaCategory(Manga manga, String category) async {
    manga.category = category;
    await DBHelper.instance.saveMangaToLibrary(manga);
    final idx = _savedLibrary.indexWhere((m) => m.url == manga.url);
    if (idx != -1) {
      _savedLibrary[idx] = manga;
    }
    notifyListeners();
  }

  /// Cek apakah komik sudah tersimpan di Pustaka lokal
  bool isMangaInLibrary(String mangaUrl) {
    return _savedLibrary.any((m) => m.url == mangaUrl);
  }

  /// Ekspor seluruh komik di pustaka ke format string JSON cadangan
  /// Bertambah setiap kali cadangan dipulihkan, agar layar lain memuat ulang datanya
  int _backupRestoreCount = 0;
  int get backupRestoreCount => _backupRestoreCount;

  Future<String> exportLibraryJson() async {
    final list = await DBHelper.instance.getLibraryManga();
    final history = await DBHelper.instance.getReadingHistory();
    final readChapters = await DBHelper.instance.getReadChaptersForBackup();
    final data = {
      'app': 'KsHcans',
      'version': '2',
      'date': DateTime.now().toIso8601String(),
      'total': list.length,
      'library': list.map((m) => {
        'title': m.title,
        'url': m.url,
        'sourceId': m.sourceId,
        'author': m.author,
        'description': m.description,
        'genre': m.genre,
        'status': m.status,
        'thumbnailUrl': m.thumbnailUrl,
        'category': m.category,
        'unreadCount': m.unreadCount,
      }).toList(),
      'history': history.map((h) => Map<String, dynamic>.from(h)..remove('id')).toList(),
      'readChapters': readChapters,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Impor / pulihkan pustaka, riwayat, dan bab terbaca dari teks JSON cadangan.
  /// Mendukung cadangan versi lama yang hanya berisi pustaka.
  Future<BackupImportResult> importLibraryJson(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map) return const BackupImportResult();
      final rawList = decoded['library'] as List? ?? [];
      int imported = 0;
      for (final item in rawList) {
        if (item is Map) {
          final manga = Manga(
            title: item['title']?.toString() ?? 'Tanpa Judul',
            url: item['url']?.toString() ?? '',
            sourceId: item['sourceId']?.toString() ?? 'bacakomik',
            author: item['author']?.toString() ?? '',
            description: item['description']?.toString() ?? '',
            genre: item['genre']?.toString() ?? 'Manga',
            status: item['status']?.toString() ?? 'Ongoing',
            thumbnailUrl: item['thumbnailUrl']?.toString() ?? '',
            category: item['category']?.toString() ?? 'Favorit',
            inLibrary: true,
            unreadCount: (item['unreadCount'] as num?)?.toInt() ?? 0,
          );
          if (manga.url.isNotEmpty) {
            await DBHelper.instance.saveMangaToLibrary(manga);
            if (!_savedLibrary.any((m) => m.url == manga.url)) {
              _savedLibrary.insert(0, manga);
            }
            imported++;
          }
        }
      }

      final history = <Map<String, dynamic>>[];
      for (final item in decoded['history'] as List? ?? const []) {
        if (item is! Map) continue;
        final mangaUrl = item['manga_url']?.toString() ?? '';
        final chapterUrl = item['chapter_url']?.toString() ?? '';
        final readAt = DateTime.tryParse(item['read_at']?.toString() ?? '');
        if (mangaUrl.isEmpty || chapterUrl.isEmpty || readAt == null) continue;
        history.add({
          'manga_title': item['manga_title']?.toString() ?? 'Tanpa Judul',
          'manga_url': mangaUrl,
          'source_id': item['source_id']?.toString() ?? '',
          'thumbnail_url': item['thumbnail_url']?.toString() ?? '',
          'chapter_name': item['chapter_name']?.toString() ?? '',
          'chapter_url': chapterUrl,
          'chapter_number': (item['chapter_number'] as num?)?.toDouble() ?? 0,
          'read_at': readAt.toIso8601String(),
        });
      }

      final readChapters = <Map<String, dynamic>>[];
      for (final item in decoded['readChapters'] as List? ?? const []) {
        if (item is! Map) continue;
        final url = item['chapter_url']?.toString() ?? '';
        if (url.isEmpty) continue;
        final readAt = DateTime.tryParse(item['read_at']?.toString() ?? '') ?? DateTime.now();
        readChapters.add({'chapter_url': url, 'read_at': readAt.toIso8601String()});
      }

      final historyCount = await DBHelper.instance.restoreReadingHistory(history);
      final readCount = await DBHelper.instance.restoreReadChapters(readChapters);
      _backupRestoreCount++;
      notifyListeners();
      return BackupImportResult(library: imported, history: historyCount, readChapters: readCount);
    } catch (_) {
      return const BackupImportResult();
    }
  }

  /// Segarkan pustaka langsung dari SQLite
  Future<void> refreshLibraryFromDB() async {
    _savedLibrary = await DBHelper.instance.getLibraryManga();
    notifyListeners();
  }

  Future<void> toggleLibrary(Manga manga) async {
    manga.inLibrary = !manga.inLibrary;
    if (manga.inLibrary) {
      await DBHelper.instance.saveMangaToLibrary(manga);
      if (!_savedLibrary.any((m) => m.url == manga.url)) {
        _savedLibrary.insert(0, manga);
      }
    } else {
      await DBHelper.instance.removeMangaFromLibrary(manga.url);
      _savedLibrary.removeWhere((m) => m.url == manga.url);
    }
    notifyListeners();
  }

  Future<List<Chapter>> fetchChaptersForManga(Manga manga) async {
    if (_chaptersCache.containsKey(manga.url)) {
      return _chaptersCache[manga.url]!;
    }

    try {
      final chapters = await ChapterFetcher.fetch(manga);
      if (chapters.isNotEmpty) {
        if (_savedLibrary.any((m) => m.url == manga.url)) {
          // Bab yang sudah terlihat di aplikasi tidak perlu dinotifikasi lagi
          DBHelper.instance.addKnownChapters(manga.url, chapters.map((c) => c.url));
        }
        _chaptersCache[manga.url] = chapters;
        if (manga.id != null) {
          DBHelper.instance.syncMangaChapters(manga.id!, chapters);
        }
        return chapters;
      }
    } catch (_) {}

    return [];
  }

  Future<void> refreshLibraryUnreadCounts() async {
    for (final manga in _savedLibrary) {
      try {
        final chapters = await fetchChaptersForManga(manga);
        if (manga.id != null && chapters.isNotEmpty) {
          await DBHelper.instance.syncMangaChapters(manga.id!, chapters);
        }
      } catch (_) {}
    }
    await loadInitialData();
  }

  void markChapterRead(Chapter chapter, bool isRead) {
    chapter.isRead = isRead;
    notifyListeners();
  }
}

/// Ringkasan hasil pemulihan cadangan
class BackupImportResult {
  final int library;
  final int history;
  final int readChapters;
  const BackupImportResult({this.library = 0, this.history = 0, this.readChapters = 0});

  bool get isEmpty => library == 0 && history == 0 && readChapters == 0;
}
