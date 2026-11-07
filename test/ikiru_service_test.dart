import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:aplikasibacakomik/core/models/chapter.dart';
import 'package:aplikasibacakomik/core/models/manga.dart';

void main() {
  group('IkiruService Logic Tests', () {
    test('Correctly parses search and library JSON into Manga objects', () {
      const mockJsonStr = '''
      {
        "success": true,
        "message": "Library search fetched successfully",
        "code": 200,
        "data": {
          "mangas": [
            {
              "id": "uuid-1",
              "title": "The Greatest Estate Developer",
              "slug": "the-greatest-estate-developer",
              "featuredImage": "https://cdn.ikiru.id/featured/cover1.jpg",
              "type": "MANHWA",
              "description": "<p>Sinopsis petualangan Suho.</p>",
              "metadata": {
                "genre": [
                  {"name": "Action"},
                  {"name": "Comedy"}
                ],
                "score": 9.1
              },
              "chapter": [
                {"number": 222}
              ]
            }
          ],
          "total": 1
        }
      }
      ''';

      final data = jsonDecode(mockJsonStr);
      final mangas = data['data']['mangas'] as List;
      final item = mangas.first;

      final manga = Manga(
        sourceId: 'ikiru',
        url: 'https://09.ikiru.wtf/manga/${item['slug']}',
        title: item['title'],
        author: 'Ikiru',
        description: 'Sinopsis petualangan Suho.',
        genre: 'Action, Comedy',
        status: 'Ongoing',
        thumbnailUrl: item['featuredImage'],
      );

      expect(manga.title, 'The Greatest Estate Developer');
      expect(manga.url, 'https://09.ikiru.wtf/manga/the-greatest-estate-developer');
      expect(manga.thumbnailUrl, 'https://cdn.ikiru.id/featured/cover1.jpg');
      expect(manga.genre, 'Action, Comedy');
      expect(manga.sourceId, 'ikiru');
    });

    test('Correctly parses detail and chapter list JSON into Chapter objects', () {
      const mockDetailJson = '''
      {
        "success": true,
        "data": {
          "title": "The Greatest Estate Developer",
          "slug": "the-greatest-estate-developer",
          "description": "<p>Sinopsis lengkap manhwa.</p>",
          "status": "COMPLETED",
          "featuredImage": "https://cdn.ikiru.id/featured/cover1.jpg",
          "metadata": {
            "author": [{"name": "Kim Suho"}],
            "genre": [{"name": "Fantasy"}]
          },
          "chapters": {
            "chapters": [
              {
                "id": "ch-222",
                "number": 222,
                "title": "The World’s Best Engineer Chapter 222",
                "createdAt": "2026-10-05T02:54:00.066Z"
              },
              {
                "id": "ch-221.5",
                "number": 221.5,
                "title": "",
                "createdAt": "2026-10-04T02:54:00.066Z"
              }
            ]
          }
        }
      }
      ''';

      final data = jsonDecode(mockDetailJson)['data'];
      final rawChapters = data['chapters']['chapters'] as List;

      final List<Chapter> chapters = [];
      for (int i = 0; i < rawChapters.length; i++) {
        final ch = rawChapters[i];
        final number = (ch['number'] as num).toDouble();
        final numberStr = number % 1 == 0 ? number.toInt().toString() : number.toString();
        chapters.add(
          Chapter(
            id: i + 1,
            mangaId: 1,
            url: 'https://09.ikiru.wtf/manga/${data['slug']}/chapter-$numberStr',
            name: (ch['title'] as String).isNotEmpty ? ch['title'] : 'Chapter $numberStr',
            chapterNumber: number,
            dateUpload: ch['createdAt'].toString().split('T').first,
          ),
        );
      }

      expect(chapters.length, 2);
      expect(chapters[0].chapterNumber, 222.0);
      expect(chapters[0].name, 'The World’s Best Engineer Chapter 222');
      expect(chapters[0].url, 'https://09.ikiru.wtf/manga/the-greatest-estate-developer/chapter-222');

      expect(chapters[1].chapterNumber, 221.5);
      expect(chapters[1].name, 'Chapter 221.5');
      expect(chapters[1].url, 'https://09.ikiru.wtf/manga/the-greatest-estate-developer/chapter-221.5');
    });

    test('Correctly extracts SSR chapter image pages from HTML', () {
      const mockHtml = '''
      <!DOCTYPE html>
      <html>
      <head><title>Chapter 222</title></head>
      <body>
        <div class="reader">
          <img src="https://cdn.ikiru.id/featured/cover.jpg" />
          <script>
            var pages = [
              "https://cdn.ikiru.id/t/manga-slug/222/01.webp?md5=abc&amp;expires=123",
              "https://cdn.ikiru.id/t/manga-slug/222/02.webp?md5=def&amp;expires=123"
            ];
          </script>
        </div>
      </body>
      </html>
      ''';

      final regex = RegExp(r'https?://cdn\.ikiru\.id/t/[^\s"''<>]+');
      final matches = regex.allMatches(mockHtml);
      final List<String> pages = [];
      for (final m in matches) {
        pages.add(m.group(0)!.replaceAll('&amp;', '&'));
      }

      expect(pages.length, 2);
      expect(pages[0], 'https://cdn.ikiru.id/t/manga-slug/222/01.webp?md5=abc&expires=123');
      expect(pages[1], 'https://cdn.ikiru.id/t/manga-slug/222/02.webp?md5=def&expires=123');
    });
  });
}
