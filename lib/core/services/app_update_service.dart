import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';

class AppUpdateInfo {
  final String latestVersion;
  final int latestBuildNumber;
  final String releaseTitle;
  final String changelog;
  final String downloadUrl;
  final String releaseDate;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.releaseTitle,
    required this.changelog,
    required this.downloadUrl,
    required this.releaseDate,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      latestVersion: json['version']?.toString().replaceAll('v', '') ?? '1.0.0',
      latestBuildNumber: int.tryParse(json['versionCode']?.toString() ?? '0') ?? 0,
      releaseTitle: json['title']?.toString() ?? 'Pembaruan KsHcans',
      changelog: json['changelog']?.toString() ?? 'Peningkatan performa dan stabilitas aplikasi.',
      downloadUrl: json['downloadUrl']?.toString() ?? '',
      releaseDate: json['releaseDate']?.toString() ?? '',
    );
  }

  factory AppUpdateInfo.fromGitHubRelease(Map<String, dynamic> json) {
    final tag = json['tag_name']?.toString().replaceAll('v', '') ?? '1.0.0';
    final name = json['name']?.toString() ?? 'KsHcans v$tag';
    final body = json['body']?.toString() ?? 'Pembaruan aplikasi resmi KsHcans.';
    final date = json['published_at']?.toString().split('T').first ?? '';

    String download = '';
    final assets = json['assets'] as List? ?? [];
    for (final asset in assets) {
      final assetName = asset['name']?.toString().toLowerCase() ?? '';
      if (assetName.endsWith('.apk')) {
        download = asset['browser_download_url']?.toString() ?? '';
        break;
      }
    }

    return AppUpdateInfo(
      latestVersion: tag,
      latestBuildNumber: 0,
      releaseTitle: name,
      changelog: body,
      downloadUrl: download,
      releaseDate: date,
    );
  }
}

class AppUpdateService {
  static const String currentVersion = '1.0.2';
  static const int currentBuildNumber = 2005;

  static const String manifestUrl =
      'https://raw.githubusercontent.com/biddfad/kshcans-andro/main/version.json';
  static const String gitHubApiUrl =
      'https://api.github.com/repos/biddfad/kshcans-andro/releases/latest';

  static const MethodChannel _installerChannel = MethodChannel('kshcans/installer');

  /// Membandingkan versi semantik (Major.Minor.Patch)
  static bool isNewerVersion(String latestVersion, int latestBuild) {
    try {
      final currentParts = currentVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final latestParts = latestVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      while (currentParts.length < 3) {
        currentParts.add(0);
      }
      while (latestParts.length < 3) {
        latestParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }

      if (latestBuild > 0 && latestBuild > currentBuildNumber) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Memeriksa pembaruan dari manifest atau GitHub Releases
  static Future<AppUpdateInfo?> checkUpdate() async {
    // 1. Coba manifest statis terlebih dahulu
    try {
      final res = await http.get(Uri.parse(manifestUrl), headers: {
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 7));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final info = AppUpdateInfo.fromJson(data);
        if (isNewerVersion(info.latestVersion, info.latestBuildNumber)) {
          return info;
        }
      }
    } catch (_) {}

    // 2. Coba endpoint GitHub Releases API jika manifest tidak tersedia
    try {
      final res = await http.get(Uri.parse(gitHubApiUrl), headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'KsHcans-App',
      }).timeout(const Duration(seconds: 7));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final info = AppUpdateInfo.fromGitHubRelease(data);
        if (isNewerVersion(info.latestVersion, info.latestBuildNumber)) {
          return info;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Pemasangan APK melalui native Android FileProvider
  static Future<bool> installApk(String filePath) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _installerChannel.invokeMethod('installApk', {'filePath': filePath});
      return result == true;
    } catch (e) {
      debugPrint('Error triggering package installer: $e');
      return false;
    }
  }

  /// Menampilkan dialog pembaruan lengkap dengan progress download
  static void showUpdateDialog(BuildContext context, AppUpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _UpdateDialogWidget(info: info),
    );
  }

