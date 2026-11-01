import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../core/models/manga.dart';
import '../../../core/services/source_config_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/manga_provider.dart';
import '../../detail/screens/manga_detail_screen.dart';

class MangaCard extends StatelessWidget {
  final Manga manga;

  const MangaCard({super.key, required this.manga});

  Map<String, String> _getImageHeaders(Manga manga) {
    return SourceConfigService.getImageHeaders(manga.sourceId, manga.thumbnailUrl);
  }

  @override
  Widget build(BuildContext context) {
    final isInLibrary = context.watch<MangaProvider>().isMangaInLibrary(manga.url) || manga.inLibrary;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MangaDetailScreen(manga: manga),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: AppTheme.cardDark,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Gambar Sampul / Cover
              CachedNetworkImage(
                imageUrl: manga.thumbnailUrl,
                fit: BoxFit.cover,
                httpHeaders: _getImageHeaders(manga),
                placeholder: (context, url) => Container(
                  color: AppTheme.surfaceDark,
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentCyan),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppTheme.cardDark,
                  padding: const EdgeInsets.all(8),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_stories,
                          color: AppTheme.accentCyan.withValues(alpha: 0.6),
                          size: 32,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          manga.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Gradient Bayangan Bawah untuk Keterbacaan Judul
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 80,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.95),
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Judul Komik
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Text(
                  manga.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),

              // Badge "Di Pustaka"
              if (isInLibrary)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark, size: 11, color: Colors.black),
                        SizedBox(width: 2),
                        Text(
                          'Pustaka',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Badge Jumlah Bab Belum Dibaca (Unread Count)
              if (manga.unreadCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.unreadBadgeRed,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '${manga.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
