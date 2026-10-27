import 'package:flutter_test/flutter_test.dart';
import 'package:aplikasibacakomik/core/services/security_service.dart';
import 'package:aplikasibacakomik/core/services/download_service.dart';

void main() {
  group('SecurityService Tests', () {
    test('hashPin produces 64-char SHA-256 hex string', () {
      final hash = SecurityService.hashPin('1234');
      expect(hash.length, 64);
      expect(hash, isNot('1234'));
    });

    test('verifyPin correctly matches hashed PIN', () {
      final hash = SecurityService.hashPin('5678');
      expect(SecurityService.verifyPin('5678', hash), isTrue);
      expect(SecurityService.verifyPin('1234', hash), isFalse);
      expect(SecurityService.verifyPin('0000', hash), isFalse);
    });

    test('verifyPin supports legacy plaintext PIN fallback', () {
      expect(SecurityService.verifyPin('4321', '4321'), isTrue);
      expect(SecurityService.verifyPin('1111', '4321'), isFalse);
      expect(SecurityService.verifyPin('1234', ''), isFalse);
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