  /// Pengecekan manual dari halaman Pengaturan
  static Future<void> performManualCheck(BuildContext context) async {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.hideCurrentSnackBar();
    scaffold.showSnackBar(
      const SnackBar(
        content: Text('Memeriksa ketersediaan pembaruan...'),
        duration: Duration(seconds: 2),
      ),
    );

    final info = await checkUpdate();
    if (!context.mounted) return;

    if (info != null && isNewerVersion(info.latestVersion, info.latestBuildNumber)) {
      showUpdateDialog(context, info);
    } else {
      scaffold.hideCurrentSnackBar();
      scaffold.showSnackBar(
        SnackBar(
          content: Text('KsHcans sudah versi terbaru (v$currentVersion)!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Pengecekan hening saat aplikasi pertama kali dibuka
  static Future<void> performSilentCheck(BuildContext context) async {
    try {
      await Future.delayed(const Duration(seconds: 3));
      if (!context.mounted) return;

      final info = await checkUpdate();
      if (!context.mounted || info == null) return;

      if (isNewerVersion(info.latestVersion, info.latestBuildNumber)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.cardDark,
            duration: const Duration(seconds: 8),
            content: Row(
              children: [
                const Icon(Icons.system_update_rounded, color: AppTheme.accentCyan),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pembaruan KsHcans v${info.latestVersion} tersedia!',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'PERBARUI',
              textColor: AppTheme.accentCyan,
              onPressed: () {
                showUpdateDialog(context, info);
              },
            ),
          ),
        );
      }
    } catch (_) {}
  }
}

class _UpdateDialogWidget extends StatefulWidget {
  final AppUpdateInfo info;

  const _UpdateDialogWidget({required this.info});

  @override
  State<_UpdateDialogWidget> createState() => _UpdateDialogWidgetState();
}

class _UpdateDialogWidgetState extends State<_UpdateDialogWidget> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = '';
  String? _errorMessage;
  http.Client? _client;

  Future<void> _startDownload() async {
    if (widget.info.downloadUrl.isEmpty) {
      setState(() {
        _errorMessage = 'Tautan unduhan tidak ditemukan pada rilis ini.';
      });
      return;
    }

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _statusText = 'Menghubungkan ke server...';
      _errorMessage = null;
    });

    try {
      _client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.info.downloadUrl));
      request.headers['User-Agent'] = 'KsHcans-App';

      final response = await _client!.send(request);
      if (response.statusCode != 200) {
        throw HttpException('HTTP status: ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      final tempDir = await getTemporaryDirectory();
      final saveFile = File('${tempDir.path}/KsHcans_v${widget.info.latestVersion}_update.apk');

      if (await saveFile.exists()) {
        await saveFile.delete();
      }

      final sink = saveFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        if (totalBytes > 0 && mounted) {
          setState(() {
            _progress = receivedBytes / totalBytes;
            final receivedMb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
            final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
            _statusText = 'Mengunduh: ${(_progress * 100).toInt()}% ($receivedMb / $totalMb MB)';
          });
        }
      }

      await sink.flush();
      await sink.close();

      if (!mounted) return;

      setState(() {
        _progress = 1.0;
        _statusText = 'Unduhan selesai! Membuka installer...';
      });

      final success = await AppUpdateService.installApk(saveFile.path);
      if (!success && mounted) {
        setState(() {
          _errorMessage =
              'Gagal memicu pemasangan otomatis. Berkas tersimpan di: ${saveFile.path}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal mengunduh: $e';
          _isDownloading = false;
        });
      }
    } finally {
      _client?.close();
    }
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.accentCyan, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.rocket_launch_rounded, color: AppTheme.accentCyan, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pembaruan Tersedia',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'v${AppUpdateService.currentVersion}  ➔  v${widget.info.latestVersion}',
                        style: const TextStyle(
                          color: AppTheme.accentCyan,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Catatan Perubahan (Changelog):',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: SingleChildScrollView(
                child: Text(
                  widget.info.changelog.isNotEmpty
                      ? widget.info.changelog
                      : 'Peningkatan performa dan optimasi pengalaman membaca.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isDownloading) ...[
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: AppTheme.cardDark,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentCyan),
              ),
              const SizedBox(height: 10),
              Text(
                _statusText,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
            ],
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!_isDownloading)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Nanti', style: TextStyle(color: Colors.white60)),
                  ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentCyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Icon(_isDownloading ? Icons.hourglass_top_rounded : Icons.download_rounded, size: 18),
                  label: Text(_isDownloading ? 'Mengunduh...' : 'Perbarui Sekarang'),
                  onPressed: _isDownloading ? null : _startDownload,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
