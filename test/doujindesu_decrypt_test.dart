import 'dart:convert';
import 'dart:io';
import 'package:aplikasibacakomik/core/services/app_http_overrides.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class DoujinDesuDecryptor {
  static const String salt = 'doujindesu-scrapers-cannot-read-this-super-secret-salt-2026-v2';
  static const int hourMs = 3600000;

  static int toSigned32(int x) {
    var y = x & 0xFFFFFFFF;
    if (y >= 0x80000000) {
      y -= 0x100000000;
    }
    return y;
  }

  static String wH(int e) {
    final t = '${salt}_$e';
    int a = 0;
    for (int i = 0; i < t.length; i++) {
      final code = t.codeUnitAt(i);
      a = (a << 5) - a + code;
      a = toSigned32(a);
    }
    int l = a != 0 ? a.abs() : 123456789;
    final buffer = StringBuffer();
    for (int i = 0; i < 32; i++) {
      l = (l * 1664525 + 1013904223) % 4294967296;
      buffer.writeCharCode(33 + (l % 93));
    }
    return buffer.toString();
  }

  static List<String> lU() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final t = now ~/ hourMs;
    return [wH(t), wH(t - 1), wH(t + 1)];
  }

  static String yre(String encryptedHex, String key) {
    final bytes = <int>[];
    for (int i = 0; i < encryptedHex.length; i += 2) {
      final sub = encryptedHex.substring(i, i + 2);
      final val = int.tryParse(sub, radix: 16);
      if (val != null) bytes.add(val);
    }
    int d = 42;
    final keyLen = key.length;
    final buffer = StringBuffer();
    for (int idx = 0; idx < bytes.length; idx++) {
      final byteVal = bytes[idx];
      final keyChar = key.codeUnitAt(idx % keyLen);
      final k = byteVal ^ keyChar ^ (idx * 13) ^ d;
      buffer.writeCharCode(k & 0xFF);
      d = (d + byteVal) % 256;
    }
    return buffer.toString();
  }

  static String? decrypt(String encryptedHex) {
    for (final key in lU()) {
      try {
        final decoded = yre(encryptedHex, key);
        return Uri.decodeComponent(decoded);
      } catch (_) {}
    }
    return null;
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = AppHttpOverrides();
  });

  test('DoujinDesu live API fetch and decrypt test', () async {
    final url = Uri.parse('https://doujin.desu.xxx/api/manga?limit=5&offset=0&sort=rating');
    final resp = await http.get(url, headers: {
      'x-app-secret': 'dfdf72051dbfdc7d76889ebd31324e74',
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    }).timeout(const Duration(seconds: 15));

    expect(resp.statusCode, 200);

    final rawJson = jsonDecode(resp.body);
    final encrypted = rawJson['_enc_resp_'] as String?;
    expect(encrypted, isNotNull);

    final decrypted = DoujinDesuDecryptor.decrypt(encrypted!);
    expect(decrypted, isNotNull);
    final parsed = jsonDecode(decrypted!) as List;
    final firstItem = parsed[0];
    final slug = firstItem['slug'];

    final detailUrl = Uri.parse('https://doujin.desu.xxx/api/manga/$slug');
    final detailResp = await http.get(detailUrl, headers: {
      'x-app-secret': 'dfdf72051dbfdc7d76889ebd31324e74',
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    });
    final detailEnc = jsonDecode(detailResp.body)['_enc_resp_'] as String;
    final detailDec = DoujinDesuDecryptor.decrypt(detailEnc)!;
    final detailJson = jsonDecode(detailDec);

    final chapters = detailJson['chapters'] as List;
    expect(chapters.isNotEmpty, true);

    final firstChId = chapters[0]['id'];
    final chUrl = Uri.parse('https://doujin.desu.xxx/api/chapters/$firstChId');
    final chResp = await http.get(chUrl, headers: {
      'x-app-secret': 'dfdf72051dbfdc7d76889ebd31324e74',
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    });
    final chEnc = jsonDecode(chResp.body)['_enc_resp_'] as String;
    final chDec = DoujinDesuDecryptor.decrypt(chEnc)!;
    final chJson = jsonDecode(chDec);
    final pages = chJson['content_urls'] as List;
    expect(pages.isNotEmpty, true);
  });
}
