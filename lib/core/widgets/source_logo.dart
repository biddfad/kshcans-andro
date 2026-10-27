import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SourceLogo extends StatelessWidget {
  final String sourceId;
  final double size;

  const SourceLogo({
    super.key,
    required this.sourceId,
    this.size = 32,
  });

  String get _assetPath {
    final id = sourceId.toLowerCase();
    if (id.contains('shinigami')) return 'assets/icons/shinigami.png';
    if (id.contains('bacakomik')) return 'assets/icons/bacakomik.png';
    if (id.contains('mangadex')) return 'assets/icons/mangadex.png';
    if (id.contains('kiryuu')) return 'assets/icons/kiryuu.png';
    if (id.contains('komiku')) return 'assets/icons/komiku.png';
    if (id.contains('komikindo')) return 'assets/icons/komikindo.png';
    if (id.contains('doujindesu')) return 'assets/icons/doujindesu.png';
    if (id.contains('westmanga')) return 'assets/icons/westmanga.png';
    if (id.contains('manhwaindo')) return 'assets/icons/manhwaindo.png';
    if (id.contains('bato')) return 'assets/icons/bato.png';
    if (id.contains('asura')) return 'assets/icons/asurascans.png';
    return 'assets/icons/bacakomik.png';
  }

  IconData get _fallbackIcon {
    final id = sourceId.toLowerCase();
    if (id.contains('shinigami')) return Icons.local_fire_department;
    if (id.contains('bacakomik')) return Icons.menu_book;
    if (id.contains('mangadex')) return Icons.public;
    if (id.contains('kiryuu')) return Icons.bolt;
    if (id.contains('komiku')) return Icons.import_contacts;
    if (id.contains('komikindo')) return Icons.auto_stories;
    if (id.contains('doujindesu')) return Icons.explicit;
    if (id.contains('westmanga')) return Icons.import_contacts;
    if (id.contains('manhwaindo')) return Icons.auto_stories;
    if (id.contains('bato')) return Icons.public;
    if (id.contains('asura')) return Icons.bolt;
    return Icons.auto_stories;
  }

  Color get _sourceColor {
    final id = sourceId.toLowerCase();
    if (id.contains('shinigami')) return const Color(0xFFFF5252);
    if (id.contains('bacakomik')) return const Color(0xFF00E5FF);
    if (id.contains('mangadex')) return const Color(0xFFFF6740);
    if (id.contains('kiryuu')) return const Color(0xFFFFD600);
    if (id.contains('komiku')) return const Color(0xFF4CAF50);
    if (id.contains('komikindo')) return const Color(0xFFAB47BC);
    if (id.contains('doujindesu')) return const Color(0xFFFF1744);
    if (id.contains('westmanga')) return const Color(0xFFFF9800);
    if (id.contains('manhwaindo')) return const Color(0xFF00BCD4);
    if (id.contains('bato')) return const Color(0xFFE91E63);
    if (id.contains('asura')) return const Color(0xFF9C27B0);
    return AppTheme.accentCyan;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.25),
        child: Image.asset(
          _assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(
                _fallbackIcon,
                color: _sourceColor,
                size: size * 0.6,
              ),
            );
          },
        ),
      ),
    );
  }
}
