import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/models/manga.dart';
import '../core/models/chapter.dart';
import '../core/database/db_helper.dart';
import '../core/services/bacakomik_service.dart';
import '../core/services/doujindesu_service.dart';
import '../core/services/kiryuu_service.dart';
import '../core/services/komiku_service.dart';
import '../core/services/komikindo_service.dart';
import '../core/services/mangadex_service.dart';
import '../core/services/shinigami_service.dart';

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
  Future<String> exportLibraryJson() async {
    final list = await DBHelper.instance.getLibraryManga();
    final data = {
      'app': 'KsHcans',
      'version': '1.0.0',
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
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Impor / pulihkan komik dari teks JSON cadangan ke database SQLite
  Future<int> importLibraryJson(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString);
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
      notifyListeners();
      return imported;
    } catch (_) {
      return 0;
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
      List<Chapter> chapters = [];
      if (manga.sourceId == 'shinigami') {
        chapters = await ShinigamiService.getMangaChapters(manga.url);
      } else if (manga.sourceId == 'mangadex') {
        chapters = await MangaDexService.getMangaChapters(manga.url);
      } else if (manga.sourceId == 'kiryuu') {
        final details = await KiryuuService.getMangaDetails(manga.url);
        chapters = details['chapters'] ?? [];
      } else if (manga.sourceId == 'doujindesu') {
        final details = await DoujinDesuService.getMangaDetails(manga.url);
        chapters = details['chapters'] ?? [];
      } else if (manga.sourceId == 'komiku') {
        final details = await KomikuService.getMangaDetails(manga.url);
        chapters = details['chapters'] ?? [];
      } else if (manga.sourceId == 'komikindo') {
        final details = await KomikIndoService.getMangaDetails(manga.url);
        chapters = details['chapters'] ?? [];
      } else {
        final details = await BacaKomikService.getMangaDetails(manga.url);
        chapters = details['chapters'] ?? [];
      }

      if (chapters.isNotEmpty) {
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
