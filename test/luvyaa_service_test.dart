import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:aplikasibacakomik/core/models/chapter.dart';
import 'package:aplikasibacakomik/core/models/manga.dart';

void main() {
  group('LuvyaaService Logic Tests', () {
    test('Correctly parses MangaThemesia bsx cards into Manga objects', () {
      const mockHtml = '''
      <div class="listupd">
        <div class="bsx">
          <a href="https://v5.luvyaa.co/study-group/" title="Study Group">
            <div class="limit">
              <span class="type Manhwa"></span>
              <img src="https://v5.luvyaa.co/wp-content/uploads/2026/01/study.jpg" />
            </div>
            <div class="bigor">
              <div class="tt">Study Group</div>
              <div class="adds">
                <div class="epxs">Chapter 441</div>
              </div>
            </div>
          </a>
        </div>
      </div>
      ''';

      final document = html_parser.parse(mockHtml);
      final cards = document.querySelectorAll('div.bsx');
      expect(cards.length, 1);

      final card = cards.first;
      final aTag = card.querySelector('a')!;
      final title = aTag.attributes['title']!;
      final href = aTag.attributes['href']!;
      final thumb = card.querySelector('img')!.attributes['src']!;

      final manga = Manga(
        sourceId: 'luvyaa',
        url: href,
        title: title,
        author: 'Mak Luvya',
        description: 'Komik Bahasa Indonesia dari Mak Luvya',
        genre: 'Manhwa',
        status: 'Ongoing',
        thumbnailUrl: thumb,
      );

      expect(manga.title, 'Study Group');
      expect(manga.url, 'https://v5.luvyaa.co/study-group/');
      expect(manga.thumbnailUrl, 'https://v5.luvyaa.co/wp-content/uploads/2026/01/study.jpg');
      expect(manga.sourceId, 'luvyaa');
    });

    test('Correctly parses chapters and detects lockedUrls VIP protection', () {
      const mockDetailHtml = '''
      <html>
      <head>
        <meta property="og:description" content="Kisah anak SMA yang pandai berkelahi." />
        <meta property="og:image" content="https://v5.luvyaa.co/cover.jpg" />
      </head>
      <body>
        <script>
          var lockedUrls = ["https://v5.luvyaa.co/study-group-chapter-442/"];
        </script>
        <div id="chapterlist">
          <ul>
            <li data-num="442">
              <a href="https://v5.luvyaa.co/study-group-chapter-442/">
                <span class="chapternum">Chapter 442</span>
                <span class="chapterdate">2 jam lalu</span>
              </a>
            </li>
            <li data-num="441">
              <a href="https://v5.luvyaa.co/study-group-chapter-441/">
                <span class="chapternum">Chapter 441</span>
                <span class="chapterdate">kemarin</span>
              </a>
            </li>
          </ul>
        </div>
      </body>
      </html>
      ''';

      // Ekstraksi lockedUrls
      final Set<String> lockedUrls = {};
      final lockedRegex = RegExp(r'lockedUrls\s*=\s*\[(.*?)\]');
      final match = lockedRegex.firstMatch(mockDetailHtml);
      if (match != null) {
        for (final item in match.group(1)!.split(',')) {
          final clean = item.trim().replaceAll("'", '').replaceAll('"', '').replaceAll(r'\/', '/');
          if (clean.isNotEmpty) lockedUrls.add(clean);
        }
      }

      final document = html_parser.parse(mockDetailHtml);
      final nodes = document.querySelectorAll('div#chapterlist ul li[data-num]');
      final List<Chapter> chapters = [];

      for (int i = 0; i < nodes.length; i++) {
        final node = nodes[i];
        final chNum = double.parse(node.attributes['data-num']!);
        final aTag = node.querySelector('a')!;
        final chUrl = aTag.attributes['href']!;
        final isLocked = lockedUrls.any((locked) => chUrl.endsWith(locked) || chUrl.contains(locked));
        final rawTitle = aTag.querySelector('.chapternum')?.text.trim() ?? 'Chapter $chNum';
        final chName = isLocked ? '🔒 $rawTitle' : rawTitle;

        chapters.add(
          Chapter(
            id: i + 1,
            mangaId: 1,
            url: chUrl,
            name: chName,
            chapterNumber: chNum,
            dateUpload: node.querySelector('.chapterdate')?.text.trim() ?? '',
          ),
        );
      }

      expect(chapters.length, 2);
      expect(chapters[0].chapterNumber, 442.0);
      expect(chapters[0].name, '🔒 Chapter 442'); // Harus terkunci dengan ikon gembok

      expect(chapters[1].chapterNumber, 441.0);
      expect(chapters[1].name, 'Chapter 441'); // Bebas / gratis
    });

    test('Correctly extracts reader pages from readerarea div', () {
      const mockReaderHtml = '''
      <div id="readerarea">
        <p>Silakan baca chapter di bawah ini</p>
        <img src="https://img2.cdn-nyaa.link/i/123/01.webp?v=1" />
        <img src="https://img2.cdn-nyaa.link/i/123/02.webp?v=1" />
        <img src="https://v5.luvyaa.co/banner.gif" />
      </div>
      ''';

      final document = html_parser.parse(mockReaderHtml);
      final readerArea = document.querySelector('div#readerarea')!;
      final pages = <String>[];

      for (final img in readerArea.querySelectorAll('img')) {
        final src = img.attributes['src'] ?? '';
        if (src.isNotEmpty && !src.contains('.gif') && !src.contains('banner')) {
          pages.add(src);
        }
      }

      expect(pages.length, 2);
      expect(pages[0], 'https://img2.cdn-nyaa.link/i/123/01.webp?v=1');
      expect(pages[1], 'https://img2.cdn-nyaa.link/i/123/02.webp?v=1');
    });
  });
}
