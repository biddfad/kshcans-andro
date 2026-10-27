import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/manga.dart';
import '../../../core/models/chapter.dart';
import '../../../core/database/db_helper.dart';
import '../../../providers/manga_provider.dart';
import '../../detail/screens/manga_detail_screen.dart';
import '../../reader/screens/reader_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _historyItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final data = await DBHelper.instance.getReadingHistory();
    final nsfwVal = await DBHelper.instance.getSetting('nsfw_enabled');
    final isNsfw = nsfwVal == 'true';
    final filtered = isNsfw
        ? data
        : data.where((item) {
            final src = item['source_id']?.toString() ?? '';
            final url = item['manga_url']?.toString() ?? '';
            return src != 'doujindesu' && !url.contains('desu.');
          }).toList();
    if (mounted) {
      setState(() {
        _historyItems = filtered;
        _isLoading = false;
      });
    }
  }

  String _formatRelativeTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes} menit yang lalu';
      if (diff.inHours < 24) return '${diff.inHours} jam yang lalu';
      if (diff.inDays == 1) return 'Kemarin';
      return '${diff.inDays} hari yang lalu';
    } catch (_) {
      return 'Baru saja';
    }
  }

  Map<String, String> _getImageHeaders(String sourceId, String url) {
    if (sourceId == 'shinigami' || url.contains('shngm')) {
      return const {
        'Referer': 'https://shinigami.asia/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
    } else if (sourceId == 'komiku' || url.contains('komiku')) {
      return const {
        'Referer': 'https://komiku.org/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      };
    } else if (sourceId == 'komikindo' || url.contains('komikindo')) {
      return const {
        'Referer': 'https://komikindo.ch/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      };
    } else if (sourceId == 'kiryuu' || url.contains('kiryuu')) {
      return const {
        'Referer': 'https://v7.kiryuu.to/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
    } else if (sourceId == 'doujindesu' || url.contains('desu.')) {
      return const {
        'Referer': 'https://doujin.desu.xxx/',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
      };
    } else if (sourceId == 'mangadex' || url.contains('mangadex')) {
      return const {
        'User-Agent': 'KsHcans/1.0.0',
      };
    } else {
      return const {
        'Referer': 'https://bacakomik.my/',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      };
    }
  }

  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Hapus Riwayat?'),
          content: const Text(
            'Apakah Anda yakin ingin menghapus seluruh riwayat bacaan komik?',
            style: TextStyle(color: AppTheme.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                await DBHelper.instance.clearReadingHistory();
                _loadHistory();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Seluruh riwayat bacaan telah dibersihkan')),
                  );
                }
              },
              child: const Text('Hapus Semua'),
            ),
          ],
        );
      },
    );
  }

  void _openMangaDetail(Map<String, dynamic> item) {
    final manga = Manga(
      sourceId: item['source_id'] ?? 'bacakomik',
      url: item['manga_url'] ?? '',
      title: item['manga_title'] ?? 'Tanpa Judul',
      author: 'Unknown',
      description: '',
      genre: '',
      status: 'Ongoing',
      thumbnailUrl: item['thumbnail_url'] ?? '',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MangaDetailScreen(manga: manga),
      ),
    ).then((_) => _loadHistory());
  }

  Future<void> _resumeReading(Map<String, dynamic> item) async {
    final manga = Manga(
      sourceId: item['source_id'] ?? 'bacakomik',
      url: item['manga_url'] ?? '',
      title: item['manga_title'] ?? 'Tanpa Judul',
      author: 'Unknown',
      description: '',
      genre: '',
      status: 'Ongoing',
      thumbnailUrl: item['thumbnail_url'] ?? '',
    );

    final targetChapterUrl = item['chapter_url'] ?? '';

    // Tampilkan loader singkat saat mengambil daftar bab lengkap
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppTheme.accentCyan),
      ),
    );

    List<Chapter> chapters = [];
    try {
      chapters = await context.read<MangaProvider>().fetchChaptersForManga(manga);
    } catch (_) {}

    if (mounted) {
      Navigator.pop(context); // Tutup loader

      if (chapters.isEmpty) {
        final fallbackChapter = Chapter(
          mangaId: 1,
          url: targetChapterUrl,
          name: item['chapter_name'] ?? 'Bab Terakhir',
          chapterNumber: (item['chapter_number'] as num?)?.toDouble() ?? 1.0,
          dateUpload: 'Riwayat',
        );
        chapters = [fallbackChapter];
      }

      int targetIndex = chapters.indexWhere((c) => c.url == targetChapterUrl);
      if (targetIndex < 0) targetIndex = 0;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReaderScreen(
            mangaTitle: manga.title,
            manga: manga,
            chapters: chapters,
            initialIndex: targetIndex,
          ),
        ),
      ).then((_) => _loadHistory());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Baca'),
        actions: [
          if (_historyItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Bersihkan Riwayat',
              onPressed: _confirmClearHistory,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
          : _historyItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_toggle_off_outlined,
                        size: 64,
                        color: AppTheme.textMuted.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Belum ada riwayat bacaan komik',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Komik yang Anda baca akan otomatis tercatat di sini',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.accentCyan,
                  onRefresh: _loadHistory,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _historyItems.length,
                    separatorBuilder: (_, index) => const Divider(color: AppTheme.cardDark, height: 1),
                    itemBuilder: (context, index) {
                      final item = _historyItems[index];
                      final title = item['manga_title'] ?? 'Tanpa Judul';
                      final chapterName = item['chapter_name'] ?? 'Bab Terakhir';
                      final readAt = item['read_at'] ?? '';
                      final thumbUrl = item['thumbnail_url'] ?? '';
                      final sourceId = item['source_id'] ?? '';

                      return Dismissible(
                        key: Key(item['manga_url'] ?? index.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.redAccent,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) async {
                          final mangaUrl = item['manga_url'] ?? '';
                          setState(() {
                            _historyItems.removeAt(index);
                          });
                          await DBHelper.instance.deleteHistoryItem(mangaUrl);
                        },
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          onTap: () => _openMangaDetail(item),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: thumbUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: thumbUrl,
                                    width: 50,
                                    height: 70,
                                    fit: BoxFit.cover,
                                    httpHeaders: _getImageHeaders(sourceId, thumbUrl),
                                    placeholder: (context, url) => Container(color: AppTheme.surfaceDark),
                                    errorWidget: (context, url, error) => Container(
                                      color: AppTheme.cardDark,
                                      child: const Icon(Icons.menu_book, color: AppTheme.accentCyan),
                                    ),
                                  )
                                : Container(
                                    width: 50,
                                    height: 70,
                                    color: AppTheme.cardDark,
                                    child: const Icon(Icons.menu_book, color: AppTheme.accentCyan),
                                  ),
                          ),
                          title: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                chapterName,
                                style: const TextStyle(color: AppTheme.accentCyan, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatRelativeTime(readAt),
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.play_circle_fill, color: AppTheme.accentCyan, size: 32),
                            tooltip: 'Lanjut Baca',
                            onPressed: () => _resumeReading(item),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
