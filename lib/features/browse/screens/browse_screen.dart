import 'package:flutter/material.dart';
import '../../../core/database/db_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/source_logo.dart';
import 'global_search_screen.dart';
import 'source_catalog_screen.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  bool _isNsfwEnabled = false;
  Set<String> _installedExtensions = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final nsfw = await DBHelper.instance.getSetting('nsfw_enabled');
      final ext = await DBHelper.instance.getSetting('installed_extensions');
      if (mounted) {
        setState(() {
          _isNsfwEnabled = nsfw == 'true';
          if (ext != null && ext.isNotEmpty) {
            _installedExtensions = ext.split(',').where((s) => s.isNotEmpty).toSet();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleInstallExtension(String key, String title) async {
    final messenger = ScaffoldMessenger.of(context);
    final isInstalled = _installedExtensions.contains(key);
    if (isInstalled) {
      _installedExtensions.remove(key);
      await DBHelper.instance.saveSetting('installed_extensions', _installedExtensions.join(','));
      setState(() {});
      messenger.showSnackBar(
        SnackBar(content: Text('Ekstensi $title telah dicopot.')),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text('Memasang ekstensi $title...')),
      );
      await Future.delayed(const Duration(milliseconds: 500));
      _installedExtensions.add(key);
      await DBHelper.instance.saveSetting('installed_extensions', _installedExtensions.join(','));
      if (mounted) {
        setState(() {});
        messenger.showSnackBar(
          SnackBar(
            content: Text('Ekstensi $title berhasil dipasang! Siap digunakan di tab Sumber Terpasang.'),
            backgroundColor: AppTheme.accentCyan,
          ),
        );
      }
    }
  }

  void _showEnableNsfwDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.explicit, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text('Konfirmasi Usia 18+', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Sumber dewasa seperti DoujinDesu memuat konten grafis khusus pembaca berusia 18 tahun ke atas. Apakah Anda berusia 18+ dan ingin membuka aksesnya?',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
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
            onPressed: () async {
              Navigator.pop(ctx);
              await DBHelper.instance.saveSetting('nsfw_enabled', 'true');
              setState(() => _isNsfwEnabled = true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sumber Dewasa (18+) telah diaktifkan.')),
                );
              }
            },
            child: const Text('Aktifkan (18+)'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Jelajahi Sumber'),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Pencarian Global ke Semua Sumber',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GlobalSearchScreen()),
                ).then((_) => _loadSettings());
              },
            ),
          ],
          bottom: const TabBar(
            indicatorColor: AppTheme.accentCyan,
            labelColor: AppTheme.accentCyan,
            unselectedLabelColor: AppTheme.textMuted,
            tabs: [
              Tab(text: 'Sumber Terpasang'),
              Tab(text: 'Ekstensi GitHub'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Sumber Terpasang (Bisa Diklik & Dibuka Langsung)
            ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildSourceItem(
                  context,
                  sourceId: 'komiku',
                  title: 'Komiku',
                  lang: 'ID (Indonesia - Ranking & Pustaka)',
                  version: 'v1.1.2',
                ),
                _buildSourceItem(
                  context,
                  sourceId: 'komikindo',
                  title: 'KomikIndo',
                  lang: 'ID (Indonesia - Google CDN WebP)',
                  version: 'v1.4.0',
                ),
                _buildSourceItem(
                  context,
                  sourceId: 'shinigami',
                  title: 'Shinigami',
                  lang: 'ID (Indonesia - Manhwa HD)',
                  version: 'v1.6.83',
                ),
                _buildSourceItem(
                  context,
                  sourceId: 'bacakomik',
                  title: 'BacaKomik',
                  lang: 'ID (Indonesia - Lengkap)',
                  version: 'v1.6.0',
                ),
                _buildSourceItem(
                  context,
                  sourceId: 'mangadex',
                  title: 'MangaDex',
                  lang: 'ALL (Multi-bahasa & ID)',
                  version: 'v2.1.0',
                ),
                _buildSourceItem(
                  context,
                  sourceId: 'kiryuu',
                  title: 'Kiryuu',
                  lang: 'ID (Indonesia - MangaStream)',
                  version: 'v1.4.2',
                ),
                _buildSourceItem(
                  context,
                  sourceId: 'ikiru',
                  title: 'Ikiru',
                  lang: 'ID (Indonesia - Manhwa & Manga HD)',
                  version: 'v1.0.0',
                ),
                _buildSourceItem(
                  context,
                  sourceId: 'luvyaa',
                  title: 'Mak Luvya',
                  lang: 'ID (Indonesia - Manhwa & Webtoon)',
                  version: 'v1.0.0',
                ),

                // Ekstensi yang dipasang secara dinamis oleh pengguna
                if (_installedExtensions.contains('manhwaindo'))
                  _buildSourceItem(
                    context,
                    sourceId: 'manhwaindo',
                    title: 'ManhwaIndo',
                    lang: 'ID (Indonesia - Webtoon Manhwa)',
                    version: 'v1.3.1',
                  ),
                if (_installedExtensions.contains('westmanga'))
                  _buildSourceItem(
                    context,
                    sourceId: 'westmanga',
                    title: 'WestManga',
                    lang: 'ID (Indonesia - Manga & Manhua)',
                    version: 'v2.0.0',
                  ),
                if (_installedExtensions.contains('bato'))
                  _buildSourceItem(
                    context,
                    sourceId: 'bato',
                    title: 'Bato.to',
                    lang: 'EN / ID (Komunitas Global)',
                    version: 'v2.0.1',
                  ),
                if (_installedExtensions.contains('asura'))
                  _buildSourceItem(
                    context,
                    sourceId: 'asurascans',
                    title: 'Asura Scans',
                    lang: 'EN (Manhwa Terjemahan Cepat)',
                    version: 'v1.9.0',
                  ),

                // Bagian Sumber Dewasa (18+ / NSFW)
                if (_isNsfwEnabled) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
                    child: Row(
                      children: [
                        Icon(Icons.explicit, color: Colors.redAccent, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Sumber Dewasa (18+ / NSFW)',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildSourceItem(
                    context,
                    sourceId: 'doujindesu',
                    title: 'DoujinDesu',
                    lang: 'ID (Doujinshi & Komik 18+)',
                    version: 'v1.4.3',
                    isNsfw: true,
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined, color: AppTheme.textMuted, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Sumber Dewasa (DoujinDesu 18+) disembunyikan.',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                            ),
                          ),
                          TextButton(
                            onPressed: _showEnableNsfwDialog,
                            child: const Text('Buka (18+)', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // Tab 2: Katalog Ekstensi GitHub
            ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildExtensionItem(
                  context,
                  key: 'manhwaindo',
                  title: 'ManhwaIndo',
                  lang: 'ID',
                  version: 'v1.3.1',
                  installed: _installedExtensions.contains('manhwaindo'),
                ),
                _buildExtensionItem(
                  context,
                  key: 'westmanga',
                  title: 'WestManga',
                  lang: 'ID',
                  version: 'v2.0.0',
                  installed: _installedExtensions.contains('westmanga'),
                ),
                _buildExtensionItem(
                  context,
                  key: 'bato',
                  title: 'Bato.to',
                  lang: 'EN / ID',
                  version: 'v2.0.1',
                  installed: _installedExtensions.contains('bato'),
                ),
                _buildExtensionItem(
                  context,
                  key: 'asura',
                  title: 'Asura Scans',
                  lang: 'EN',
                  version: 'v1.9.0',
                  installed: _installedExtensions.contains('asura'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceItem(
    BuildContext context, {
    required String sourceId,
    required String title,
    required String lang,
    required String version,
    bool isNsfw = false,
  }) {
    return ListTile(
      leading: SourceLogo(
        sourceId: sourceId,
        size: 42,
      ),
      title: Row(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (isNsfw) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.redAccent, width: 0.8),
              ),
              child: const Text(
                '18+',
                style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text('$lang • $version', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, color: AppTheme.textMuted, size: 16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SourceCatalogScreen(
              sourceId: sourceId,
              sourceName: title,
            ),
          ),
        );
      },
    );
  }

  Widget _buildExtensionItem(
    BuildContext context, {
    required String key,
    required String title,
    required String lang,
    required String version,
    required bool installed,
  }) {
    return ListTile(
      leading: SourceLogo(
        sourceId: title.toLowerCase().replaceAll('.', '').replaceAll(' ', ''),
        size: 42,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('$lang • $version', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      trailing: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: installed ? AppTheme.surfaceDark : AppTheme.accentCyan,
          foregroundColor: installed ? Colors.redAccent : Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          minimumSize: Size.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () => _toggleInstallExtension(key, title),
        child: Text(
          installed ? 'Copot' : 'Pasang',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
