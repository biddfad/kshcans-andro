import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/models/chapter.dart';
import '../widgets/zoomable_page.dart';
import '../../../core/models/manga.dart';
import '../../../core/database/db_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/bacakomik_service.dart';
import '../../../core/services/doujindesu_service.dart';
import '../../../core/services/download_service.dart';
import '../../../core/services/kiryuu_service.dart';
import '../../../core/services/komiku_service.dart';
import '../../../core/services/komikindo_service.dart';
import '../../../core/services/mangadex_service.dart';
import '../../../core/services/shinigami_service.dart';
import '../../../core/services/source_config_service.dart';
import '../../../providers/manga_provider.dart';

/// Data representasi satu bab yang telah selesai dimuat
class LoadedChapter {
  final Chapter chapter;
  final int chapterIndex;
  final List<String> pages;
  final List<GlobalKey> pageKeys;
  final GlobalKey headerKey;

  LoadedChapter({
    required this.chapter,
    required this.chapterIndex,
    required this.pages,
    required this.pageKeys,
    required this.headerKey,
  });
}

/// Tipe item untuk list rendering virtualized tanpa jeda
enum ReaderItemType {
  page,
  chapterHeader,
  loadingNext,
  loadError,
  endOfManga,
}

class ReaderFlatItem {
  final ReaderItemType type;
  final LoadedChapter? chapterData;
  final int pageIndex; // 0-based
  final String? pageUrl;
  final Key? key;
  final String? errorMessage;

  ReaderFlatItem.header({required this.chapterData, required this.key})
      : type = ReaderItemType.chapterHeader,
        pageIndex = 0,
        pageUrl = null,
        errorMessage = null;

  ReaderFlatItem.page({
    required this.chapterData,
    required this.pageIndex,
    required this.pageUrl,
    required this.key,
  })  : type = ReaderItemType.page,
        errorMessage = null;

  ReaderFlatItem.loading({this.key})
      : type = ReaderItemType.loadingNext,
        chapterData = null,
        pageIndex = 0,
        pageUrl = null,
        errorMessage = null;

  ReaderFlatItem.error(this.errorMessage, {this.key})
      : type = ReaderItemType.loadError,
        chapterData = null,
        pageIndex = 0,
        pageUrl = null;

  ReaderFlatItem.endOfManga({this.key})
      : type = ReaderItemType.endOfManga,
        chapterData = null,
        pageIndex = 0,
        pageUrl = null,
        errorMessage = null;
}

class ReaderScreen extends StatefulWidget {
  final String mangaTitle;
  final Manga? manga;
  final List<Chapter> chapters;
  final int initialIndex;

  ReaderScreen({
    super.key,
    required this.mangaTitle,
    this.manga,
    List<Chapter>? chapters,
    Chapter? chapter,
    int? initialIndex,
  })  : chapters = chapters ?? (chapter != null ? [chapter] : []),
        initialIndex = initialIndex ?? 0;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  bool _showOverlay = true;
  late int _currentIndex; // Indeks bab awal atau bab dasar
  int _activeChapterIndex = 0; // Indeks bab yang sedang berada di layar
  int _activeChapterPage = 1; // Halaman aktif dalam bab yang sedang dilihat
  int _activeChapterTotalPages = 1;

  final ScrollController _scrollController = ScrollController();
  late PageController _pageController;

  // Stream bab yang telah dimuat secara berkesinambungan (Continuous Chapters)
  final List<LoadedChapter> _loadedChapters = [];
  bool _isLoadingInitial = true;
  bool _isLoadingNext = false;
  String? _nextChapterError;
  bool _hasMoreNextChapters = true;

  // Mode Membaca: 'webtoon' (vertikal bersambung), 'horizontal_rtl' (manga), 'horizontal_ltr'
  String _readingMode = 'webtoon';

  // State Auto-Scroll & Layar Penuh
  bool _isFullScreen = false;
  bool _isAutoScrolling = false;
  double _autoScrollSpeed = 1.0; // 0.5x, 1.0x, 1.5x, 2.0x, 3.0x
  Timer? _autoScrollTimer;
  bool _showSpeedControls = false;

  // Halaman sedang di-zoom (mode horizontal): kunci geser antar halaman
  bool _isPageZoomed = false;

