import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../core/models/manga.dart';
import '../../../core/services/bacakomik_service.dart';
import '../../../core/services/doujindesu_service.dart';
import '../../../core/services/download_service.dart';
import '../../../core/services/ikiru_service.dart';
import '../../../core/services/kiryuu_service.dart';
import '../../../core/services/komiku_service.dart';
import '../../../core/services/komikindo_service.dart';
import '../../../core/services/luvyaa_service.dart';
import '../../../core/services/mangadex_service.dart';
import '../../../core/services/shinigami_service.dart';
import '../../../core/services/source_config_service.dart';
import '../../../core/database/db_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/source_logo.dart';
import '../../../providers/manga_provider.dart';
import '../../detail/screens/manga_detail_screen.dart';

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  List<Manga> _latestUpdates = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _selectedSource = 'all'; // 'all', 'komiku', 'komikindo', 'shinigami', 'bacakomik', 'kiryuu', 'mangadex', 'doujindesu'
  bool _isNsfwEnabled = false;
  final Set<String> _downloadingManga = {};
  final Set<String> _downloadedManga = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNsfwSetting();
    _loadUpdates();
  }

  Future<void> _loadNsfwSetting() async {
    final val = await DBHelper.instance.getSetting('nsfw_enabled');
    if (mounted) {
      setState(() => _isNsfwEnabled = val == 'true');
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 350) {
      _loadMoreUpdates();
    }
  }

  Future<void> _loadUpdates({bool isRefresh = false}) async {
    if (isRefresh) {
      _currentPage = 1;
      _hasMore = true;
    }
    setState(() => _isLoading = true);
    List<Manga> result = [];
    try {
      if (_selectedSource == 'shinigami') {
        result = await ShinigamiService.getLatestUpdates(page: 1);
      } else if (_selectedSource == 'komiku') {
        result = await KomikuService.getLatestUpdates(page: 1);
      } else if (_selectedSource == 'komikindo') {
        result = await KomikIndoService.getLatestUpdates(page: 1);
      } else if (_selectedSource == 'bacakomik') {
        result = await BacaKomikService.getLatestUpdates(page: 1);
      } else if (_selectedSource == 'kiryuu') {
        result = await KiryuuService.getLatestUpdates(page: 1);
      } else if (_selectedSource == 'ikiru') {
        result = await IkiruService.getLatestUpdates(page: 1);
      } else if (_selectedSource == 'luvyaa') {
        result = await LuvyaaService.getLatestUpdates(page: 1);
      } else if (_selectedSource == 'mangadex') {
        result = await MangaDexService.getLatestUpdates(page: 1);
      } else if (_selectedSource == 'doujindesu') {
        result = await DoujinDesuService.getLatestUpdates(page: 1);
      } else {
        // 'all': Tarik secara paralel dari Komiku, KomikIndo, Shinigami, dan BacaKomik
        final futures = await Future.wait([
          KomikuService.getLatestUpdates(page: 1).catchError((_) => <Manga>[]),
          KomikIndoService.getLatestUpdates(page: 1).catchError((_) => <Manga>[]),
          ShinigamiService.getLatestUpdates(page: 1).catchError((_) => <Manga>[]),
          BacaKomikService.getLatestUpdates(page: 1).catchError((_) => <Manga>[]),
        ]);
        final combined = <Manga>[];
        final seen = <String>{};
        for (final list in futures) {
          for (final m in list) {
            if (!seen.contains(m.url)) {
              seen.add(m.url);
              combined.add(m);
            }
          }
        }
        result = combined;
      }
    } catch (_) {
      result = [];
    }

    if (mounted) {
      setState(() {
        _latestUpdates = result;
        _isLoading = false;
        _hasMore = result.isNotEmpty;
        _currentPage = 1;
      });
    }
  }

  Future<void> _loadMoreUpdates() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    setState(() => _isLoadingMore = true);
    final nextPage = _currentPage + 1;
    List<Manga> newItems = [];

    try {
      if (_selectedSource == 'shinigami') {
        newItems = await ShinigamiService.getLatestUpdates(page: nextPage);
      } else if (_selectedSource == 'komiku') {
        newItems = await KomikuService.getLatestUpdates(page: nextPage);
      } else if (_selectedSource == 'komikindo') {
        newItems = await KomikIndoService.getLatestUpdates(page: nextPage);
      } else if (_selectedSource == 'bacakomik') {
        newItems = await BacaKomikService.getLatestUpdates(page: nextPage);
      } else if (_selectedSource == 'kiryuu') {
        newItems = await KiryuuService.getLatestUpdates(page: nextPage);
      } else if (_selectedSource == 'ikiru') {
        newItems = await IkiruService.getLatestUpdates(page: nextPage);
      } else if (_selectedSource == 'luvyaa') {
        newItems = await LuvyaaService.getLatestUpdates(page: nextPage);
      } else if (_selectedSource == 'mangadex') {
        newItems = await MangaDexService.getLatestUpdates(page: nextPage);
      } else if (_selectedSource == 'doujindesu') {
        newItems = await DoujinDesuService.getLatestUpdates(page: nextPage);
      } else {
        final futures = await Future.wait([
          KomikuService.getLatestUpdates(page: nextPage).catchError((_) => <Manga>[]),
          KomikIndoService.getLatestUpdates(page: nextPage).catchError((_) => <Manga>[]),
          BacaKomikService.getLatestUpdates(page: nextPage).catchError((_) => <Manga>[]),
        ]);
        final combined = <Manga>[];
        final existing = _latestUpdates.map((m) => m.url).toSet();
        for (final list in futures) {
          for (final m in list) {
            if (!existing.contains(m.url)) {
              existing.add(m.url);
              combined.add(m);
            }
          }
        }
        newItems = combined;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        if (newItems.isNotEmpty) {
          _latestUpdates.addAll(newItems);
          _currentPage = nextPage;
        } else {
          _hasMore = false;
        }
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _downloadLatestChapter(Manga manga) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _downloadingManga.add(manga.url));
    messenger.showSnackBar(
      SnackBar(content: Text('Memulai pengunduhan bab terbaru ${manga.title}...')),
    );

    try {
      final chapters = await context.read<MangaProvider>().fetchChaptersForManga(manga);
      if (chapters.isNotEmpty) {
        final latestCh = chapters.first;
        final success = await DownloadService.downloadChapter(manga: manga, chapter: latestCh);
        if (mounted) {
          setState(() {
            _downloadingManga.remove(manga.url);
            if (success) _downloadedManga.add(manga.url);
          });
          messenger.showSnackBar(
            SnackBar(
              content: Text(success
                  ? 'Berhasil mengunduh ${latestCh.name} (${manga.title})!'
                  : 'Gagal mengunduh bab.'),
              backgroundColor: success ? AppTheme.accentCyan : Colors.redAccent,
            ),
          );
        }
      } else {
        if (mounted) setState(() => _downloadingManga.remove(manga.url));
      }
    } catch (_) {
      if (mounted) setState(() => _downloadingManga.remove(manga.url));
    }
  }

  Map<String, String> _getImageHeaders(Manga manga) {
    return SourceConfigService.getImageHeaders(manga.sourceId, manga.thumbnailUrl);
  }

  Widget _buildSourceFilterChip(String label, String sourceId) {
    final isSelected = _selectedSource == sourceId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.black : Colors.white,
          ),
        ),
        selected: isSelected,
        selectedColor: AppTheme.accentCyan,
        backgroundColor: AppTheme.cardDark,
        checkmarkColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onSelected: (_) {
          if (_selectedSource != sourceId) {
            setState(() {
              _selectedSource = sourceId;
              _currentPage = 1;
              _hasMore = true;
            });
            _loadUpdates();
          }
        },
      ),
    );
  }

  String _getSourceName(String sourceId) {
    switch (sourceId) {
      case 'shinigami':
        return 'Shinigami ID';
      case 'komiku':
        return 'Komiku';
      case 'komikindo':
        return 'KomikIndo';
      case 'mangadex':
        return 'MangaDex';
      case 'kiryuu':
        return 'Kiryuu';
      case 'ikiru':
        return 'Ikiru';
      case 'luvyaa':
        return 'Mak Luvya';
      case 'doujindesu':
        return 'DoujinDesu (18+)';
      default:
        return 'BacaKomik';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Beranda', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(
              'Rilisan Bab Terbaru Hari Ini',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan Rilis Terbaru',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Memeriksa rilis bab baru...'), duration: Duration(seconds: 1)),
              );
              _loadUpdates(isRefresh: true);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Sumber
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildSourceFilterChip('Semua Sumber', 'all'),
                _buildSourceFilterChip('Komiku', 'komiku'),
                _buildSourceFilterChip('KomikIndo', 'komikindo'),
                _buildSourceFilterChip('Ikiru', 'ikiru'),
                _buildSourceFilterChip('Shinigami', 'shinigami'),
                _buildSourceFilterChip('BacaKomik', 'bacakomik'),
                _buildSourceFilterChip('Kiryuu', 'kiryuu'),
                _buildSourceFilterChip('Mak Luvya', 'luvyaa'),
                _buildSourceFilterChip('MangaDex', 'mangadex'),
                if (_isNsfwEnabled) _buildSourceFilterChip('DoujinDesu (18+)', 'doujindesu'),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
                : _latestUpdates.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.whatshot_outlined, size: 54, color: AppTheme.textMuted),
                            const SizedBox(height: 12),
                            const Text('Belum ada pembaruan komik', style: TextStyle(color: AppTheme.textMuted)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentCyan,
                                foregroundColor: Colors.black,
                              ),
                              onPressed: () => _loadUpdates(isRefresh: true),
                              child: const Text('Muat Ulang'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppTheme.accentCyan,
                        onRefresh: () => _loadUpdates(isRefresh: true),
                        child: ListView.separated(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _latestUpdates.length + 1,
                          separatorBuilder: (_, index) => const Divider(color: AppTheme.cardDark, height: 1),
                          itemBuilder: (context, index) {
                            if (index == _latestUpdates.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                child: Center(
                                  child: _isLoadingMore
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
                                              'Memuat rilis selanjutnya...',
                                              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                            ),
                                          ],
                                        )
                                      : (!_hasMore && _latestUpdates.isNotEmpty)
                                          ? const Text(
                                              'Semua rilis terbaru telah ditampilkan',
                                              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                            )
                                          : const SizedBox.shrink(),
                                ),
                              );
                            }

                            final item = _latestUpdates[index];
                            final isDownloading = _downloadingManga.contains(item.url);
                            final isDownloaded = _downloadedManga.contains(item.url);

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MangaDetailScreen(manga: item),
                                  ),
                                );
                              },
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: CachedNetworkImage(
                                  imageUrl: item.thumbnailUrl,
                                  width: 50,
                                  height: 70,
                                  fit: BoxFit.cover,
                                  httpHeaders: _getImageHeaders(item),
                                  placeholder: (context, url) => Container(color: AppTheme.surfaceDark),
                                  errorWidget: (context, url, error) => Container(
                                    color: AppTheme.cardDark,
                                    child: const Icon(Icons.broken_image, color: AppTheme.textMuted),
                                  ),
                                ),
                              ),
                              title: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      SourceLogo(sourceId: item.sourceId, size: 14),
                                      const SizedBox(width: 6),
                                      Text(
                                        _getSourceName(item.sourceId),
                                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Baru saja diperbarui',
                                    style: TextStyle(color: AppTheme.accentCyan, fontSize: 11, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              trailing: isDownloading
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentCyan),
                                      ),
                                    )
                                  : IconButton(
                                      icon: Icon(
                                        isDownloaded ? Icons.download_done : Icons.download_outlined,
                                        color: isDownloaded ? AppTheme.accentCyan : AppTheme.textMuted,
                                      ),
                                      tooltip: 'Unduh Bab Terbaru',
                                      onPressed: () => _downloadLatestChapter(item),
                                    ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
