import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Layanan keamanan dan kriptografi untuk perlindungan privasi pengguna
class SecurityService {
  /// Jumlah iterasi PBKDF2. Membuat setiap tebakan PIN jauh lebih mahal
  /// dibanding SHA-256 tunggal.
  static const int pbkdf2Iterations = 20000;
  static const String _prefix = 'pbkdf2';

  /// Salt statis versi lama, hanya dipakai untuk memverifikasi lalu memigrasi hash lama.
  static const String _legacySalt = 'KsHcans_Secure_Salt_2026_@!';

  /// Batas salah PIN sebelum layar kunci dijeda
  static const int maxAttemptsBeforeLockout = 5;

  static bool isValidPinFormat(String pin) => RegExp(r'^\d{4}$').hasMatch(pin);

  /// Menghasilkan hash PIN dengan PBKDF2-HMAC-SHA256 dan salt acak per PIN.
  /// Format: `pbkdf2$<iterasi>$<salt base64>$<hash base64>`
  static Future<String> hashPin(String rawPin, {int iterations = pbkdf2Iterations}) async {
    final rng = Random.secure();
    final salt = Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));
    final derived = await Isolate.run(() => _pbkdf2(utf8.encode(rawPin), salt, iterations, 32));
    return '$_prefix\$$iterations\$${base64Encode(salt)}\$${base64Encode(derived)}';
  }

  /// Memverifikasi PIN terhadap hash tersimpan (format PBKDF2 baru atau SHA-256 lama).
  static Future<bool> verifyPin(String enteredPin, String storedPin) async {
    if (storedPin.isEmpty || !isValidPinFormat(enteredPin)) return false;

    final parts = storedPin.split('\$');
    if (parts.length == 4 && parts[0] == _prefix) {
      final iterations = int.tryParse(parts[1]);
      if (iterations == null || iterations <= 0) return false;
      final salt = base64Decode(parts[2]);
      final expected = base64Decode(parts[3]);
      final derived = await Isolate.run(
        () => _pbkdf2(utf8.encode(enteredPin), salt, iterations, expected.length),
      );
      return _constantTimeEquals(derived, expected);
    }

    if (isLegacyHash(storedPin)) {
      final legacy = sha256.convert(utf8.encode('$enteredPin$_legacySalt')).toString();
      return _constantTimeEquals(utf8.encode(legacy), utf8.encode(storedPin));
    }
    return false;
  }

  /// Hash SHA-256 versi lama (64 karakter hex) yang perlu dimigrasi ke PBKDF2
  static bool isLegacyHash(String stored) => RegExp(r'^[0-9a-f]{64}$').hasMatch(stored);

  /// PIN yang masih tersimpan sebagai teks biasa dari versi paling awal
  static bool isPlaintextPin(String stored) => isValidPinFormat(stored);

  /// Lama jeda setelah [failedAttempts] kali salah: 30 detik, lalu berlipat ganda
  /// tiap 5 kesalahan berikutnya, maksimal 1 jam.
  static Duration lockoutFor(int failedAttempts) {
    if (failedAttempts < maxAttemptsBeforeLockout) return Duration.zero;
    final level = failedAttempts ~/ maxAttemptsBeforeLockout - 1;
    final seconds = 30 * pow(2, min(level, 7)).toInt();
    return Duration(seconds: min(seconds, 3600));
  }

  static Uint8List _pbkdf2(List<int> password, List<int> salt, int iterations, int length) {
    final hmac = Hmac(sha256, password);
    final out = BytesBuilder();
    var block = 1;
    while (out.length < length) {
      final blockIndex = [block >> 24 & 0xff, block >> 16 & 0xff, block >> 8 & 0xff, block & 0xff];
      var u = hmac.convert([...salt, ...blockIndex]).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      out.add(t);
      block++;
    }
    return Uint8List.fromList(out.toBytes().sublist(0, length));
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