  Chapter get currentChapter {
    if (widget.chapters.isEmpty) {
      return Chapter(mangaId: 0, url: '', name: 'Bab 1', chapterNumber: 1, dateUpload: '');
    }
    final targetIdx = _activeChapterIndex.clamp(0, widget.chapters.length - 1);
    return widget.chapters[targetIdx];
  }

  /// Header HTTP referer dinamis sesuai sumber bab
  Map<String, String> _getHeadersForChapter(Chapter ch) {
    String sourceId = widget.manga?.sourceId ?? '';
    if (sourceId.isEmpty) {
      if (ch.url.startsWith('shinigami:')) {
        sourceId = 'shinigami';
      } else if (ch.url.contains('komiku')) {
        sourceId = 'komiku';
      } else if (ch.url.contains('komikindo')) {
        sourceId = 'komikindo';
      } else if (ch.url.contains('doujindesu') || ch.url.contains('desu.')) {
        sourceId = 'doujindesu';
      } else if (ch.url.contains('kiryuu')) {
        sourceId = 'kiryuu';
      } else if (ch.url.contains('mangadex') || !ch.url.startsWith('http')) {
        sourceId = 'mangadex';
      } else {
        sourceId = 'bacakomik';
      }
    }
    return SourceConfigService.getImageHeaders(sourceId, ch.url);
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.chapters.isNotEmpty ? widget.chapters.length - 1 : 0);
    _activeChapterIndex = _currentIndex;
    _pageController = PageController();
    _scrollController.addListener(_onVerticalScroll);
    _loadPreferredReadingMode();
    _loadInitialChapter();
  }

  Future<void> _loadPreferredReadingMode() async {
    try {
      final saved = await DBHelper.instance.getSetting('reading_mode');
      if (saved != null && mounted) {
        if (saved == 'Manga Kanan-ke-Kiri') {
          setState(() => _readingMode = 'horizontal_rtl');
        } else if (saved == 'Buku Kiri-ke-Kanan') {
          setState(() => _readingMode = 'horizontal_ltr');
        } else {
          setState(() => _readingMode = 'webtoon');
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _stopAutoScroll();
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _scrollController.removeListener(_onVerticalScroll);
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      setState(() => _showOverlay = false);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _toggleAutoScroll() {
    if (_readingMode != 'webtoon') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auto-scroll hanya aktif pada mode Webtoon vertikal.')),
      );
      return;
    }

    setState(() {
      _isAutoScrolling = !_isAutoScrolling;
    });

    if (_isAutoScrolling) {
      _startAutoScroll();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Auto-Scroll Aktif (${_autoScrollSpeed}x) - Sentuh layar untuk jeda.'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      _stopAutoScroll();
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      final current = _scrollController.offset;
      if (current >= max) {
        _stopAutoScroll();
        if (mounted) setState(() => _isAutoScrolling = false);
        return;
      }
      final step = 1.2 * _autoScrollSpeed;
      _scrollController.jumpTo((current + step).clamp(0.0, max));
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _setAutoScrollSpeed(double speed) {
    setState(() {
      _autoScrollSpeed = speed;
    });
    if (_isAutoScrolling) {
      _startAutoScroll();
    }
  }

  /// Menentukan apakah urutan bab tersaji secara descending (nomor besar ke kecil)
  bool get _isDescending =>
      widget.chapters.length > 1 &&
      widget.chapters.first.chapterNumber > widget.chapters.last.chapterNumber;

  /// Index untuk bab berikutnya setelah indeks tertentu (lanjutan alur cerita)
  int? _getNextChapterIndexAfter(int idx) {
    if (widget.chapters.length <= 1) return null;
    if (_isDescending) {
      return idx > 0 ? idx - 1 : null;
    } else {
      return idx < widget.chapters.length - 1 ? idx + 1 : null;
    }
  }

  /// Index untuk bab sebelumnya
  int? _getPrevChapterIndexBefore(int idx) {
    if (widget.chapters.length <= 1) return null;
    if (_isDescending) {
      return idx < widget.chapters.length - 1 ? idx + 1 : null;
    } else {
      return idx > 0 ? idx - 1 : null;
    }
  }

  int? get nextChapterIndex => _getNextChapterIndexAfter(_activeChapterIndex);
  int? get prevChapterIndex => _getPrevChapterIndexBefore(_activeChapterIndex);

  /// Helper untuk mengambil lembaran gambar (offline atau online)
  Future<List<String>> _fetchPagesForChapter(Chapter ch) async {
    try {
      // 1. Cek penyimpanan unduhan offline
      final offline = await DownloadService.getDownloadedPages(widget.mangaTitle, ch);
      if (offline.isNotEmpty) return offline;

      // 2. Jika belum diunduh, ambil secara online
      final url = ch.url;
      if (url.startsWith('shinigami:')) {
        return await ShinigamiService.getChapterPages(url);
      } else if (url.startsWith('doujindesu:') || widget.manga?.sourceId == 'doujindesu') {
        return await DoujinDesuService.getChapterPages(url);
      } else if (url.contains('komiku') || widget.manga?.sourceId == 'komiku') {
        return await KomikuService.getChapterPages(url);
      } else if (url.contains('komikindo') || widget.manga?.sourceId == 'komikindo') {
        return await KomikIndoService.getChapterPages(url);
      } else if (url.contains('kiryuu') || widget.manga?.sourceId == 'kiryuu') {
        return await KiryuuService.getChapterPages(url);
      } else if (widget.manga?.sourceId == 'mangadex' || !url.startsWith('http')) {
        return await MangaDexService.getChapterPages(url);
      } else {
        return await BacaKomikService.getChapterPages(url);
      }
    } catch (_) {
      return [];
    }
  }

  /// Muat bab awal
  Future<void> _loadInitialChapter() async {
    setState(() {
      _isLoadingInitial = true;
      _loadedChapters.clear();
      _nextChapterError = null;
      _activeChapterIndex = _currentIndex;
      _activeChapterPage = 1;
      _activeChapterTotalPages = 1;
      _hasMoreNextChapters = true;
    });

    if (widget.chapters.isEmpty) {
      setState(() => _isLoadingInitial = false);
      return;
    }

    final targetChapter = widget.chapters[_currentIndex];
    final pages = await _fetchPagesForChapter(targetChapter);

    if (mounted) {
      if (pages.isNotEmpty) {
        final lc = LoadedChapter(
          chapter: targetChapter,
          chapterIndex: _currentIndex,
          pages: pages,
          pageKeys: List.generate(pages.length, (_) => GlobalKey()),
          headerKey: GlobalKey(),
        );

        setState(() {
          _loadedChapters.add(lc);
          _activeChapterPage = 1;
          _activeChapterTotalPages = pages.length;
          _isLoadingInitial = false;
        });

        // Cek apakah masih ada bab berikutnya dalam komik ini
        final nextIdx = _getNextChapterIndexAfter(_currentIndex);
        if (nextIdx == null) {
          setState(() => _hasMoreNextChapters = false);
        }

        // Tandai bab ini sebagai sudah dibaca
        targetChapter.isRead = true;
        DBHelper.instance.markChapterRead(targetChapter.url, true);
        context.read<MangaProvider>().markChapterRead(targetChapter, true);
        _recordHistoryForChapter(targetChapter);
      } else {
        setState(() {
          _isLoadingInitial = false;
        });
      }
    }
  }

  /// Sambungkan bab berikutnya secara otomatis di bawah tanpa interupsi
  Future<void> _loadNextChapterSection() async {
    if (_isLoadingNext || !_hasMoreNextChapters || _loadedChapters.isEmpty) return;

    final lastLoaded = _loadedChapters.last;
    final nextIdx = _getNextChapterIndexAfter(lastLoaded.chapterIndex);

    if (nextIdx == null) {
      if (mounted) {
        setState(() => _hasMoreNextChapters = false);
      }
      return;
    }

    setState(() {
      _isLoadingNext = true;
      _nextChapterError = null;
    });

    final nextChapter = widget.chapters[nextIdx];
    final pages = await _fetchPagesForChapter(nextChapter);

    if (mounted) {
      if (pages.isNotEmpty) {
        final newSection = LoadedChapter(
          chapter: nextChapter,
          chapterIndex: nextIdx,
          pages: pages,
          pageKeys: List.generate(pages.length, (_) => GlobalKey()),
          headerKey: GlobalKey(),
        );

        setState(() {
          _loadedChapters.add(newSection);
          _isLoadingNext = false;
          final furtherNextIdx = _getNextChapterIndexAfter(nextIdx);
          if (furtherNextIdx == null) {
            _hasMoreNextChapters = false;
          }
        });
      } else {
        setState(() {
          _isLoadingNext = false;
          _nextChapterError = 'Gagal memuat ${nextChapter.name}';
        });
      }
    }
  }

  /// Deteksi posisi scroll & lakukan prefetch bab berikutnya jika sisa < 1500px
  void _onVerticalScroll() {
    if (_readingMode != 'webtoon' || !_scrollController.hasClients || _loadedChapters.isEmpty) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;

    // Prefetch bab berikutnya di latar belakang
    if (!_isLoadingNext && _hasMoreNextChapters && currentScroll >= maxScroll - 1500) {
      _loadNextChapterSection();
    }

    // Deteksi bab dan halaman aktif di viewport layar
    _detectActiveChapterAndPage();
  }

  void _detectActiveChapterAndPage() {
    final viewportHeight = MediaQuery.of(context).size.height;
    final checkPoint = viewportHeight * 0.35; // 35% dari atas layar

    int? detectedChapterIdx;
    int? detectedPageNum;
    int? detectedTotalPages;
    Chapter? activeCh;

    for (final lc in _loadedChapters) {
      for (int p = 0; p < lc.pageKeys.length; p++) {
        final key = lc.pageKeys[p];
        final ctx = key.currentContext;
        if (ctx != null) {
          final box = ctx.findRenderObject() as RenderBox?;
          if (box != null && box.hasSize) {
            final pos = box.localToGlobal(Offset.zero);
            if (pos.dy <= checkPoint && pos.dy + box.size.height > checkPoint) {
              detectedChapterIdx = lc.chapterIndex;
              detectedPageNum = p + 1;
              detectedTotalPages = lc.pages.length;
              activeCh = lc.chapter;
              break;
            } else if (pos.dy > checkPoint && p == 0 && detectedChapterIdx == null) {
              detectedChapterIdx = lc.chapterIndex;
              detectedPageNum = 1;
              detectedTotalPages = lc.pages.length;
              activeCh = lc.chapter;
              break;
            }
          }
        }
      }
      if (detectedChapterIdx != null) break;
    }

    if (detectedChapterIdx != null && detectedPageNum != null && mounted) {
      final chapterChanged = detectedChapterIdx != _activeChapterIndex;
      if (chapterChanged || detectedPageNum != _activeChapterPage) {
        setState(() {
          _activeChapterIndex = detectedChapterIdx!;
          _activeChapterPage = detectedPageNum!;
          if (detectedTotalPages != null) {
            _activeChapterTotalPages = detectedTotalPages;
          }
        });

        if (chapterChanged && activeCh != null) {
          HapticFeedback.selectionClick();
          activeCh.isRead = true;
          DBHelper.instance.markChapterRead(activeCh.url, true);
          context.read<MangaProvider>().markChapterRead(activeCh, true);
          _recordHistoryForChapter(activeCh);
        }
      }
    }
  }

  Future<void> _recordHistoryForChapter(Chapter ch) async {
    // Mode Penyamaran: Lewati penyimpanan jika aktif
    final isIncognito = await DBHelper.instance.getSetting('incognito_recent');
    if (isIncognito == 'true') return;

    final source = widget.manga?.sourceId ??
        (ch.url.contains('shinigami')
            ? 'shinigami'
            : (ch.url.contains('doujindesu')
                ? 'doujindesu'
                : (ch.url.contains('komiku')
                    ? 'komiku'
                    : (ch.url.contains('komikindo')
                        ? 'komikindo'
                        : (ch.url.contains('kiryuu')
                            ? 'kiryuu'
                            : (ch.url.contains('mangadex') ? 'mangadex' : 'bacakomik'))))));
    final thumb = widget.manga?.thumbnailUrl ?? '';
    DBHelper.instance.saveReadingHistory(
      mangaTitle: widget.mangaTitle,
      mangaUrl: widget.manga?.url ?? ch.url,
      sourceId: source,
      thumbnailUrl: thumb,
      chapterName: ch.name,
      chapterUrl: ch.url,
      chapterNumber: ch.chapterNumber,
    );
  }

  void _goToChapter(int targetIndex) {
    if (targetIndex < 0 || targetIndex >= widget.chapters.length) return;

    // Cek apakah bab ini sudah ada dalam continuous stream
    final existingLoaded = _loadedChapters.indexWhere((lc) => lc.chapterIndex == targetIndex);
    if (existingLoaded != -1 && _readingMode == 'webtoon') {
      final targetKey = _loadedChapters[existingLoaded].headerKey.currentContext != null
          ? _loadedChapters[existingLoaded].headerKey
          : (_loadedChapters[existingLoaded].pageKeys.isNotEmpty
              ? _loadedChapters[existingLoaded].pageKeys.first
              : null);
      if (targetKey?.currentContext != null) {
        Scrollable.ensureVisible(
          targetKey!.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        return;
      }
    }

    // Jika belum dimuat atau lompat jauh, inisialisasi stream baru mulai dari bab target
    setState(() {
      _currentIndex = targetIndex;
      _activeChapterIndex = targetIndex;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    _loadInitialChapter();
  }

  void _showChapterListModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pilih Bab',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${widget.chapters.length} Bab',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: AppTheme.cardDark),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.chapters.length,
                  itemBuilder: (context, idx) {
                    final ch = widget.chapters[idx];
                    final isCurrent = idx == _activeChapterIndex;
                    return ListTile(
                      dense: true,
                      tileColor: isCurrent ? AppTheme.accentCyan.withValues(alpha: 0.15) : null,
                      leading: Icon(
                        isCurrent
                            ? Icons.play_circle_fill
                            : (ch.isRead ? Icons.check_circle_outline : Icons.radio_button_unchecked),
                        color: isCurrent ? AppTheme.accentCyan : (ch.isRead ? AppTheme.accentCyan : AppTheme.textMuted),
                        size: 20,
                      ),
                      title: Text(
                        ch.name,
                        style: TextStyle(
                          color: isCurrent ? AppTheme.accentCyan : (ch.isRead ? AppTheme.textMuted : Colors.white),
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: ch.dateUpload.isNotEmpty
                          ? Text(ch.dateUpload, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11))
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        if (!isCurrent) {
                          _goToChapter(idx);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReaderSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pengaturan Pembaca',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Mode Membaca',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.swap_vert, color: AppTheme.accentCyan),
                    title: const Text('Mode Webtoon (Infinity Continuous Scroll)', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Scroll ke bawah terus tanpa henti antar-bab', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    trailing: _readingMode == 'webtoon'
                        ? const Icon(Icons.check_circle, color: AppTheme.accentCyan)
                        : null,
                    onTap: () {
                      setState(() => _readingMode = 'webtoon');
                      DBHelper.instance.saveSetting('reading_mode', 'Webtoon Vertikal');
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.arrow_back, color: AppTheme.accentCyan),
                    title: const Text('Mode Manga (Geser Kanan ke Kiri / RTL)', style: TextStyle(color: Colors.white)),
                    trailing: _readingMode == 'horizontal_rtl'
                        ? const Icon(Icons.check_circle, color: AppTheme.accentCyan)
                        : null,
                    onTap: () {
                      setState(() => _readingMode = 'horizontal_rtl');
                      DBHelper.instance.saveSetting('reading_mode', 'Manga Kanan-ke-Kiri');
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.arrow_forward, color: AppTheme.accentCyan),
                    title: const Text('Mode Standar (Geser Kiri ke Kanan / LTR)', style: TextStyle(color: Colors.white)),
                    trailing: _readingMode == 'horizontal_ltr'
                        ? const Icon(Icons.check_circle, color: AppTheme.accentCyan)
                        : null,
                    onTap: () {
                      setState(() => _readingMode = 'horizontal_ltr');
                      DBHelper.instance.saveSetting('reading_mode', 'Buku Kiri-ke-Kanan');
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Flat item list untuk virtualized ListView
  List<ReaderFlatItem> get _flatItems {
    final List<ReaderFlatItem> items = [];
    for (int c = 0; c < _loadedChapters.length; c++) {
      final lc = _loadedChapters[c];
      // Jika bukan bab pertama di atas, tambahkan Chapter Transition Header
      if (c > 0) {
        items.add(ReaderFlatItem.header(chapterData: lc, key: lc.headerKey));
      }
      for (int p = 0; p < lc.pages.length; p++) {
        items.add(ReaderFlatItem.page(
          chapterData: lc,
          pageIndex: p,
          pageUrl: lc.pages[p],
          key: lc.pageKeys[p],
        ));
      }
    }

    // Status tambahan di bagian paling bawah
    if (_isLoadingNext) {
      items.add(ReaderFlatItem.loading(key: const ValueKey('loading_next_indicator')));
    } else if (_nextChapterError != null) {
      items.add(ReaderFlatItem.error(_nextChapterError, key: const ValueKey('error_retry_card')));
    } else if (!_hasMoreNextChapters && _loadedChapters.isNotEmpty) {
      items.add(ReaderFlatItem.endOfManga(key: const ValueKey('end_of_manga_card')));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Kanvas Lembaran Komik
          if (_isLoadingInitial)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.accentCyan),
                  SizedBox(height: 16),
                  Text(
                    'Mengambil lembaran komik asli...',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            )
          else if (_loadedChapters.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image, size: 64, color: AppTheme.textMuted),
                  const SizedBox(height: 16),
                  const Text(
                    'Tidak dapat memuat lembaran komik dari sumber',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentCyan,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: _loadInitialChapter,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba Lagi'),
                  ),
                ],
              ),
            )
          else
            GestureDetector(
              onTap: () {
                if (_isAutoScrolling) {
                  _stopAutoScroll();
                  setState(() => _isAutoScrolling = false);
                  return;
                }
                setState(() {
                  _showOverlay = !_showOverlay;
                });
              },
              child: _buildReaderContent(),
            ),

          // Top Overlay Menu (App Bar Reader)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: _showOverlay ? 0 : -100,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withValues(alpha: 0.88),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.mangaTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            currentChapter.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.accentCyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                        color: _isFullScreen ? AppTheme.accentCyan : Colors.white,
                      ),
                      tooltip: _isFullScreen ? 'Keluar Layar Penuh' : 'Layar Penuh Sejati',
                      onPressed: _toggleFullScreen,
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_list_bulleted, color: Colors.white),
                      tooltip: 'Daftar Bab',
                      onPressed: _showChapterListModal,
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      tooltip: 'Pengaturan Pembaca',
                      onPressed: _showReaderSettings,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Overlay Menu (Navigasi Bab & Halaman)
          if (_loadedChapters.isNotEmpty)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              bottom: _showOverlay ? 0 : -140,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black.withValues(alpha: 0.88),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Baris 1: Tombol Cepat Pindah Bab
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: prevChapterIndex != null ? Colors.white : Colors.white24,
                                side: BorderSide(color: prevChapterIndex != null ? Colors.white30 : Colors.white12),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              icon: const Icon(Icons.arrow_back_ios, size: 14),
                              label: const Text('Bab Sblmnya', style: TextStyle(fontSize: 12)),
                              onPressed: prevChapterIndex != null ? () => _goToChapter(prevChapterIndex!) : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: nextChapterIndex != null ? AppTheme.accentCyan : AppTheme.cardDark,
                                foregroundColor: nextChapterIndex != null ? Colors.black : Colors.white30,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              icon: const Icon(Icons.arrow_forward_ios, size: 14),
                              label: const Text(
                                'Bab Berikutnya',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              onPressed: nextChapterIndex != null ? () => _goToChapter(nextChapterIndex!) : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Baris 2: Indikator Halaman & Slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${currentChapter.name} • Hal $_activeChapterPage / $_activeChapterTotalPages',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentCyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _readingMode == 'webtoon'
                                  ? 'Infinity Scroll'
                                  : (_readingMode == 'horizontal_rtl' ? 'Manga (RTL)' : 'Standar (LTR)'),
                              style: const TextStyle(color: AppTheme.accentCyan, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _activeChapterPage.clamp(1, _activeChapterTotalPages).toDouble(),
                        min: 1,
                        max: _activeChapterTotalPages.toDouble(),
                        activeColor: AppTheme.accentCyan,
                        inactiveColor: AppTheme.cardDark,
                        onChanged: (val) {
                          final page = val.toInt();
                          setState(() {
                            _activeChapterPage = page;
                          });
                          if (_readingMode == 'webtoon') {
                            final currentLoaded = _loadedChapters.firstWhere(
                              (lc) => lc.chapterIndex == _activeChapterIndex,
                              orElse: () => _loadedChapters.first,
                            );
                            if (page - 1 < currentLoaded.pageKeys.length &&
                                currentLoaded.pageKeys[page - 1].currentContext != null) {
                              Scrollable.ensureVisible(
                                currentLoaded.pageKeys[page - 1].currentContext!,
                                alignment: 0.0,
                                duration: const Duration(milliseconds: 200),
                              );
                            }
                          } else {
                            if (_pageController.hasClients) {
                              _pageController.jumpToPage(page - 1);
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Floating Auto-Scroll Controls (Hanya pada mode Webtoon)
          if (_readingMode == 'webtoon' && _loadedChapters.isNotEmpty)
            Positioned(
              bottom: _showOverlay ? 145 : 24,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Pop-up bar pilihan kecepatan
                  if (_showSpeedControls)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [0.5, 1.0, 1.5, 2.0, 3.0].map((spd) {
                          final isSel = _autoScrollSpeed == spd;
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _setAutoScrollSpeed(spd),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSel ? AppTheme.accentCyan : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${spd}x',
                                style: TextStyle(
                                  color: isSel ? Colors.black : Colors.white,
                                  fontSize: 11,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  // Tombol Utama Floating Auto-Scroll
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            setState(() {
                              _showSpeedControls = !_showSpeedControls;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.cardDark.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              '${_autoScrollSpeed}x',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      FloatingActionButton.small(
                        heroTag: 'auto_scroll_btn',
                        backgroundColor:
                            _isAutoScrolling ? AppTheme.accentCyan : AppTheme.cardDark.withValues(alpha: 0.9),
                        foregroundColor: _isAutoScrolling ? Colors.black : Colors.white,
                        elevation: 4,
                        onPressed: _toggleAutoScroll,
                        tooltip: _isAutoScrolling ? 'Hentikan Auto-Scroll' : 'Mulai Auto-Scroll',
                        child: Icon(_isAutoScrolling ? Icons.pause : Icons.play_arrow),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReaderContent() {
    if (_readingMode == 'webtoon') {
      final items = _flatItems;
      return ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          switch (item.type) {
            case ReaderItemType.chapterHeader:
              return _buildChapterTransitionHeader(item.chapterData!.chapter, key: item.key);
            case ReaderItemType.page:
              final headers = _getHeadersForChapter(item.chapterData!.chapter);
              return _buildPageImage(item.pageUrl!, item.pageIndex, headers: headers, key: item.key);
            case ReaderItemType.loadingNext:
              return _buildLoadingNextIndicator(key: item.key);
            case ReaderItemType.loadError:
              return _buildLoadErrorCard(item.errorMessage ?? 'Gagal memuat bab', key: item.key);
            case ReaderItemType.endOfManga:
              return _buildEndOfMangaCard(key: item.key);
          }
        },
      );
    } else {
      // Horizontal mode (RTL atau LTR) untuk bab aktif
      final isRtl = _readingMode == 'horizontal_rtl';
      final activeLoaded = _loadedChapters.firstWhere(
        (lc) => lc.chapterIndex == _activeChapterIndex,
        orElse: () => _loadedChapters.isNotEmpty
            ? _loadedChapters.first
            : LoadedChapter(
                chapter: currentChapter,
                chapterIndex: _activeChapterIndex,
                pages: [],
                pageKeys: [],
                headerKey: GlobalKey(),
              ),
      );
      final activePages = activeLoaded.pages;
      final headers = _getHeadersForChapter(activeLoaded.chapter);

      return PageView.builder(
        controller: _pageController,
        reverse: isRtl,
        // Saat halaman di-zoom, geser dipakai untuk menggeser gambar, bukan pindah halaman
        physics: _isPageZoomed ? const NeverScrollableScrollPhysics() : null,
        itemCount: activePages.length + 1,
        onPageChanged: (index) {
          setState(() {
            _activeChapterPage = (index + 1).clamp(1, activePages.isNotEmpty ? activePages.length : 1);
          });
        },
        itemBuilder: (context, index) {
          if (index == activePages.length) {
            return Center(child: _buildEndOfChapterCard());
          }
          return Center(
            child: _buildPageImage(
              activePages[index],
              index,
              headers: headers,
              fit: BoxFit.contain,
              key: index < activeLoaded.pageKeys.length ? activeLoaded.pageKeys[index] : null,
            ),
          );
        },
      );
    }
  }

  /// Banner pemisah transisi bab yang elegan saat scroll ke bab selanjutnya
  Widget _buildChapterTransitionHeader(Chapter chapter, {Key? key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accentCyan.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentCyan.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_downward, size: 14, color: AppTheme.accentCyan),
                    SizedBox(width: 6),
                    Text(
                      'Bab Berikutnya Tersambung',
                      style: TextStyle(
                        color: AppTheme.accentCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            chapter.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Lanjutkan gulir ke bawah untuk membaca bab ini',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  /// Indikator loading halus di akhir scroll saat mengambil bab selanjutnya
  Widget _buildLoadingNextIndicator({Key? key}) {
    final hasNext = nextChapterIndex != null;
    final nextCh = hasNext ? widget.chapters[nextChapterIndex!] : null;
    final nextTitle = nextCh != null ? nextCh.name : 'Bab Selanjutnya';

    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.accentCyan,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Menyambungkan $nextTitle...',
              style: const TextStyle(color: AppTheme.accentCyan, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Halaman otomatis tersambung tanpa perlu diklik',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  /// Banner jika koneksi gagal saat menyambung bab berikutnya
  Widget _buildLoadErrorCard(String errorMsg, {Key? key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, color: Colors.redAccent, size: 36),
          const SizedBox(height: 10),
          Text(
            errorMsg,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Koneksi internet bermasalah saat menyambung bab selanjutnya.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCyan,
              foregroundColor: Colors.black,
            ),
            onPressed: _loadNextChapterSection,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Coba Sambung Lagi'),
          ),
        ],
      ),
    );
  }

  /// Banner selebrasi ketika seluruh bab komik telah selesai dibaca
  Widget _buildEndOfMangaCard({Key? key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.accentCyan.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.celebration, color: AppTheme.accentCyan, size: 48),
          ),
          const SizedBox(height: 16),
          const Text(
            'Bab Terakhir Tercapai!',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Selamat! Anda telah selesai membaca seluruh bab yang tersedia untuk komik ini. Nantikan bab terbaru selanjutnya saat dirilis!',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Kembali ke Menu Komik', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Rendering lembaran gambar dengan proteksi OOM memori (1080p decode) dan gesture pinch-to-zoom
  Widget _buildPageImage(
    String pathOrUrl,
    int index, {
    required Map<String, String> headers,
    BoxFit fit = BoxFit.fitWidth,
    Key? key,
  }) {
    Widget imageWidget;
    // Jika file tersimpan lokal (unduhan offline)
    if (pathOrUrl.startsWith('/') || pathOrUrl.startsWith('file:') || File(pathOrUrl).existsSync()) {
      final localFile = File(pathOrUrl.replaceFirst('file://', ''));
      imageWidget = Image.file(
        localFile,
        fit: fit,
        cacheWidth: 1080,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 300,
          color: AppTheme.cardDark,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
                const SizedBox(height: 8),
                Text(
                  'Gagal memuat file offline hal. ${index + 1}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      imageWidget = CachedNetworkImage(
        imageUrl: pathOrUrl,
        fit: fit,
        memCacheWidth: 1080,
        httpHeaders: headers,
        placeholder: (context, url) => Container(
          height: 480,
          color: AppTheme.surfaceDark,
          child: const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.accentCyan,
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          height: 320,
          color: AppTheme.cardDark,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image, color: Colors.redAccent, size: 32),
                const SizedBox(height: 8),
                Text(
                  'Gagal memuat hal. ${index + 1}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ZoomablePage(
      key: key,
      onZoomChanged: _readingMode == 'webtoon'
          ? null
          : (zoomed) {
              if (mounted && _isPageZoomed != zoomed) setState(() => _isPageZoomed = zoomed);
            },
      child: imageWidget,
    );
  }

  /// Kartu transisi akhir bab (khusus untuk mode PageView horizontal)
  Widget _buildEndOfChapterCard() {
    final hasNext = nextChapterIndex != null;
    final nextChapter = hasNext ? widget.chapters[nextChapterIndex!] : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, color: AppTheme.accentCyan, size: 52),
          const SizedBox(height: 12),
          Text(
            '${currentChapter.name} Selesai!',
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            hasNext ? 'Lanjut membaca bab selanjutnya:' : 'Selamat! Anda sudah membaca bab paling baru.',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (hasNext && nextChapter != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.arrow_forward),
                label: Text(
                  'Lanjut: ${nextChapter.name}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _goToChapter(nextChapterIndex!),
              ),
            )
          else
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Kembali ke Menu Komik'),
              onPressed: () => Navigator.pop(context),
            ),
        ],
      ),
    );
  }
}
