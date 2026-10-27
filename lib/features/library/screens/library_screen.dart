import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/manga.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/manga_provider.dart';
import '../widgets/manga_card.dart';

class LibraryScreen extends StatefulWidget {
  final VoidCallback? onExploreTap;

  const LibraryScreen({super.key, this.onExploreTap});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _isSearching = false;
  String _sortBy = 'title_asc'; // 'title_asc', 'title_desc', 'unread'
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _showAddCategoryDialog(BuildContext context, MangaProvider provider) {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Tambah Kategori Baru', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Misal: Manhwa Pilihan, Rekomendasi Teman',
            hintStyle: TextStyle(color: AppTheme.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCyan,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final cat = textCtrl.text.trim();
              if (cat.isNotEmpty) {
                provider.addCustomCategory(cat);
                provider.selectCategory(cat);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showSortBottomSheet() {
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
                    'Urutkan Pustaka',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.sort_by_alpha, color: AppTheme.accentCyan),
                    title: const Text('Abjad A ke Z (Menaik)', style: TextStyle(color: Colors.white)),
                    trailing: _sortBy == 'title_asc'
                        ? const Icon(Icons.check_circle, color: AppTheme.accentCyan)
                        : null,
                    onTap: () {
                      setState(() => _sortBy = 'title_asc');
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.sort_by_alpha, color: AppTheme.accentCyan),
                    title: const Text('Abjad Z ke A (Menurun)', style: TextStyle(color: Colors.white)),
                    trailing: _sortBy == 'title_desc'
                        ? const Icon(Icons.check_circle, color: AppTheme.accentCyan)
                        : null,
                    onTap: () {
                      setState(() => _sortBy = 'title_desc');
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.mark_unread_chat_alt, color: AppTheme.accentCyan),
                    title: const Text('Jumlah Belum Dibaca Terbanyak', style: TextStyle(color: Colors.white)),
                    trailing: _sortBy == 'unread'
                        ? const Icon(Icons.check_circle, color: AppTheme.accentCyan)
                        : null,
                    onTap: () {
                      setState(() => _sortBy = 'unread');
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

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MangaProvider>();
    final rawList = provider.libraryManga;
    final mangaList = List<Manga>.from(rawList);

    if (_sortBy == 'title_asc') {
      mangaList.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (_sortBy == 'title_desc') {
      mangaList.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
    } else if (_sortBy == 'unread') {
      mangaList.sort((a, b) => b.unreadCount.compareTo(a.unreadCount));
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Cari komik di perpustakaan...',
                  hintStyle: TextStyle(color: AppTheme.textMuted),
                  border: InputBorder.none,
                ),
                onChanged: (val) => provider.searchLive(val),
              )
            : const Text('Perpustakaan'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  provider.searchLive('');
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Perbarui Status Pustaka',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Memperbarui jumlah bab baru di pustaka...')),
              );
              await provider.refreshLibraryUnreadCounts();
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Urutkan Pustaka',
            onPressed: _showSortBottomSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Kategori Filter Chips
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: provider.categories.length + 1,
              itemBuilder: (context, index) {
                if (index == provider.categories.length) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: const Icon(Icons.add, size: 16, color: AppTheme.accentCyan),
                      label: const Text('Kategori', style: TextStyle(color: AppTheme.accentCyan, fontSize: 12)),
                      backgroundColor: AppTheme.cardDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onPressed: () => _showAddCategoryDialog(context, provider),
                    ),
                  );
                }
                final category = provider.categories[index];
                final isSelected = category == provider.selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (_) => provider.selectCategory(category),
                  ),
                );
              },
            ),
          ),

          if (provider.isLoading)
            const LinearProgressIndicator(color: AppTheme.accentCyan, backgroundColor: Colors.transparent),

          const SizedBox(height: 8),

          // Grid Komik
          Expanded(
            child: mangaList.isEmpty
                ? (provider.isLibraryEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardDark,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.accentCyan.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.collections_bookmark_outlined,
                                  size: 52,
                                  color: AppTheme.accentCyan,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Pustaka Anda Masih Kosong',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Simpan manga, manhwa, atau manhua favorit Anda dari berbagai sumber di tab Jelajahi untuk memudahkan membaca dan memantau rilis bab terbaru.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.5),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentCyan,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                ),
                                icon: const Icon(Icons.explore, size: 20),
                                label: const Text('Mulai Jelajahi Komik', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: widget.onExploreTap,
                              ),
                            ],
                          ),
                        ),
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.filter_list_off,
                                size: 54,
                                color: AppTheme.textMuted.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'Tidak ditemukan komik dengan judul "${_searchController.text}"'
                                    : 'Belum ada komik di kategori "${provider.selectedCategory}"',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ))
                : RefreshIndicator(
                    color: AppTheme.accentCyan,
                    onRefresh: () async {
                      await provider.refreshLibraryUnreadCounts();
                    },
                    child: CustomScrollView(
                      controller: _scrollController,
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
                                return MangaCard(manga: mangaList[index]);
                              },
                              childCount: mangaList.length,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
