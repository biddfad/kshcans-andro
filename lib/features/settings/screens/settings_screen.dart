import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/database/db_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/services/chapter_update_service.dart';
import '../../../core/services/download_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/secure_screen_service.dart';
import '../../../core/services/security_service.dart';
import '../../../providers/manga_provider.dart';
import '../../../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // State Preferensi Pengguna
  String _themeStyle = 'OLED Hitam Pekat';
  String _themeAccent = 'Cyan Neon';
  String _readingMode = 'Webtoon Vertikal';
  bool _keepScreenOn = true;
  bool _fullscreenReader = true;
  bool _autoDeleteChapters = true;
  bool _appLockEnabled = false;
  bool _incognitoRecent = false;
  bool _secureScreen = false;
  bool _notifyNewChapters = false;
  bool _isCheckingChapters = false;
  bool _nsfwEnabled = false;
  double _cacheSizeMb = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
    _calculateRealCacheSize();
  }

  Future<void> _loadSavedPreferences() async {
    try {
      final savedMode = await DBHelper.instance.getSetting('reading_mode');
      final savedNsfw = await DBHelper.instance.getSetting('nsfw_enabled');
      final savedLock = await DBHelper.instance.getSetting('app_lock_enabled');
      final savedIncog = await DBHelper.instance.getSetting('incognito_recent');
      final savedSecure = await DBHelper.instance.getSetting('secure_screen');
      final savedNotify = await DBHelper.instance.getSetting(ChapterUpdateService.settingKey);
      if (mounted) {
        setState(() {
          if (savedMode != null && savedMode.isNotEmpty) _readingMode = savedMode;
          _nsfwEnabled = savedNsfw == 'true';
          _appLockEnabled = savedLock == 'true';
          _incognitoRecent = savedIncog == 'true';
          _secureScreen = savedSecure == 'true';
          _notifyNewChapters = savedNotify == 'true';
        });
      }
    } catch (_) {}
  }

  Future<void> _calculateRealCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      int totalBytes = 0;
      if (await tempDir.exists()) {
        final list = tempDir.listSync(recursive: true);
        for (final item in list) {
          if (item is File) {
            totalBytes += await item.length();
          }
        }
      }
      if (mounted) {
        setState(() {
          _cacheSizeMb = totalBytes / (1024 * 1024);
        });
      }
    } catch (_) {}
  }

  Future<void> _clearRealDiskCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final list = tempDir.listSync(recursive: true);
        for (final item in list) {
          try {
            if (item is File) {
              await item.delete();
            }
          } catch (_) {}
        }
      }
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (mounted) {
        setState(() {
          _cacheSizeMb = 0.0;
        });
      }
    } catch (_) {}
  }

  void _showThemeDialog() {
    final themeProv = context.read<ThemeProvider>();
    _themeStyle = themeProv.styleName;
    _themeAccent = themeProv.accentName;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tema & Aksen Warna',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text('Gaya Gelap:', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _themeStyle == 'OLED Hitam Pekat' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: _themeStyle == 'OLED Hitam Pekat' ? AppTheme.accentCyan : AppTheme.textMuted,
                    ),
                    title: const Text('OLED Hitam Pekat (Hemat Baterai)', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      setModalState(() => _themeStyle = 'OLED Hitam Pekat');
                      setState(() => _themeStyle = 'OLED Hitam Pekat');
                      context.read<ThemeProvider>().setStyle('OLED Hitam Pekat');
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _themeStyle == 'Dark Charcoal' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: _themeStyle == 'Dark Charcoal' ? AppTheme.accentCyan : AppTheme.textMuted,
                    ),
                    title: const Text('Dark Charcoal (Abu-abu Gelap)', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      setModalState(() => _themeStyle = 'Dark Charcoal');
                      setState(() => _themeStyle = 'Dark Charcoal');
                      context.read<ThemeProvider>().setStyle('Dark Charcoal');
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Aksen Warna Neon:', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildColorChip('Cyan Neon', AppTheme.accentCyan, setModalState),
                      _buildColorChip('Pink KsH Katana', const Color(0xFFFF2A85), setModalState),
                      _buildColorChip('Ungu Cyber', const Color(0xFF9D4EDD), setModalState),
                      _buildColorChip('Hijau Emerald', const Color(0xFF06D6A0), setModalState),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentCyan,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Tema diterapkan: $_themeStyle ($_themeAccent)'),
                            backgroundColor: AppTheme.cardDark,
                          ),
                        );
                      },
                      child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildColorChip(String name, Color color, StateSetter setModalState) {
    final isSelected = _themeAccent == name;
    return ChoiceChip(
      avatar: CircleAvatar(backgroundColor: color, radius: 7),
      label: Text(name),
      selected: isSelected,
      selectedColor: color.withValues(alpha: 0.3),
      onSelected: (selected) {
        if (selected) {
          setModalState(() => _themeAccent = name);
          setState(() => _themeAccent = name);
          context.read<ThemeProvider>().setAccent(name, color);
        }
      },
    );
  }

  void _showReaderPreferencesDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Preferensi Pembaca (Reader)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    const Text('Mode Baca Default:', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _readingMode == 'Webtoon Vertikal' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: _readingMode == 'Webtoon Vertikal' ? AppTheme.accentCyan : AppTheme.textMuted,
                      ),
                      title: const Text('Webtoon Vertikal (Manhwa & Scroll)', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        setModalState(() => _readingMode = 'Webtoon Vertikal');
                        setState(() => _readingMode = 'Webtoon Vertikal');
                        DBHelper.instance.saveSetting('reading_mode', 'Webtoon Vertikal');
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _readingMode == 'Manga Kanan-ke-Kiri' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: _readingMode == 'Manga Kanan-ke-Kiri' ? AppTheme.accentCyan : AppTheme.textMuted,
                      ),
                      title: const Text('Manga Kanan-ke-Kiri (Gaya Jepang)', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        setModalState(() => _readingMode = 'Manga Kanan-ke-Kiri');
                        setState(() => _readingMode = 'Manga Kanan-ke-Kiri');
                        DBHelper.instance.saveSetting('reading_mode', 'Manga Kanan-ke-Kiri');
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _readingMode == 'Buku Kiri-ke-Kanan' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: _readingMode == 'Buku Kiri-ke-Kanan' ? AppTheme.accentCyan : AppTheme.textMuted,
                      ),
                      title: const Text('Buku Kiri-ke-Kanan (Standar Komik)', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        setModalState(() => _readingMode = 'Buku Kiri-ke-Kanan');
                        setState(() => _readingMode = 'Buku Kiri-ke-Kanan');
                        DBHelper.instance.saveSetting('reading_mode', 'Buku Kiri-ke-Kanan');
                      },
                    ),
                    const Divider(color: AppTheme.cardDark),
                    SwitchListTile(
                      activeTrackColor: AppTheme.accentCyan,
                      title: const Text('Layar Tetap Menyala (Keep Screen On)', style: TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: const Text('Mencegah layar HP mati otomatis saat membaca', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      value: _keepScreenOn,
                      onChanged: (val) {
                        setModalState(() => _keepScreenOn = val);
                        setState(() => _keepScreenOn = val);
                      },
                    ),
                    SwitchListTile(
                      activeTrackColor: AppTheme.accentCyan,
                      title: const Text('Mode Layar Penuh (Fullscreen)', style: TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: const Text('Sembunyikan bilah status baterai & jam', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      value: _fullscreenReader,
                      onChanged: (val) {
                        setModalState(() => _fullscreenReader = val);
                        setState(() => _fullscreenReader = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentCyan,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Preferensi pembaca berhasil disimpan!')),
                          );
                        },
                        child: const Text('Terapkan Pengaturan', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showStorageDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.storage, color: AppTheme.accentCyan),
                  SizedBox(width: 10),
                  Text('Unduhan & Cache', style: TextStyle(fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Penyimpanan Cache Gambar:\n${_cacheSizeMb.toStringAsFixed(1)} MB',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cache digunakan untuk mempercepat pemuatan sampul komik dan lembaran bab yang sering Anda baca.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeTrackColor: AppTheme.accentCyan,
                    title: const Text('Hapus Bab Selesai', style: TextStyle(fontSize: 13, color: Colors.white)),
                    subtitle: const Text('Hapus otomatis unduhan setelah tamat dibaca', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    value: _autoDeleteChapters,
                    onChanged: (val) {
                      setDialogState(() => _autoDeleteChapters = val);
                      setState(() => _autoDeleteChapters = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tutup', style: TextStyle(color: AppTheme.textMuted)),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_forever, size: 16, color: Colors.orangeAccent),
                  label: const Text('Hapus Unduhan', style: TextStyle(color: Colors.orangeAccent, fontSize: 13)),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    await DownloadService.deleteAllDownloads();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Seluruh file unduhan bab offline berhasil dibersihkan!'),
                      ),
                    );
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    await _clearRealDiskCache();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Cache disk & memori gambar berhasil dibersihkan! Penyimpanan HP lebih lega.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  label: const Text('Bersihkan Cache'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSecurityDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.security, color: AppTheme.accentCyan),
                  SizedBox(width: 10),
                  Text('Keamanan & Privasi', style: TextStyle(fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeTrackColor: AppTheme.accentCyan,
                    title: const Text('Kunci Aplikasi saat Dibuka', style: TextStyle(fontSize: 13, color: Colors.white)),
                    subtitle: const Text('Gunakan PIN 4 Digit saat membuka KsHcans', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    value: _appLockEnabled,
                    onChanged: (val) {
                      if (val) {
                        _promptSetPin(context, setDialogState);
                      } else {
                        DBHelper.instance.saveSetting('app_lock_enabled', 'false');
                        DBHelper.instance.saveSetting('app_lock_pin', '');
                        setDialogState(() => _appLockEnabled = false);
                        setState(() => _appLockEnabled = false);
                      }
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeTrackColor: AppTheme.accentCyan,
                    title: const Text('Samarkan di Recent Apps', style: TextStyle(fontSize: 13, color: Colors.white)),
                    subtitle: const Text('Sembunyikan layar di menu multitasking & blokir screenshot (Anti-Intip)', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    value: _secureScreen,
                    onChanged: (val) {
                      DBHelper.instance.saveSetting('secure_screen', val ? 'true' : 'false');
                      SecureScreenService.setEnabled(val);
                      setDialogState(() => _secureScreen = val);
                      setState(() => _secureScreen = val);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeTrackColor: AppTheme.accentCyan,
                    title: const Text('Mode Penyamaran', style: TextStyle(fontSize: 13, color: Colors.white)),
                    subtitle: const Text('Jangan simpan riwayat bacaan', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    value: _incognitoRecent,
                    onChanged: (val) {
                      DBHelper.instance.saveSetting('incognito_recent', val ? 'true' : 'false');
                      setDialogState(() => _incognitoRecent = val);
                      setState(() => _incognitoRecent = val);
                    },
                  ),
                  const Divider(color: AppTheme.cardDark),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeTrackColor: Colors.redAccent,
                    title: const Text('Sumber Dewasa (18+ / NSFW)', style: TextStyle(fontSize: 13, color: Colors.white)),
                    subtitle: const Text('Menampilkan sumber seperti DoujinDesu di tab Jelajahi & Pencarian', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    value: _nsfwEnabled,
                    onChanged: (val) {
                      if (val) {
                        showDialog(
                          context: context,
                          builder: (c) => AlertDialog(
                            backgroundColor: AppTheme.surfaceDark,
                            title: const Text('Konfirmasi Usia 18+', style: TextStyle(color: Colors.white)),
                            content: const Text(
                              'Sumber ini memuat konten grafis khusus dewasa (18+). Apakah Anda berusia 18 tahun ke atas dan menyetujui pembukaan akses konten ini?',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c),
                                child: const Text('Batal', style: TextStyle(color: AppTheme.textMuted)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                onPressed: () {
                                  Navigator.pop(c);
                                  setDialogState(() => _nsfwEnabled = true);
                                  setState(() => _nsfwEnabled = true);
                                  DBHelper.instance.saveSetting('nsfw_enabled', 'true');
                                },
                                child: const Text('Saya Berusia 18+'),
                              ),
                            ],
                          ),
                        );
                      } else {
                        setDialogState(() => _nsfwEnabled = false);
                        setState(() => _nsfwEnabled = false);
                        DBHelper.instance.saveSetting('nsfw_enabled', 'false');
                      }
                    },
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan, foregroundColor: Colors.black),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pengaturan keamanan disimpan')),
                    );
                  },
                  child: const Text('Tutup'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _promptSetPin(BuildContext context, StateSetter setDialogState) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Buat 4 Digit PIN Kunci', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Masukkan 4 angka PIN rahasia untuk melindungi aplikasi KsHcans:',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 4,
              obscureText: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, letterSpacing: 14, color: AppTheme.accentCyan, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: '••••',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCyan,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final pin = pinController.text.trim();
              if (!SecurityService.isValidPinFormat(pin)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN harus terdiri dari 4 angka')),
                );
                return;
              }
              final hashedPin = await SecurityService.hashPin(pin);
              await DBHelper.instance.saveSetting('pin_failed_attempts', '0');
              await DBHelper.instance.saveSetting('pin_lockout_until', '');
              await DBHelper.instance.saveSetting('app_lock_enabled', 'true');
              await DBHelper.instance.saveSetting('app_lock_pin', hashedPin);
              setDialogState(() => _appLockEnabled = true);
              setState(() => _appLockEnabled = true);
              if (context.mounted) {
                Navigator.pop(c);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kunci PIN aplikasi berhasil diaktifkan!')),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showBackupDialog() {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.backup, color: AppTheme.accentCyan),
              SizedBox(width: 10),
              Text('Cadangan & Pemulihan', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cadangan berisi pustaka, riwayat bacaan, dan daftar bab yang sudah dibaca. '
                'Simpan file-nya di tempat aman (mis. Google Drive) sebelum uninstall atau ganti HP.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.save_alt, color: AppTheme.accentCyan),
                title: const Text('Simpan Cadangan ke File', style: TextStyle(fontSize: 14)),
                subtitle: const Text('Pilih folder di HP untuk menyimpan file .json', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                onTap: () async {
                  final jsonBackup = await context.read<MangaProvider>().exportLibraryJson();
                  try {
                    final saved = await FilePicker.saveFile(
                      dialogTitle: 'Simpan cadangan KsHcans',
                      fileName: _backupFileName(),
                      bytes: Uint8List.fromList(utf8.encode(jsonBackup)),
                      mimeType: 'application/json',
                    );
                    if (saved == null) return; // Dibatalkan pengguna
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('File cadangan berhasil disimpan!'), backgroundColor: Colors.green),
                    );
                  } catch (_) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Gagal menyimpan file cadangan.'), backgroundColor: Colors.redAccent),
                    );
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.share, color: AppTheme.accentCyan),
                title: const Text('Bagikan File Cadangan', style: TextStyle(fontSize: 14)),
                subtitle: const Text('Kirim ke Google Drive, WhatsApp, Telegram, dll.', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                onTap: () async {
                  final jsonBackup = await context.read<MangaProvider>().exportLibraryJson();
                  final file = File(p.join((await getTemporaryDirectory()).path, _backupFileName()));
                  await file.writeAsString(jsonBackup);
                  await SharePlus.instance.share(
                    ShareParams(files: [XFile(file.path, mimeType: 'application/json')], subject: 'Cadangan KsHcans'),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              const Divider(color: AppTheme.cardDark),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restore, color: AppTheme.accentCyan),
                title: const Text('Pulihkan dari File', style: TextStyle(fontSize: 14)),
                subtitle: const Text('Pilih file cadangan .json', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                onTap: () async {
                  final provider = context.read<MangaProvider>();
                  final picked = await FilePicker.pickFiles(
                    dialogTitle: 'Pilih file cadangan KsHcans',
                    type: FileType.custom,
                    allowedExtensions: ['json'],
                  );
                  if (picked.isEmpty) return; // Dibatalkan pengguna
                  final String content;
                  try {
                    content = await picked.first.xFile.readAsString();
                  } catch (_) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('File tidak dapat dibaca.'), backgroundColor: Colors.redAccent),
                    );
                    return;
                  }
                  final result = await provider.importLibraryJson(content);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showImportResult(messenger, result);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.paste, color: AppTheme.textMuted),
                title: const Text('Pulihkan dari Teks JSON', style: TextStyle(fontSize: 14)),
                subtitle: const Text('Untuk cadangan lama yang disalin ke Clipboard', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRestoreDialog();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup', style: TextStyle(color: AppTheme.textMuted)),
            ),
          ],
        );
      },
    );
  }

  String _backupFileName() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'KsHcans_cadangan_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}.json';
  }

  void _showImportResult(ScaffoldMessengerState messenger, BackupImportResult result) {
    if (result.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Format cadangan tidak valid atau tidak berisi data.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Berhasil dipulihkan: ${result.library} komik, ${result.history} riwayat, '
          '${result.readChapters} bab terbaca.',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showRestoreDialog() {
    final textController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<MangaProvider>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.file_download, color: AppTheme.accentCyan),
              SizedBox(width: 10),
              Text('Pulihkan Pustaka', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tempelkan teks JSON cadangan pustaka di bawah ini untuk mengembalikan seluruh komik favorit:',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 5,
                style: const TextStyle(fontSize: 12, color: Colors.white, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: '{\n  "app": "KsHcans",\n  "library": [...]\n}',
                  hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: AppTheme.cardDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final clipData = await Clipboard.getData(Clipboard.kTextPlain);
                    if (clipData?.text != null && clipData!.text!.isNotEmpty) {
                      textController.text = clipData.text!;
                    }
                  },
                  icon: const Icon(Icons.paste, size: 16, color: AppTheme.accentCyan),
                  label: const Text('Tempel dari Clipboard', style: TextStyle(fontSize: 12, color: AppTheme.accentCyan)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCyan,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final content = textController.text.trim();
                if (content.isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Teks cadangan JSON tidak boleh kosong!')),
                  );
                  return;
                }

                final result = await provider.importLibraryJson(content);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _showImportResult(messenger, result);
              },
              child: const Text('Pulihkan Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/icons/app_icon.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.oledBlack,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.5), width: 1.5),
                    ),
                    child: const Center(
                      child: Text(
                        'KsH',
                        style: TextStyle(
                          color: AppTheme.accentCyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('KsHcans', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('v${AppUpdateService.currentVersion} (Release Build)', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aplikasi pembaca komik, manga, manhwa & manhua modern tanpa iklan dengan mesin Flutter AOT hemat memori (~18 MB).',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
              ),
              const SizedBox(height: 14),
              const Text('Sumber Komik Terpasang:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.accentCyan)),
              const SizedBox(height: 6),
              const Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: Colors.greenAccent),
                  SizedBox(width: 6),
                  Text('Shinigami API (Manhwa Populer HD)', style: TextStyle(fontSize: 12, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 4),
              const Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: Colors.greenAccent),
                  SizedBox(width: 6),
                  Text('BacaKomik (Koleksi Manga ID)', style: TextStyle(fontSize: 12, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 4),
              const Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: Colors.greenAccent),
                  SizedBox(width: 6),
                  Text('MangaDex (Katalog Global Resmi)', style: TextStyle(fontSize: 12, color: Colors.white)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                AppUpdateService.performManualCheck(context);
              },
              child: const Text('Cek Pembaruan', style: TextStyle(color: AppTheme.accentCyan)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCyan,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan & Lainnya'),
      ),
      body: ListView(
        children: [
          _buildHeader('BACAAN & TAMPILAN'),
          _buildSettingTile(
            icon: Icons.palette_outlined,
            title: 'Tema & Tampilan',
            subtitle: '$_themeStyle ($_themeAccent)',
            onTap: _showThemeDialog,
          ),
          _buildSettingTile(
            icon: Icons.auto_stories_outlined,
            title: 'Preferensi Pembaca (Reader)',
            subtitle: 'Mode: $_readingMode',
            onTap: _showReaderPreferencesDialog,
          ),
          _buildSettingTile(
            icon: Icons.download_outlined,
            title: 'Unduhan & Penyimpanan',
            subtitle: 'Penyimpanan internal, cache: ${_cacheSizeMb.toStringAsFixed(1)} MB',
            onTap: _showStorageDialog,
          ),

          _buildHeader('NOTIFIKASI'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined, color: Colors.white70),
            activeTrackColor: AppTheme.accentCyan,
            title: const Text('Notifikasi Bab Baru', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: Text(
              ChapterUpdateService.isSupported
                  ? 'Cek komik di Pustaka setiap ±6 jam, walau aplikasi ditutup'
                  : 'Belum didukung di perangkat ini',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            value: _notifyNewChapters,
            onChanged: ChapterUpdateService.isSupported && !_isCheckingChapters ? _toggleNewChapterNotifications : null,
          ),
          if (_notifyNewChapters)
            ListTile(
              leading: _isCheckingChapters
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentCyan),
                    )
                  : const Icon(Icons.refresh, color: Colors.white70),
              title: const Text('Cek Bab Baru Sekarang', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: const Text('Periksa semua komik di Pustaka saat ini juga', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              onTap: _isCheckingChapters ? null : _checkNewChaptersNow,
            ),

          _buildHeader('KEAMANAN & PRIVASI'),
          _buildSettingTile(
            icon: Icons.security_outlined,
            title: 'Keamanan & Kunci PIN',
            subtitle: _appLockEnabled ? 'Kunci aplikasi: Aktif' : 'Kunci aplikasi: Nonaktif',
            onTap: _showSecurityDialog,
          ),

          _buildHeader('DATA & APLIKASI'),
          _buildSettingTile(
            icon: Icons.backup_outlined,
            title: 'Cadangan & Pemulihan',
            subtitle: 'Ekspor atau impor data pustaka (format JSON)',
            onTap: _showBackupDialog,
          ),
          _buildSettingTile(
            icon: Icons.info_outline,
            title: 'Tentang Aplikasi',
            subtitle: 'KsHcans v1.0.0 (Release Build)',
            onTap: _showAboutDialog,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _toggleNewChapterNotifications(bool enable) async {
    final messenger = ScaffoldMessenger.of(context);
    if (enable && !await NotificationService.requestPermission()) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Izin notifikasi ditolak. Aktifkan lewat Pengaturan HP > Aplikasi > KsHcans.')),
      );
      return;
    }
    setState(() => _isCheckingChapters = enable);
    try {
      // Saat diaktifkan, bab yang ada sekarang dicatat dulu (bisa beberapa detik)
      await ChapterUpdateService.setEnabled(enable);
      if (!mounted) return;
      setState(() => _notifyNewChapters = enable);
      messenger.showSnackBar(SnackBar(
        content: Text(enable
            ? 'Notifikasi bab baru aktif. Kamu akan diberi tahu saat ada bab baru.'
            : 'Notifikasi bab baru dimatikan'),
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Gagal mengubah pengaturan notifikasi')));
    } finally {
      if (mounted) setState(() => _isCheckingChapters = false);
    }
  }

  Future<void> _checkNewChaptersNow() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isCheckingChapters = true);
    try {
      final results = await ChapterUpdateService.checkLibrary();
      await NotificationService.showNewChapters(results);
      messenger.showSnackBar(SnackBar(
        content: Text(results.isEmpty
            ? 'Belum ada bab baru untuk komik di Pustaka'
            : '${results.length} komik punya bab baru!'),
      ));
    } finally {
      if (mounted) setState(() => _isCheckingChapters = false);
    }
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.accentCyan,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
      onTap: onTap,
    );
  }
}
