import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/models/manga.dart';
import '../../../core/models/chapter.dart';
import '../../../core/database/db_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/source_logo.dart';
import '../../../core/services/download_service.dart';
import '../../../providers/manga_provider.dart';
import '../../reader/screens/reader_screen.dart';

class MangaDetailScreen extends StatefulWidget {
  final Manga manga;

  const MangaDetailScreen({super.key, required this.manga});

  @override
  State<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends State<MangaDetailScreen> {
  bool _isExpanded = false;
  List<Chapter> _chapters = [];
  bool _isLoadingChapters = true;
  final Set<String> _downloadingChapters = {};

  String _chapterSearchQuery = '';
  String _chapterFilter = 'all'; // 'all', 'unread', 'downloaded'
  bool _isSearchingChapter = false;

  bool get _hasReadAnyChapter => _chapters.any((c) => c.isRead);

  Chapter? get _continueChapter {
    if (_chapters.isEmpty) return null;
    final sorted = List<Chapter>.from(_chapters)
      ..sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));
    for (final ch in sorted) {
      if (!ch.isRead) return ch;
    }
    return sorted.last;
  }

  List<Chapter> get _filteredChapters {
    return _chapters.where((ch) {
      if (_chapterFilter == 'unread' && ch.isRead) return false;
      if (_chapterFilter == 'downloaded' && !ch.isDownloaded) return false;
      if (_chapterSearchQuery.isNotEmpty) {
        final q = _chapterSearchQuery.toLowerCase();
        return ch.name.toLowerCase().contains(q) ||
            ch.chapterNumber.toString().contains(q);
      }
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    final provider = context.read<MangaProvider>();
    final fetched = await provider.fetchChaptersForManga(widget.manga);
    
    // Sinkronisasi status sudah dibaca dari database SQLite lokal
    final readUrls = await DBHelper.instance.getReadChapterUrls();

    // Cek status unduhan offline dan status baca untuk setiap bab
    for (final ch in fetched) {
      if (readUrls.contains(ch.url)) {
        ch.isRead = true;
      }
      final isDownloaded = await DownloadService.isChapterDownloaded(widget.manga.title, ch);
      ch.isDownloaded = isDownloaded;
    }

    if (mounted) {
      setState(() {
        _chapters = fetched;
        _isLoadingChapters = false;
      });
    }
  }

  Future<void> _startDownloadChapter(Chapter chapter) async {
    setState(() {
      _downloadingChapters.add(chapter.url);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Mengunduh ${chapter.name}...')),
    );

    final success = await DownloadService.downloadChapter(
      manga: widget.manga,
      chapter: chapter,
    );

    if (mounted) {
      setState(() {
        _downloadingChapters.remove(chapter.url);
        if (success) {
          chapter.isDownloaded = true;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Berhasil mengunduh ${chapter.name}! Siap dibaca offline.'
                : 'Gagal mengunduh ${chapter.name}. Periksa koneksi internet.',
          ),
          backgroundColor: success ? AppTheme.accentCyan : Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _deleteDownloadedChapter(Chapter chapter) async {
    await DownloadService.deleteDownloadedChapter(widget.manga.title, chapter);
    if (mounted) {
      setState(() {
        chapter.isDownloaded = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unduhan ${chapter.name} telah dihapus.')),
      );
    }
  }

  bool _isBatchDownloading = false;

  void _showBatchDownloadModal() {
    final unreadList = _chapters.where((c) => !c.isRead && !c.isDownloaded).toList();
    final nonDownloadedList = _chapters.where((c) => !c.isDownloaded).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
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
              const Row(
                children: [
                  Icon(Icons.download_for_offline, color: AppTheme.accentCyan),
                  SizedBox(width: 10),
                  Text(
                    'Unduh Bab Massal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Tersedia ${unreadList.length} bab belum dibaca (${nonDownloadedList.length} belum diunduh)',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.looks_5, color: AppTheme.accentCyan),
                title: const Text('Unduh 5 Bab Belum Dibaca', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _startBatchDownload(5, unreadOnly: true);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.looks_two, color: AppTheme.accentCyan),
                title: const Text('Unduh 10 Bab Belum Dibaca', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _startBatchDownload(10, unreadOnly: true);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.all_inclusive, color: AppTheme.accentCyan),
                title: Text(
                  'Unduh Semua Belum Dibaca (${unreadList.length} Bab)',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _startBatchDownload(unreadList.length, unreadOnly: true);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startBatchDownload(int count, {bool unreadOnly = true}) async {
    if (_isBatchDownloading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proses unduhan massal sedang berjalan...')),
      );
      return;
    }

    final candidates = _chapters.where((c) {
      if (c.isDownloaded) return false;
      if (unreadOnly && c.isRead) return false;
      return true;
    }).toList();

    // Urutkan bab dari nomor terkecil ke terbesar
    candidates.sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));
    final targets = candidates.take(count).toList();

    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada bab yang perlu diunduh.')),
      );
      return;
    }

    setState(() => _isBatchDownloading = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Memulai unduhan massal ${targets.length} bab...')),
    );

    int successCount = 0;
    for (int i = 0; i < targets.length; i++) {
      final ch = targets[i];
      if (!mounted) break;
      setState(() => _downloadingChapters.add(ch.url));

      final success = await DownloadService.downloadChapter(
        manga: widget.manga,
        chapter: ch,
      );

      if (mounted) {
        setState(() {
          _downloadingChapters.remove(ch.url);
          if (success) {
            ch.isDownloaded = true;
            successCount++;
          }
        });
      }
    }

    if (mounted) {
      setState(() => _isBatchDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selesai mengunduh $successCount dari ${targets.length} bab.'),
          backgroundColor: AppTheme.accentCyan,
        ),
      );
    }
  }

  void _showCategoryPickerModal(BuildContext context, MangaProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
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
                'Pilih Kategori Pustaka',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...provider.categories.where((c) => c != 'Semua').map((cat) {
                final isSelected = widget.manga.category == cat;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? AppTheme.accentCyan : AppTheme.textMuted,
                  ),
                  title: Text(cat, style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    provider.updateMangaCategory(widget.manga, cat);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Komik dipindahkan ke kategori $cat')),
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _chapterFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
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
        setState(() => _chapterFilter = value);
      },
    );
  }

  void _showChapterOptionsBottomSheet(Chapter chapter) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chapter.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  chapter.isRead ? Icons.mark_chat_unread_outlined : Icons.done_all,
                  color: AppTheme.accentCyan,
                ),
                title: Text(
                  chapter.isRead ? 'Tandai Belum Dibaca' : 'Tandai Sudah Dibaca',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  final newStatus = !chapter.isRead;
                  setState(() => chapter.isRead = newStatus);
                  await DBHelper.instance.markChapterRead(chapter.url, newStatus);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.playlist_add_check, color: AppTheme.accentCyan),
                title: const Text(
                  'Tandai Semua Bab Sebelumnya Sudah Dibaca',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Tandai bab ini dan seluruh bab di bawahnya sebagai selesai',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
                onTap: () async {
                  final idx = _chapters.indexOf(chapter);
                  if (idx >= 0) {
                    final urlsToMark = <String>[];
                    setState(() {
                      for (int i = idx; i < _chapters.length; i++) {
                        _chapters[i].isRead = true;
                        urlsToMark.add(_chapters[i].url);
                      }
                    });
                    await DBHelper.instance.markMultipleChaptersRead(urlsToMark, true);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              if (!chapter.isDownloaded)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.download, color: AppTheme.accentCyan),
                  title: const Text('Unduh Bab Offline', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _startDownloadChapter(chapter);
                  },
                )
              else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Hapus Unduhan Bab', style: TextStyle(color: Colors.redAccent)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _deleteDownloadedChapter(chapter);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Map<String, String> get _imageHeaders {
    final manga = widget.manga;
    if (manga.sourceId == 'shinigami' || manga.thumbnailUrl.contains('shngm')) {
      return const {
        'Referer': 'https://shinigami.asia/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
    } else if (manga.sourceId == 'mangadex' || manga.thumbnailUrl.contains('mangadex')) {
      return const {
        'User-Agent': 'KsHcans/1.0.0',
      };
    } else if (manga.sourceId == 'kiryuu' || manga.thumbnailUrl.contains('kiryuu')) {
      return const {
        'Referer': 'https://v7.kiryuu.to/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
    } else {
      return const {
        'Referer': 'https://bacakomik.my/',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MangaProvider>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header Cover Komik
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppTheme.oledBlack,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.manga.thumbnailUrl,
                    fit: BoxFit.cover,
                    httpHeaders: _imageHeaders,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.8),
                          AppTheme.oledBlack,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: widget.manga.thumbnailUrl,
                            width: 90,
                            height: 130,
                            fit: BoxFit.cover,
                            httpHeaders: _imageHeaders,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.manga.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.manga.author,
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cardDark,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      widget.manga.status,
                                      style: const TextStyle(
                                        color: AppTheme.accentCyan,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.cardDark,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SourceLogo(sourceId: widget.manga.sourceId, size: 14),
                                        const SizedBox(width: 5),
                                        Text(
                                          widget.manga.sourceId == 'shinigami'
                                              ? 'Shinigami'
                                              : widget.manga.sourceId == 'mangadex'
                                                  ? 'MangaDex'
                                                  : 'BacaKomik',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tombol Aksi & Sinopsis
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.manga.inLibrary ? AppTheme.cardDark : AppTheme.accentCyan,
                            foregroundColor: widget.manga.inLibrary ? Colors.white : Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: Icon(widget.manga.inLibrary ? Icons.bookmark : Icons.bookmark_add_outlined),
                          label: Text(
                            widget.manga.inLibrary
                                ? 'Pustaka (${widget.manga.category})'
                                : 'Tambah ke Pustaka',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            provider.toggleLibrary(widget.manga);
                          },
                          onLongPress: widget.manga.inLibrary
                              ? () => _showCategoryPickerModal(context, provider)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.accentCyan,
                            side: const BorderSide(color: AppTheme.accentCyan),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: Icon(_hasReadAnyChapter ? Icons.play_arrow : Icons.menu_book),
                          label: Text(
                            _hasReadAnyChapter && _continueChapter != null
                                ? 'Lanjut: ${_continueChapter!.name}'
                                : 'Mulai Baca',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            if (_chapters.isNotEmpty) {
                              final target = _continueChapter ?? _chapters.last;
                              final targetIndex = _chapters.indexOf(target);
                              _openChapter(context, targetIndex >= 0 ? targetIndex : 0);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sinopsis',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    child: Text(
                      widget.manga.description.isEmpty
                          ? 'Membaca komik ${widget.manga.title} terjemahan Bahasa Indonesia lengkap di aplikasi.'
                          : widget.manga.description,
                      maxLines: _isExpanded ? 100 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFCCCCCC),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const Divider(color: AppTheme.cardDark, height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isLoadingChapters
                            ? 'Memuat daftar bab...'
                            : '${_filteredChapters.length} / ${_chapters.length} Bab',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Row(
                        children: [
                          if (_isBatchDownloading)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentCyan),
                              ),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.download_for_offline_outlined, color: AppTheme.accentCyan),
                              tooltip: 'Unduh Bab Massal',
                              onPressed: _showBatchDownloadModal,
                            ),
                          IconButton(
                            icon: Icon(
                              _isSearchingChapter ? Icons.close : Icons.search,
                              color: _isSearchingChapter ? AppTheme.accentCyan : AppTheme.textMuted,
                            ),
                            tooltip: 'Cari Bab',
                            onPressed: () {
                              setState(() {
                                _isSearchingChapter = !_isSearchingChapter;
                                if (!_isSearchingChapter) {
                                  _chapterSearchQuery = '';
                                }
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.swap_vert, color: AppTheme.textMuted),
                            tooltip: 'Balik Urutan',
                            onPressed: () {
                              setState(() {
                                _chapters = _chapters.reversed.toList();
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_isSearchingChapter) ...[
                    const SizedBox(height: 8),
                    TextField(
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Cari bab (misal: 120, Special)...',
                        hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.6)),
                        prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.accentCyan),
                        filled: true,
                        fillColor: AppTheme.cardDark,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) => setState(() => _chapterSearchQuery = val),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('Semua (${_chapters.length})', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'Belum Dibaca (${_chapters.where((c) => !c.isRead).length})',
                          'unread',
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'Terunduh (${_chapters.where((c) => c.isDownloaded).length})',
                          'downloaded',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Daftar Seluruh Bab (Chapters)
          if (_isLoadingChapters)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: AppTheme.accentCyan),
                ),
              ),
            )
          else if (_chapters.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
                  child: Column(
                    children: [
                      const Icon(Icons.menu_book_outlined, color: AppTheme.textMuted, size: 40),
                      const SizedBox(height: 12),
                      const Text(
                        'Belum ada bab yang tersedia atau gagal memuat data.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentCyan,
                          side: const BorderSide(color: AppTheme.accentCyan),
                        ),
                        onPressed: () {
                          setState(() => _isLoadingChapters = true);
                          _loadChapters();
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Muat Ulang'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_filteredChapters.isEmpty)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    'Tidak ada bab yang sesuai filter / pencarian.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final chapter = _filteredChapters[index];
                  final originalIndex = _chapters.indexOf(chapter);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    onLongPress: () => _showChapterOptionsBottomSheet(chapter),
                    title: Text(
                      chapter.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: chapter.isRead ? FontWeight.normal : FontWeight.bold,
                        color: chapter.isRead ? AppTheme.textMuted : Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      chapter.dateUpload,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_downloadingChapters.contains(chapter.url))
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentCyan),
                            ),
                          )
                        else if (chapter.isDownloaded)
                          IconButton(
                            icon: const Icon(Icons.download_done, color: AppTheme.accentCyan),
                            tooltip: 'Unduhan Selesai (Hapus)',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: AppTheme.surfaceDark,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: Text('Hapus Unduhan ${chapter.name}?'),
                                  content: const Text(
                                    'File gambar bab ini akan dihapus dari memori HP Anda.',
                                    style: TextStyle(color: AppTheme.textMuted),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Batal', style: TextStyle(color: AppTheme.textMuted)),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _deleteDownloadedChapter(chapter);
                                      },
                                      child: const Text('Hapus'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.download_for_offline_outlined, color: AppTheme.textMuted),
                            tooltip: 'Unduh Bab Offline',
                            onPressed: () => _startDownloadChapter(chapter),
                          ),
                        IconButton(
                          icon: Icon(
                            chapter.isRead ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: chapter.isRead ? AppTheme.accentCyan : AppTheme.textMuted,
                            size: 20,
                          ),
                          tooltip: chapter.isRead ? 'Tandai Belum Dibaca' : 'Tandai Sudah Dibaca',
                          onPressed: () async {
                            final newStatus = !chapter.isRead;
                            setState(() => chapter.isRead = newStatus);
                            await DBHelper.instance.markChapterRead(chapter.url, newStatus);
                          },
                        ),
                      ],
                    ),
                    onTap: () => _openChapter(context, originalIndex >= 0 ? originalIndex : 0),
                  );
                },
                childCount: _filteredChapters.length,
              ),
            ),
        ],
      ),
    );
  }

  void _openChapter(BuildContext context, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderScreen(
          mangaTitle: widget.manga.title,
          manga: widget.manga,
          chapters: _chapters,
          initialIndex: index,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }
}
