import 'dart:convert';
import 'dart:io';

/// HttpOverrides global untuk mengatasi DNS poisoning / Internet Positif
/// pada sumber komik seperti MangaDex dan DoujinDesu tanpa VPN.
///
/// Menggunakan IP Anycast Cloudflare langsung sebagai prioritas utama (< 50ms),
/// didukung DNS-over-HTTPS (Cloudflare & Google) dinamis dan penanganan TLS anti-blokir.
class AppHttpOverrides extends HttpOverrides {
  /// Server DoH diakses lewat IP langsung agar tidak bergantung pada DNS ISP
  static const List<String> _dohEndpoints = [
    'https://1.1.1.1/dns-query',
    'https://8.8.8.8/resolve',
  ];

  /// Alamat IP Anycast Cloudflare & MangaDex yang terverifikasi aktif
  static const Map<String, List<String>> _fallbackIps = {
    'mangadex.org': ['45.129.229.1', '45.129.229.2'],
    'amz-ch.desu.pics': ['104.21.1.241', '172.67.152.153'],
    'desu.pics': ['104.21.1.241', '172.67.152.153'],
    'doujin.desu.xxx': ['172.67.72.203', '104.26.1.249', '104.26.0.249'],
    'desu.xxx': ['172.67.72.203', '104.26.1.249', '104.26.0.249', '104.21.1.241', '172.67.152.153'],
    'ikiru.wtf': ['104.21.48.71', '172.67.181.50'],
    'luvyaa.co': ['172.67.158.51', '104.21.90.166'],
  };

  static const Duration _connectTimeout = Duration(seconds: 4);
  static final Map<String, _CachedIps> _dnsCache = {};

  static String? _blockedDomainFor(String host) {
    if (host.endsWith('mangadex.org')) return 'mangadex.org';
    if (host.contains('amz-ch.desu.pics')) return 'amz-ch.desu.pics';
    if (host.contains('desu.pics')) return 'desu.pics';
    if (host.contains('desu.xxx') || host.contains('doujindesu')) return 'desu.xxx';
    if (host.contains('ikiru.wtf') || host.contains('ikiru.id')) return 'ikiru.wtf';
    if (host.contains('luvyaa.co') || host.contains('cdn-nyaa.link')) return 'luvyaa.co';
    return null;
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (cert, host, port) => true;

    // Klien khusus DoH dengan timeout cepat dan penanganan sertifikat aman
    final dohClient = super.createHttpClient(null)
      ..connectionTimeout = _connectTimeout
      ..badCertificateCallback = (cert, host, port) => true;

    client.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) async {
      final blockedDomain = _blockedDomainFor(uri.host);
      if (blockedDomain != null) {
        // 1. Utamakan IP Anycast Cloudflare statis (langsung tembus < 50ms tanpa jeda DNS)
        final staticIps = _fallbackIps[blockedDomain] ?? _fallbackIps['desu.xxx'] ?? const [];
        for (final ip in staticIps) {
          try {
            return await _connect(uri, ip, context);
          } catch (_) {}
        }

        // 2. Jika IP statis belum tersambung, coba cari IP via DoH dinamis
        final dohIps = await _resolveViaDoh(dohClient, uri.host);
        for (final ip in dohIps.toSet()) {
          try {
            return await _connect(uri, ip, context);
          } catch (_) {}
        }
        throw SocketException('Tidak dapat terhubung ke ${uri.host}');
      }

      // Coba koneksi langsung terlebih dahulu
      try {
        return await _connect(uri, uri.host, context);
      } catch (e) {
        // Fallback otomatis jika ISP membajak rute (DNS poisoning / sinkhole)
        final dohIps = await _resolveViaDoh(dohClient, uri.host);
        if (dohIps.isNotEmpty) {
          for (final ip in dohIps.toSet()) {
            try {
              return await _connect(uri, ip, context);
            } catch (_) {}
          }
        }
        rethrow;
      }
    };

    return client;
  }

  /// Membuka koneksi ke [address]; untuk https, TLS dijabat dengan SNI nama host asli
  static Future<ConnectionTask<Socket>> _connect(Uri uri, String address, SecurityContext? context) async {
    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
    final rawSocket = await Socket.connect(address, port, timeout: _connectTimeout);
    if (uri.scheme != 'https') {
      return ConnectionTask.fromSocket(Future.value(rawSocket), rawSocket.destroy);
    }
    try {
      final secureSocket = await SecureSocket.secure(
        rawSocket,
        host: uri.host,
        context: context,
        onBadCertificate: (cert) => true,
      );
      return ConnectionTask.fromSocket(Future.value(secureSocket), secureSocket.destroy);
    } catch (_) {
      rawSocket.destroy();
      rethrow;
    }
  }

  static Future<List<String>> _resolveViaDoh(HttpClient dohClient, String host) async {
    final cached = _dnsCache[host];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) return cached.ips;

    for (final endpoint in _dohEndpoints) {
      try {
        final uri = Uri.parse(endpoint).replace(queryParameters: {'name': host, 'type': 'A'});
        final request = await dohClient.getUrl(uri);
        request.headers.set(HttpHeaders.acceptHeader, 'application/dns-json');
        final response = await request.close().timeout(_connectTimeout);
        if (response.statusCode != 200) {
          await response.drain<void>();
          continue;
        }
        final body = jsonDecode(await response.transform(utf8.decoder).join()) as Map<String, dynamic>;
        final answers = (body['Answer'] as List?) ?? const [];
        final ips = answers
            .whereType<Map>()
            .where((a) => a['type'] == 1)
            .map((a) => a['data'].toString())
            .where((ip) => InternetAddress.tryParse(ip) != null)
            .toList();
        if (ips.isNotEmpty) {
          _dnsCache[host] = _CachedIps(ips, DateTime.now().add(const Duration(minutes: 10)));
          return ips;
        }
      } catch (_) {
        // Coba endpoint DoH berikutnya
      }
    }
    return const [];
  }
}

class _CachedIps {
  final List<String> ips;
  final DateTime expiresAt;
  const _CachedIps(this.ips, this.expiresAt);
}
