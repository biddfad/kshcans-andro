import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import '../database/db_helper.dart';
import '../models/chapter.dart';
import '../models/manga.dart';
import 'app_http_overrides.dart';
import 'chapter_fetcher.dart';
import 'notification_service.dart';

class NewChaptersResult {
  final Manga manga;

  /// Bab baru, urutan sesuai sumber (biasanya terbaru lebih dulu)
  final List<Chapter> newChapters;

  const NewChaptersResult(this.manga, this.newChapters);
}

/// Titik masuk isolate latar belakang Workmanager (harus fungsi top-level)
@pragma('vm:entry-point')
void chapterUpdateCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = AppHttpOverrides();
    try {
      final enabled = await DBHelper.instance.getSetting(ChapterUpdateService.settingKey);
      if (enabled != 'true') return true;
      final results = await ChapterUpdateService.checkLibrary();
      await NotificationService.showNewChapters(results);
    } catch (e) {
      debugPrint('Pengecekan bab baru gagal: $e');
    }
    // Selalu "berhasil" agar Android tidak mengulang terus-menerus; jadwal berikutnya tetap jalan
    return true;
  });
}

/// Pengecekan berkala bab baru untuk komik di Pustaka
class ChapterUpdateService {
  static const String settingKey = 'notify_new_chapters';
  static const String _uniqueTaskName = 'kshcans_new_chapters';
  static const Duration checkInterval = Duration(hours: 6);

  /// Pengecekan latar belakang hanya didukung di Android
  static bool get isSupported => Platform.isAndroid;

  static Future<void> initialize() async {
    if (!isSupported) return;
    await Workmanager().initialize(chapterUpdateCallbackDispatcher);
  }

  static Future<void> setEnabled(bool enabled) async {
    await DBHelper.instance.saveSetting(settingKey, enabled ? 'true' : 'false');
    if (!isSupported) return;
    if (enabled) {
      // Tandai bab yang sudah ada sekarang sebagai "diketahui" agar tidak muncul notifikasi palsu
      await checkLibrary();
      await Workmanager().registerPeriodicTask(
        _uniqueTaskName,
        _uniqueTaskName,
        frequency: checkInterval,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
    } else {
      await Workmanager().cancelByUniqueName(_uniqueTaskName);
    }
  }

  /// Bandingkan daftar bab terbaru dengan yang sudah diketahui untuk setiap komik di Pustaka.
  /// Komik yang baru pertama kali dicek hanya dicatat (tidak dianggap punya bab baru).
  static Future<List<NewChaptersResult>> checkLibrary({
    Future<List<Chapter>> Function(Manga manga)? fetcher,
  }) async {
    final fetch = fetcher ?? ChapterFetcher.fetch;
    final results = <NewChaptersResult>[];
    for (final manga in await DBHelper.instance.getLibraryManga()) {
      final List<Chapter> chapters;
      try {
        chapters = await fetch(manga);
      } catch (_) {
        continue; // Sumber sedang bermasalah - coba lagi di jadwal berikutnya
      }
      if (chapters.isEmpty) continue;

      final known = await DBHelper.instance.getKnownChapterUrls(manga.url);
      final fresh = chapters.where((c) => !known.contains(c.url)).toList();
      if (fresh.isEmpty) continue;
      await DBHelper.instance.addKnownChapters(manga.url, fresh.map((c) => c.url));
      if (known.isNotEmpty) results.add(NewChaptersResult(manga, fresh));
    }
    return results;
  }
}
