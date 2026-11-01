import 'package:flutter/services.dart';

/// Mengaktifkan FLAG_SECURE di Android: memblokir screenshot / rekam layar
/// dan menampilkan layar kosong di menu Recent Apps (Anti-Intip).
class SecureScreenService {
  static const MethodChannel _channel = MethodChannel('kshcans/secure_screen');

  static Future<void> setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setSecure', {'enabled': enabled});
    } on MissingPluginException {
      // Platform tanpa implementasi native (mis. iOS / test) - abaikan
    } on PlatformException {
      // Gagal di sisi native - abaikan agar aplikasi tetap berjalan
    }
  }
}
