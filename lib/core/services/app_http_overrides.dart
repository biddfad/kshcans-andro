import 'dart:convert';
import 'dart:io';

/// HttpOverrides global untuk mengatasi DNS poisoning / Internet Positif
/// pada sumber komik seperti MangaDex dan DoujinDesu tanpa VPN.
///
/// Alamat IP host yang diblokir dicari lewat DNS-over-HTTPS (Cloudflare / Google),
/// lalu koneksi TLS tetap divalidasi terhadap nama host asli. Sertifikat yang
/// tidak valid SELALU ditolak, sehingga aman dari serangan man-in-the-middle.
class AppHttpOverrides extends HttpOverrides {
  /// Server DoH diakses lewat IP langsung (sertifikatnya memuat IP tersebut)
  /// agar tidak bergantung pada DNS ISP yang bisa diracuni.
  static const List<String> _dohEndpoints = [
    'https://1.1.1.1/dns-query',
    'https://8.8.8.8/resolve',
  ];

  /// Cadangan terakhir jika DoH gagal. Aman karena sertifikat tetap divalidasi.
  static const Map<String, List<String>> _fallbackIps = {
    'mangadex.org': ['45.129.229.1', '45.129.229.2'],
    'desu.xxx': ['172.67.72.203', '104.26.1.249', '104.26.0.249'],
  };

  static const Duration _connectTimeout = Duration(seconds: 15);
  static final Map<String, _CachedIps> _dnsCache = {};

  static String? _blockedDomainFor(String host) {
    if (host.endsWith('mangadex.org')) return 'mangadex.org';
    if (host.contains('desu.xxx')) return 'desu.xxx';
    return null;
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    // Klien khusus DoH tanpa connectionFactory agar tidak rekursif
    final dohClient = super.createHttpClient(null)..connectionTimeout = _connectTimeout;

    client.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) async {
      final blockedDomain = _blockedDomainFor(uri.host);
      if (blockedDomain == null) {
        return _connect(uri, uri.host, context);
      }

      final candidates = <String>[
        ...await _resolveViaDoh(dohClient, uri.host),
        ..._fallbackIps[blockedDomain]!,
      ];
      Object? lastError;
      for (final ip in candidates.toSet()) {
        try {
          return await _connect(uri, ip, context);
        } catch (e) {
          lastError = e;
        }
      }
      throw lastError ?? SocketException('Tidak dapat terhubung ke ${uri.host}');
    };

    return client;
  }

  /// Membuka koneksi ke [address]; untuk https, TLS dijabat dengan nama host asli
  /// (SNI + validasi sertifikat), tanpa pengecualian sertifikat buruk.
  static Future<ConnectionTask<Socket>> _connect(Uri uri, String address, SecurityContext? context) async {
    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
    final rawSocket = await Socket.connect(address, port, timeout: _connectTimeout);
    if (uri.scheme != 'https') {
      return ConnectionTask.fromSocket(Future.value(rawSocket), rawSocket.destroy);
    }
    try {
      final secureSocket = await SecureSocket.secure(rawSocket, host: uri.host, context: context);
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
