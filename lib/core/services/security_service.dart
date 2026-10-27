import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Layanan keamanan dan kriptografi untuk perlindungan privasi pengguna
class SecurityService {
  static const String _pinSalt = 'KsHcans_Secure_Salt_2026_@!';

  /// Menghasilkan hash kriptografis SHA-256 untuk PIN 4-digit
  static String hashPin(String rawPin) {
    final bytes = utf8.encode('$rawPin$_pinSalt');
    return sha256.convert(bytes).toString();
  }

  /// Memverifikasi kecocokan PIN yang dimasukkan dengan data tersimpan di SQLite
  /// Mendukung kompatibilitas ke belakang (jika sebelumnya tersimpan sebagai plain text)
  static bool verifyPin(String enteredPin, String storedPin) {
    if (storedPin.isEmpty) return false;
    // Cek kecocokan hash SHA-256
    if (hashPin(enteredPin) == storedPin) return true;
    // Fallback kompatibilitas dengan PIN lama (plain text)
    if (enteredPin == storedPin) return true;
    return false;
  }
}
