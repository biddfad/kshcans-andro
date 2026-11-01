import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aplikasibacakomik/core/services/security_service.dart';
import 'package:aplikasibacakomik/core/services/download_service.dart';

void main() {
  group('SecurityService Tests', () {
    test('hashPin produces salted PBKDF2 hash that never contains the PIN', () async {
      final hash = await SecurityService.hashPin('1234');
      expect(hash.startsWith('pbkdf2\$${SecurityService.pbkdf2Iterations}\$'), isTrue);
      expect(hash.contains('1234'), isFalse);
    });

    test('hashPin uses a random salt per call', () async {
      final a = await SecurityService.hashPin('1234');
      final b = await SecurityService.hashPin('1234');
      expect(a, isNot(b));
    });

    test('verifyPin correctly matches hashed PIN', () async {
      final hash = await SecurityService.hashPin('5678');
      expect(await SecurityService.verifyPin('5678', hash), isTrue);
      expect(await SecurityService.verifyPin('1234', hash), isFalse);
      expect(await SecurityService.verifyPin('0000', hash), isFalse);
    });

    test('verifyPin still accepts legacy SHA-256 hashes for migration', () async {
      // Hash SHA-256 versi lama untuk PIN '2468'
      final legacy = sha256.convert(utf8.encode('2468KsHcans_Secure_Salt_2026_@!')).toString();
      expect(SecurityService.isLegacyHash(legacy), isTrue);
      expect(await SecurityService.verifyPin('2468', legacy), isTrue);
      expect(await SecurityService.verifyPin('1111', legacy), isFalse);
    });

    test('verifyPin no longer accepts plaintext PIN storage', () async {
      expect(await SecurityService.verifyPin('4321', '4321'), isFalse);
      expect(await SecurityService.verifyPin('1234', ''), isFalse);
      expect(SecurityService.isPlaintextPin('4321'), isTrue);
    });

    test('lockoutFor starts after 5 failures and grows', () {
      expect(SecurityService.lockoutFor(4), Duration.zero);
      expect(SecurityService.lockoutFor(5), const Duration(seconds: 30));
      expect(SecurityService.lockoutFor(10), const Duration(seconds: 60));
      expect(SecurityService.lockoutFor(1000), const Duration(hours: 1));
    });
  });

  group('DownloadService Sanitization Tests', () {
    test('sanitizeFolderName cleans illegal filesystem characters', () {
      final safe = DownloadService.sanitizeFolderName('Manga: Cool / Epic * Chapter? "Special" <1> | 2');
      expect(safe.contains(':'), isFalse);
      expect(safe.contains('/'), isFalse);
      expect(safe.contains('*'), isFalse);
      expect(safe.contains('?'), isFalse);
      expect(safe.contains('"'), isFalse);
      expect(safe.contains('<'), isFalse);
      expect(safe.contains('>'), isFalse);
      expect(safe.contains('|'), isFalse);
    });

    test('sanitizeFolderName trims leading and trailing dots', () {
      final safe = DownloadService.sanitizeFolderName('...Chapter 1...');
      expect(safe.startsWith('.'), isFalse);
      expect(safe.endsWith('.'), isFalse);
    });

    test('sanitizeFolderName caps excessively long names to 80 chars', () {
      final longName = 'A' * 150;
      final safe = DownloadService.sanitizeFolderName(longName);
      expect(safe.length, lessThanOrEqualTo(80));
    });

    test('sanitizeFolderName falls back to untitled if input is empty', () {
      final safe = DownloadService.sanitizeFolderName('   :::   ');
      expect(safe, isNotEmpty);
    });
  });
}
