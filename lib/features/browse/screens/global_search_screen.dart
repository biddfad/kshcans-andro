import 'package:flutter/material.dart';
import '../../../core/database/db_helper.dart';
import '../../../core/models/manga.dart';
import '../../../core/services/bacakomik_service.dart';
import '../../../core/services/doujindesu_service.dart';
import '../../../core/services/ikiru_service.dart';
import '../../../core/services/kiryuu_service.dart';
import '../../../core/services/komiku_service.dart';
import '../../../core/services/komikindo_service.dart';
import '../../../core/services/luvyaa_service.dart';
import '../../../core/services/mangadex_service.dart';
import '../../../core/services/shinigami_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/source_logo.dart';
import '../../library/widgets/manga_card.dart';

class GlobalSearchScreen extends StatefulWidget {
  final String? initialQuery;

  const GlobalSearchScreen({super.key, this.initialQuery});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isNsfwEnabled = false;
  String _selectedSourceFilter = 'all';

  List<Manga> _shinigamiResults = [];
  List<Manga> _bacakomikResults = [];
  List<Manga> _kiryuuResults = [];
  List<Manga> _mangadexResults = [];
  List<Manga> _komikuResults = [];
  List<Manga> _komikindoResults = [];
  List<Manga> _doujindesuResults = [];
  List<Manga> _ikiruResults = [];
  List<Manga> _luvyaaResults = [];

  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _checkNsfw();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }
  }

  Future<void> _checkNsfw() async {
    try {
      final val = await DBHelper.instance.getSetting('nsfw_enabled');
      if (mounted) {
        setState(() => _isNsfwEnabled = val == 'true');
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _shinigamiResults = [];
      _bacakomikResults = [];
      _kiryuuResults = [];
      _mangadexResults = [];
      _komikuResults = [];
      _komikindoResults = [];
      _doujindesuResults = [];
      _ikiruResults = [];
      _luvyaaResults = [];
    });

    try {
      final futures = await Future.wait([
        ShinigamiService.searchManga(cleanQuery).catchError((_) => <Manga>[]),
        BacaKomikService.searchManga(cleanQuery).catchError((_) => <Manga>[]),
        KiryuuService.searchManga(cleanQuery).catchError((_) => <Manga>[]),
        MangaDexService.searchManga(cleanQuery).catchError((_) => <Manga>[]),
        KomikuService.searchManga(cleanQuery).catchError((_) => <Manga>[]),
        KomikIndoService.searchManga(cleanQuery).catchError((_) => <Manga>[]),
        IkiruService.searchManga(cleanQuery).catchError((_) => <Manga>[]),
        LuvyaaService.searchManga(cleanQuery).catchError((_) => <Manga>[]),
        if (_isNsfwEnabled)
          DoujinDesuService.searchManga(cleanQuery).catchError((_) => <Manga>[])
        else
          Future.value(<Manga>[]),
      ]);

      if (mounted) {
        setState(() {
          _shinigamiResults = futures[0];
          _bacakomikResults = futures[1];
          _kiryuuResults = futures[2];
          _mangadexResults = futures[3];
          _komikuResults = futures[4];
          _komikindoResults = futures[5];
          _ikiruResults = futures[6];
          _luvyaaResults = futures[7];
          _doujindesuResults = futures[8];
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  List<Manga> get _filteredResults {
    switch (_selectedSourceFilter) {
      case 'shinigami':
        return _shinigamiResults;
      case 'bacakomik':
        return _bacakomikResults;
      case 'kiryuu':
        return _kiryuuResults;
      case 'mangadex':
        return _mangadexResults;
      case 'komiku':
        return _komikuResults;
      case 'komikindo':
        return _komikindoResults;
      case 'ikiru':
        return _ikiruResults;
      case 'luvyaa':
        return _luvyaaResults;
      case 'doujindesu':
        return _doujindesuResults;
      default:
        return [
          ..._komikuResults,
          ..._komikindoResults,
          ..._ikiruResults,
          ..._shinigamiResults,
          ..._bacakomikResults,
          ..._kiryuuResults,
          ..._luvyaaResults,
          ..._mangadexResults,
          if (_isNsfwEnabled) ..._doujindesuResults,
        ];
    }
  }

  int get _totalCount =>
      _shinigamiResults.length +
      _bacakomikResults.length +
      _kiryuuResults.length +
      _mangadexResults.length +
      _komikuResults.length +
      _komikindoResults.length +
      _ikiruResults.length +
      _luvyaaResults.length +
      (_isNsfwEnabled ? _doujindesuResults.length : 0);

  Widget _buildFilterChip(String label, String sourceId, int count) {
    final isSelected = _selectedSourceFilter == sourceId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sourceId != 'all') ...[
              SourceLogo(sourceId: sourceId, size: 14),
              const SizedBox(width: 5),
            ],
            Text('$label ($count)'),
          ],
        ),
        selected: isSelected,
        selectedColor: AppTheme.accentCyan,
        backgroundColor: AppTheme.cardDark,
        checkmarkColor: Colors.black,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.black : Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onSelected: (_) {
          setState(() => _selectedSourceFilter = sourceId);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          textInputAction: TextInputAction.search,
          onSubmitted: _performSearch,
          decoration: InputDecoration(
            hintText: 'Cari komik ke semua sumber...',
            hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.7)),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: AppTheme.textMuted),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          onChanged: (val) => setState(() {}),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppTheme.accentCyan),
            onPressed: () => _performSearch(_searchController.text),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_hasSearched) ...[
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _buildFilterChip('Semua', 'all', _totalCount),
                  _buildFilterChip('Komiku', 'komiku', _komikuResults.length),
                  _buildFilterChip('KomikIndo', 'komikindo', _komikindoResults.length),
                  _buildFilterChip('Ikiru', 'ikiru', _ikiruResults.length),
                  _buildFilterChip('Shinigami', 'shinigami', _shinigamiResults.length),
                  _buildFilterChip('BacaKomik', 'bacakomik', _bacakomikResults.length),
                  _buildFilterChip('Kiryuu', 'kiryuu', _kiryuuResults.length),
                  _buildFilterChip('Mak Luvya', 'luvyaa', _luvyaaResults.length),
                  _buildFilterChip('MangaDex', 'mangadex', _mangadexResults.length),
                  if (_isNsfwEnabled)
                    _buildFilterChip('DoujinDesu (18+)', 'doujindesu', _doujindesuResults.length),
                ],
              ),
            ),
            const Divider(color: AppTheme.cardDark, height: 1),
          ],
          if (_isSearching)
            const LinearProgressIndicator(color: AppTheme.accentCyan, backgroundColor: Colors.transparent),
          Expanded(
            child: !_hasSearched
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.travel_explore, size: 72, color: AppTheme.textMuted.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        const Text(
                          'Ketik judul komik untuk mencari\nke 4 sumber komik sekaligus.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : _filteredResults.isEmpty && !_isSearching
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 64, color: AppTheme.textMuted),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ditemukan komik untuk "${_searchController.text}"',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _filteredResults.length,
                        itemBuilder: (context, index) {
                          return MangaCard(manga: _filteredResults[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
