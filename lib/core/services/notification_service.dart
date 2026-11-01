import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'chapter_update_service.dart';

/// Menampilkan notifikasi lokal untuk bab komik baru
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Batas notifikasi per pengecekan agar tidak membanjiri panel notifikasi
  static const int _maxPerCheck = 5;

  static const AndroidNotificationDetails _androidDetails = AndroidNotificationDetails(
    'new_chapters',
    'Bab Baru',
    channelDescription: 'Pemberitahuan saat komik di Pustaka merilis bab baru',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Izin diminta lewat requestPermission() saat pengguna mengaktifkan fitur
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  /// Minta izin notifikasi (Android 13+ / iOS). Mengembalikan false jika ditolak.
  static Future<bool> requestPermission() async {
    await _ensureInitialized();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) return await ios.requestPermissions(alert: true, sound: true) ?? false;
    return false;
  }

  static Future<void> showNewChapters(List<NewChaptersResult> results) async {
    if (results.isEmpty) return;
    await _ensureInitialized();
    const details = NotificationDetails(android: _androidDetails, iOS: DarwinNotificationDetails());

    for (final result in results.take(_maxPerCheck)) {
      final count = result.newChapters.length;
      final latest = result.newChapters.first.name;
      await _plugin.show(
        id: result.manga.url.hashCode & 0x7fffffff,
        title: result.manga.title,
        body: count == 1 ? 'Bab baru: $latest' : '$count bab baru (terbaru: $latest)',
        notificationDetails: details,
      );
    }

    final remaining = results.length - _maxPerCheck;
    if (remaining > 0) {
      await _plugin.show(
        id: 0,
        title: 'KsHcans',
        body: 'Dan $remaining komik lain di Pustaka juga punya bab baru',
        notificationDetails: details,
      );
    }
  }
}
