import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aplikasibacakomik/core/models/chapter.dart';
import 'package:aplikasibacakomik/core/models/manga.dart';
import 'package:aplikasibacakomik/core/theme/app_theme.dart';
import 'package:aplikasibacakomik/features/reader/screens/reader_screen.dart';
import 'package:aplikasibacakomik/features/reader/widgets/zoomable_page.dart';
import 'package:aplikasibacakomik/providers/manga_provider.dart';
import 'package:aplikasibacakomik/providers/theme_provider.dart';

class _HttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _HttpOverrides();
  });

  final testChapters = [
    Chapter(
      id: 1,
      mangaId: 10,
      url: 'https://komik.com/ch-2',
      name: 'Chapter 2: Pertarungan Sengit',
      chapterNumber: 2.0,
      dateUpload: '1 hari lalu',
    ),
    Chapter(
      id: 2,
      mangaId: 10,
      url: 'https://komik.com/ch-1',
      name: 'Chapter 1: Awal Mula',
      chapterNumber: 1.0,
      dateUpload: '2 hari lalu',
    ),
  ];

  final testManga = Manga(
    id: 10,
    sourceId: 'shinigami',
    url: 'test-manga-id',
    title: 'Solo Leveling Test',
    author: 'Chugong',
    description: 'Manhwa hunter terkuat',
    genre: 'Action, Fantasy',
    status: 'Ongoing',
    thumbnailUrl: 'https://cdn.shinigami.gg/assets/cover.jpg',
  );

  Widget createReaderWidget({int initialIndex = 1}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => MangaProvider()),
      ],
      child: MaterialApp(
        theme: AppTheme.oledTheme,
        home: ReaderScreen(
          mangaTitle: testManga.title,
          manga: testManga,
          chapters: testChapters,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  testWidgets('ReaderScreen renders initial controls, title, and buttons', (WidgetTester tester) async {
    await tester.pumpWidget(createReaderWidget(initialIndex: 1)); // Chapter 1
    await tester.pump(const Duration(milliseconds: 100));

    // 1. Verifikasi header judul manga dan nama chapter
    expect(find.text('Solo Leveling Test'), findsOneWidget);
    expect(find.text('Chapter 1: Awal Mula'), findsWidgets);

    // 2. Verifikasi tombol navigasi utama di app bar atas
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen), findsOneWidget); // Ikon fullscreen
    expect(find.byIcon(Icons.format_list_bulleted), findsOneWidget); // Ikon daftar bab
    expect(find.byIcon(Icons.settings), findsOneWidget); // Ikon pengaturan mode baca
  });

  testWidgets('ReaderScreen can open chapter list bottom sheet modal', (WidgetTester tester) async {
    await tester.pumpWidget(createReaderWidget(initialIndex: 1));
    await tester.pump(const Duration(milliseconds: 100));

    // Klik tombol daftar bab di app bar atas
    final listButton = find.byIcon(Icons.format_list_bulleted);
    expect(listButton, findsOneWidget);
    await tester.tap(listButton);
    await tester.pump(const Duration(milliseconds: 300));

    // Verifikasi modal terbuka dengan daftar bab
    expect(find.text('Pilih Bab'), findsOneWidget);
    expect(find.text('2 Bab'), findsOneWidget);
    expect(find.text('Chapter 2: Pertarungan Sengit'), findsWidgets);
  });

  testWidgets('ReaderScreen can open reader settings bottom sheet modal', (WidgetTester tester) async {
    await tester.pumpWidget(createReaderWidget(initialIndex: 1));
    await tester.pump(const Duration(milliseconds: 100));

    // Klik tombol pengaturan pembaca di app bar atas
    final settingsButton = find.byIcon(Icons.settings);
    expect(settingsButton, findsOneWidget);
    await tester.tap(settingsButton);
    await tester.pump(const Duration(milliseconds: 300));

    // Verifikasi opsi 3 mode baca tersedia
    expect(find.text('Pengaturan Pembaca'), findsOneWidget);
    expect(find.text('Mode Webtoon (Infinity Continuous Scroll)'), findsOneWidget);
    expect(find.text('Mode Manga (Geser Kanan ke Kiri / RTL)'), findsOneWidget);
    expect(find.text('Mode Standar (Geser Kiri ke Kanan / LTR)'), findsOneWidget);
  });

  testWidgets('ZoomablePage widget double-tap and zoom functionality', (WidgetTester tester) async {
    bool zoomReported = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ZoomablePage(
            onZoomChanged: (zoomed) => zoomReported = zoomed,
            child: Container(key: const Key('page_img'), width: 300, height: 500, color: Colors.blue),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('page_img')), findsOneWidget);
    expect(zoomReported, false);

    // Double tap untuk zoom
    await tester.tap(find.byKey(const Key('page_img')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('page_img')));
    await tester.pumpAndSettle();

    // Verifikasi zoom aktif
    expect(zoomReported, true);

    // Double tap lagi untuk reset zoom
    await tester.tap(find.byKey(const Key('page_img')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('page_img')));
    await tester.pumpAndSettle();

    // Verifikasi zoom reset
    expect(zoomReported, false);
  });
}
