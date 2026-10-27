import 'package:flutter_test/flutter_test.dart';
import 'package:aplikasibacakomik/core/models/chapter.dart';

void main() {
  group('Infinity Reader Chapter Progression Logic Tests', () {
    test('Descending chapters progression (e.g. Chapter 10 down to Chapter 1)', () {
      final chapters = List.generate(
        10,
        (i) => Chapter(
          id: i + 1,
          mangaId: 1,
          url: 'https://komik.com/ch-${10 - i}',
          name: 'Chapter ${10 - i}',
          chapterNumber: (10 - i).toDouble(),
          dateUpload: 'Hari ini',
        ),
      );

      final isDescending = chapters.length > 1 &&
          chapters.first.chapterNumber > chapters.last.chapterNumber;
      expect(isDescending, true);

      // Mulai dari Chapter 1 (index 9)
      int currentIdx = 9;
      expect(chapters[currentIdx].chapterNumber, 1.0);

      // Next chapter setelah Chapter 1 haruslah Chapter 2 (index 8)
      int? nextIdx = isDescending ? (currentIdx > 0 ? currentIdx - 1 : null) : null;
      expect(nextIdx, 8);
      expect(chapters[nextIdx!].chapterNumber, 2.0);

      // Terus berlanjut sampai bab paling akhir (Chapter 10, index 0)
      currentIdx = 0;
      nextIdx = isDescending ? (currentIdx > 0 ? currentIdx - 1 : null) : null;
      expect(nextIdx, isNull); // Tidak ada bab selanjutnya (End of Manga)
    });

    test('Ascending chapters progression (e.g. Chapter 1 up to Chapter 10)', () {
      final chapters = List.generate(
        10,
        (i) => Chapter(
          id: i + 1,
          mangaId: 1,
          url: 'https://komik.com/ch-${i + 1}',
          name: 'Chapter ${i + 1}',
          chapterNumber: (i + 1).toDouble(),
          dateUpload: 'Hari ini',
        ),
      );

      final isDescending = chapters.length > 1 &&
          chapters.first.chapterNumber > chapters.last.chapterNumber;
      expect(isDescending, false);

      // Mulai dari Chapter 1 (index 0)
      int currentIdx = 0;
      expect(chapters[currentIdx].chapterNumber, 1.0);

      // Next chapter setelah Chapter 1 adalah Chapter 2 (index 1)
      int? nextIdx = !isDescending ? (currentIdx < chapters.length - 1 ? currentIdx + 1 : null) : null;
      expect(nextIdx, 1);
      expect(chapters[nextIdx!].chapterNumber, 2.0);

      // Pada bab terakhir (Chapter 10, index 9)
      currentIdx = 9;
      nextIdx = !isDescending ? (currentIdx < chapters.length - 1 ? currentIdx + 1 : null) : null;
      expect(nextIdx, isNull); // End of Manga
    });

    test('Single chapter manga progression', () {
      final chapters = [
        Chapter(
          id: 1,
          mangaId: 1,
          url: 'https://komik.com/oneshot',
          name: 'Oneshot',
          chapterNumber: 1.0,
          dateUpload: 'Hari ini',
        ),
      ];

      // Oneshot tidak memiliki next chapter
      final nextIdx = chapters.length > 1 ? 1 : null;
      expect(nextIdx, isNull);
    });
  });
}
