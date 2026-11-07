import 'package:flutter/material.dart';
import '../../../core/models/manga.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/bacakomik_service.dart';
import '../../../core/services/doujindesu_service.dart';
import '../../../core/services/ikiru_service.dart';
import '../../../core/services/kiryuu_service.dart';
import '../../../core/services/komiku_service.dart';
import '../../../core/services/komikindo_service.dart';
import '../../../core/services/luvyaa_service.dart';
import '../../../core/services/mangadex_service.dart';
import '../../../core/services/shinigami_service.dart';
import '../../../core/widgets/source_logo.dart';
import '../../library/widgets/manga_card.dart';

class SourceCatalogScreen extends StatefulWidget {
  final String sourceId;
  final String sourceName;

  const SourceCatalogScreen({
    super.key,
    required this.sourceId,
    required this.sourceName,
  });

  @override
  State<SourceCatalogScreen> createState() => _SourceCatalogScreenState();
}

class _SourceCatalogScreenState extends State<SourceCatalogScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Data komik per tab & pencarian
  List<Manga> _popularManga = [];
  List<Manga> _latestManga = [];
  List<Manga> _searchManga = [];

  // Status loading awal
  bool _isLoadingPopular = true;
  bool _isLoadingLatest = true;
  bool _isSearching = false;
  bool _isSearchLoading = false;

  // Infinite Scroll & Paginasi State
  int _popularPage = 1;
  bool _isLoadingMorePopular = false;
  bool _hasMorePopular = true;
  final ScrollController _popularScrollController = ScrollController();

  int _latestPage = 1;
  bool _isLoadingMoreLatest = false;
  bool _hasMoreLatest = true;
  final ScrollController _latestScrollController = ScrollController();

  int _searchPage = 1;
  bool _isLoadingMoreSearch = false;
  bool _hasMoreSearch = true;
  String _activeSearchQuery = '';
  final ScrollController _searchScrollController = ScrollController();

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _popularScrollController.addListener(_onPopularScroll);
    _latestScrollController.addListener(_onLatestScroll);
    _searchScrollController.addListener(_onSearchScroll);

    _loadData();
  }

  void _onPopularScroll() {
    if (_popularScrollController.position.pixels >= _popularScrollController.position.maxScrollExtent - 300) {
      _loadMorePopular();
    }
  }

  void _onLatestScroll() {
    if (_latestScrollController.position.pixels >= _latestScrollController.position.maxScrollExtent - 300) {
      _loadMoreLatest();
    }
  }

  void _onSearchScroll() {
    if (_searchScrollController.position.pixels >= _searchScrollController.position.maxScrollExtent - 300) {
      _loadMoreSearch();
    }
  }

  Future<void> _loadData() async {
    _loadPopular();
    _loadLatest();
  }

  Future<List<Manga>> _fetchFromSource({
    required String mode,
    required int page,
    String query = '',
  }) async {
    try {
      if (widget.sourceId == 'komiku') {
        if (mode == 'popular') return await KomikuService.getPopularManga(page: page);
        if (mode == 'latest') return await KomikuService.getLatestUpdates(page: page);
        return await KomikuService.searchManga(query, page: page);
      } else if (widget.sourceId == 'komikindo') {
        if (mode == 'popular') return await KomikIndoService.getPopularManga(page: page);
        if (mode == 'latest') return await KomikIndoService.getLatestUpdates(page: page);
        return await KomikIndoService.searchManga(query, page: page);
      } else if (widget.sourceId == 'shinigami') {
        if (mode == 'popular') return await ShinigamiService.getPopularManga(page: page);
        if (mode == 'latest') return await ShinigamiService.getLatestUpdates(page: page);
        return await ShinigamiService.searchManga(query, page: page);
      } else if (widget.sourceId == 'doujindesu') {
        if (mode == 'popular') return await DoujinDesuService.getPopularManga(page: page);
        if (mode == 'latest') return await DoujinDesuService.getLatestUpdates(page: page);
        return await DoujinDesuService.searchManga(query, page: page);
      } else if (widget.sourceId == 'mangadex') {
        if (mode == 'popular') return await MangaDexService.getPopularManga(page: page);
        if (mode == 'latest') return await MangaDexService.getLatestUpdates(page: page);
        return await MangaDexService.searchManga(query, page: page);
      } else if (widget.sourceId == 'kiryuu') {
        if (mode == 'popular') return await KiryuuService.getPopularManga(page: page);
        if (mode == 'latest') return await KiryuuService.getLatestUpdates(page: page);
        return await KiryuuService.searchManga(query, page: page);
      } else if (widget.sourceId == 'ikiru') {
        if (mode == 'popular') return await IkiruService.getPopularManga(page: page);
        if (mode == 'latest') return await IkiruService.getLatestUpdates(page: page);
        return await IkiruService.searchManga(query, page: page);
      } else if (widget.sourceId == 'luvyaa') {
        if (mode == 'popular') return await LuvyaaService.getPopularManga(page: page);
        if (mode == 'latest') return await LuvyaaService.getLatestUpdates(page: page);
        return await LuvyaaService.searchManga(query, page: page);
      } else {
        if (mode == 'popular') return await BacaKomikService.getPopularManga(page: page);
        if (mode == 'latest') return await BacaKomikService.getLatestUpdates(page: page);
        return await BacaKomikService.searchManga(query, page: page);
      }
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadPopular() async {
    setState(() {
      _isLoadingPopular = true;
      _popularPage = 1;
      _hasMorePopular = true;
    });

    final result = await _fetchFromSource(mode: 'popular', page: 1);

    if (mounted) {
      setState(() {
        _popularManga = result;
        _isLoadingPopular = false;
        if (result.isEmpty || result.length < 10) {
          _hasMorePopular = false;
        }
      });
    }
  }

  Future<void> _loadMorePopular() async {
    if (_isLoadingPopular || _isLoadingMorePopular || !_hasMorePopular) return;

    setState(() => _isLoadingMorePopular = true);

    final nextPage = _popularPage + 1;
    final nextItems = await _fetchFromSource(mode: 'popular', page: nextPage);

    if (mounted) {
      setState(() {
        if (nextItems.isEmpty) {
          _hasMorePopular = false;
        } else {
          final existingUrls = _popularManga.map((m) => m.url).toSet();
          final uniqueNew = nextItems.where((m) => !existingUrls.contains(m.url)).toList();
          if (uniqueNew.isEmpty) {
            _hasMorePopular = false;
          } else {
            _popularManga.addAll(uniqueNew);
            _popularPage = nextPage;
            if (nextItems.length < 10) {
              _hasMorePopular = false;
            }
          }
        }
        _isLoadingMorePopular = false;
      });
    }
  }

  Future<void> _loadLatest() async {
    setState(() {
      _isLoadingLatest = true;
      _latestPage = 1;
      _hasMoreLatest = true;
    });

    final result = await _fetchFromSource(mode: 'latest', page: 1);

    if (mounted) {
      setState(() {
        _latestManga = result;
        _isLoadingLatest = false;
        if (result.isEmpty || result.length < 10) {
          _hasMoreLatest = false;
        }
      });
    }
  }

  Future<void> _loadMoreLatest() async {
    if (_isLoadingLatest || _isLoadingMoreLatest || !_hasMoreLatest) return;

    setState(() => _isLoadingMoreLatest = true);

    final nextPage = _latestPage + 1;
    final nextItems = await _fetchFromSource(mode: 'latest', page: nextPage);

    if (mounted) {
      setState(() {
        if (nextItems.isEmpty) {
          _hasMoreLatest = false;
        } else {
          final existingUrls = _latestManga.map((m) => m.url).toSet();
          final uniqueNew = nextItems.where((m) => !existingUrls.contains(m.url)).toList();
          if (uniqueNew.isEmpty) {
            _hasMoreLatest = false;
          } else {
            _latestManga.addAll(uniqueNew);
            _latestPage = nextPage;
            if (nextItems.length < 10) {
              _hasMoreLatest = false;
            }
          }
        }
        _isLoadingMoreLatest = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    setState(() {
      _isSearchLoading = true;
      _activeSearchQuery = cleanQuery;
      _searchPage = 1;
      _hasMoreSearch = true;
    });

    final result = await _fetchFromSource(mode: 'search', page: 1, query: cleanQuery);

    if (mounted) {
      setState(() {
        _searchManga = result;
        _isSearchLoading = false;
        if (result.isEmpty || result.length < 10) {
          _hasMoreSearch = false;
        }
      });
    }
  }

  Future<void> _loadMoreSearch() async {
    if (_isSearchLoading || _isLoadingMoreSearch || !_hasMoreSearch || _activeSearchQuery.isEmpty) return;

    setState(() => _isLoadingMoreSearch = true);

    final nextPage = _searchPage + 1;
    final nextItems = await _fetchFromSource(mode: 'search', page: nextPage, query: _activeSearchQuery);

    if (mounted) {
      setState(() {
        if (nextItems.isEmpty) {
          _hasMoreSearch = false;
        } else {
          final existingUrls = _searchManga.map((m) => m.url).toSet();
          final uniqueNew = nextItems.where((m) => !existingUrls.contains(m.url)).toList();
          if (uniqueNew.isEmpty) {
            _hasMoreSearch = false;
          } else {
            _searchManga.addAll(uniqueNew);
            _searchPage = nextPage;
            if (nextItems.length < 10) {
              _hasMoreSearch = false;
            }
          }
        }
        _isLoadingMoreSearch = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _popularScrollController.dispose();
    _latestScrollController.dispose();
    _searchScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Cari di ${widget.sourceName}...',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  border: InputBorder.none,
                ),
                onSubmitted: (val) => _performSearch(val),
              )
            : Row(
                children: [
                  SourceLogo(sourceId: widget.sourceId, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.sourceName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchManga.clear();
                  _activeSearchQuery = '';
                }
              });
            },
          ),
        ],
        bottom: _isSearching
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.accentCyan,
                labelColor: AppTheme.accentCyan,
                unselectedLabelColor: AppTheme.textMuted,
                tabs: const [
                  Tab(text: 'Populer'),
                  Tab(text: 'Terbaru (Rilis Baru)'),
                ],
              ),
      ),
      body: _isSearching
          ? _buildSearchBody()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMangaGrid(
                  list: _popularManga,
                  loading: _isLoadingPopular,
                  isLoadingMore: _isLoadingMorePopular,
                  hasMore: _hasMorePopular,
                  scrollController: _popularScrollController,
                  onRefresh: _loadPopular,
                ),
                _buildMangaGrid(
                  list: _latestManga,
                  loading: _isLoadingLatest,
                  isLoadingMore: _isLoadingMoreLatest,
                  hasMore: _hasMoreLatest,
                  scrollController: _latestScrollController,
                  onRefresh: _loadLatest,
                ),
              ],
            ),
    );
  }

  Widget _buildSearchBody() {
    if (_isSearchLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan));
    }
    if (_searchManga.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty ? 'Ketik judul komik lalu tekan cari' : 'Tidak ditemukan komik',
          style: const TextStyle(color: AppTheme.textMuted),
        ),
      );
    }
    return _buildMangaGrid(
      list: _searchManga,
      loading: false,
      isLoadingMore: _isLoadingMoreSearch,
      hasMore: _hasMoreSearch,
      scrollController: _searchScrollController,
      onRefresh: () async => _performSearch(_activeSearchQuery),
    );
  }

  Widget _buildMangaGrid({
    required List<Manga> list,
    required bool loading,
    required bool isLoadingMore,
    required bool hasMore,
    required ScrollController scrollController,
    required Future<void> Function() onRefresh,
  }) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan));
    }
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book, size: 50, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            const Text('Gagal memuat komik dari server', style: TextStyle(color: AppTheme.textMuted)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRefresh, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppTheme.accentCyan,
      onRefresh: onRefresh,
      child: CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.65,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return MangaCard(manga: list[index]);
                },
                childCount: list.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: isLoadingMore
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.accentCyan,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Memuat komik selanjutnya...',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                          ),
                        ],
                      )
                    : (!hasMore && list.isNotEmpty)
                        ? const Text(
                            'Semua komik telah dimuat dari sumber',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          )
                        : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
