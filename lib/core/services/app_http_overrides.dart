import 'dart:io';

/// HttpOverrides global untuk mengatasi DNS poisoning / Internet Positif
/// pada sumber komik internasional seperti MangaDex (api.mangadex.org & uploads.mangadex.org)
/// tanpa memerlukan VPN tambahan bagi pengguna.
class AppHttpOverrides extends HttpOverrides {
  static const List<String> _mangadexDirectIps = [
    '45.129.229.1',
    '45.129.229.2',
  ];

  static const List<String> _doujindesuDirectIps = [
    '172.67.72.203',
    '104.26.1.249',
    '104.26.0.249',
  ];

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (cert, host, port) => true;
    
    client.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) async {
      String targetHost = uri.host;
      
      // Deteksi domain MangaDex & DoujinDesu yang diblokir oleh ISP di Indonesia
      final isMangaDex = uri.host.endsWith('mangadex.org');
      final isDoujinDesu = uri.host.contains('desu.xxx');

      if (isMangaDex) {
        targetHost = _mangadexDirectIps.first;
      } else if (isDoujinDesu) {
        targetHost = _doujindesuDirectIps.first;
      }

      try {
        final rawSocket = await Socket.connect(targetHost, uri.port, timeout: const Duration(seconds: 15));
        if (uri.scheme == 'https') {
          final secureSocket = await SecureSocket.secure(
            rawSocket,
            host: uri.host,
            onBadCertificate: (cert) => true,
          );
          return ConnectionTask.fromSocket(Future.value(secureSocket), () {
            secureSocket.destroy();
          });
        }
        return ConnectionTask.fromSocket(Future.value(rawSocket), () {
          rawSocket.destroy();
        });
      } catch (e) {
        // Fallback ke IP sekunder jika IP primer gagal
        if (isMangaDex && _mangadexDirectIps.length > 1) {
          final rawSocket = await Socket.connect(_mangadexDirectIps[1], uri.port, timeout: const Duration(seconds: 15));
          if (uri.scheme == 'https') {
            final secureSocket = await SecureSocket.secure(
              rawSocket,
              host: uri.host,
              onBadCertificate: (cert) => true,
            );
            return ConnectionTask.fromSocket(Future.value(secureSocket), () {
              secureSocket.destroy();
            });
          }
          return ConnectionTask.fromSocket(Future.value(rawSocket), () {
            rawSocket.destroy();
          });
        } else if (isDoujinDesu && _doujindesuDirectIps.length > 1) {
          final rawSocket = await Socket.connect(_doujindesuDirectIps[1], uri.port, timeout: const Duration(seconds: 15));
          if (uri.scheme == 'https') {
            final secureSocket = await SecureSocket.secure(
              rawSocket,
              host: uri.host,
              onBadCertificate: (cert) => true,
            );
            return ConnectionTask.fromSocket(Future.value(secureSocket), () {
              secureSocket.destroy();
            });
          }
          return ConnectionTask.fromSocket(Future.value(rawSocket), () {
            rawSocket.destroy();
          });
        }
        rethrow;
      }
    };

    return client;
  }
}
