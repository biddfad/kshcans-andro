import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/app_http_overrides.dart';
import 'core/services/app_update_service.dart';
import 'core/services/chapter_update_service.dart';
import 'core/services/source_config_service.dart';
import 'core/services/secure_screen_service.dart';
import 'core/services/security_service.dart';
import 'core/database/db_helper.dart';
import 'core/theme/app_theme.dart';
import 'providers/manga_provider.dart';
import 'providers/theme_provider.dart';
import 'features/library/screens/library_screen.dart';
import 'features/updates/screens/updates_screen.dart';
import 'features/history/screens/history_screen.dart';
import 'features/browse/screens/browse_screen.dart';
import 'features/settings/screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = AppHttpOverrides();
  try {
    await SourceConfigService.initialize();
    await ChapterUpdateService.initialize();
  } catch (e) {
    debugPrint('Gagal menyiapkan layanan: $e');
  }
  runApp(const KomikReaderApp());
}

class KomikReaderApp extends StatelessWidget {
  const KomikReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => MangaProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'KsHcans',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.themeData,
            home: const MainNavigationScreen(),
          );
        },
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isLocked = false;
  String _savedPin = '';
  String _enteredPin = '';
  String _pinError = '';
  bool _isVerifying = false;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAppLock();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SourceConfigService.syncRemoteConfig();
      AppUpdateService.performSilentCheck(context);
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Saat aplikasi diminimalkan ke background atau layar dimatikan,
    // kunci ulang aplikasi secara otomatis demi keamanan & privasi
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_savedPin.isNotEmpty && mounted) {
        setState(() {
          _isLocked = true;
          _enteredPin = '';
          _pinError = '';
        });
      }
    }
  }

  Future<void> _checkAppLock() async {
    final secureScreen = await DBHelper.instance.getSetting('secure_screen');
    await SecureScreenService.setEnabled(secureScreen == 'true');

    final lockEnabled = await DBHelper.instance.getSetting('app_lock_enabled');
    var pin = await DBHelper.instance.getSetting('app_lock_pin');
    if (pin != null && SecurityService.isPlaintextPin(pin)) {
      // Migrasi PIN teks biasa dari versi lama agar tidak lagi tersimpan terbuka
      pin = await SecurityService.hashPin(pin);
      await DBHelper.instance.saveSetting('app_lock_pin', pin);
    }
    _failedAttempts = int.tryParse(await DBHelper.instance.getSetting('pin_failed_attempts') ?? '') ?? 0;
    final until = int.tryParse(await DBHelper.instance.getSetting('pin_lockout_until') ?? '');
    _lockoutUntil = until == null ? null : DateTime.fromMillisecondsSinceEpoch(until);

    if (lockEnabled == 'true' && pin != null && pin.isNotEmpty && mounted) {
      setState(() {
        _isLocked = true;
        _savedPin = pin!;
      });
      _startLockoutTicker();
    }
  }

  bool get _isLockedOut => _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);

  void _startLockoutTicker() {
    _lockoutTimer?.cancel();
    if (!_isLockedOut) return;
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() {});
      if (!_isLockedOut) timer.cancel();
    });
  }

  Future<void> _onDigitPressed(String digit) async {
    if (_isVerifying || _isLockedOut || _enteredPin.length >= 4) return;
    setState(() {
      _enteredPin += digit;
      _pinError = '';
    });
    if (_enteredPin.length < 4) return;

    setState(() => _isVerifying = true);
    final ok = await SecurityService.verifyPin(_enteredPin, _savedPin);
    if (!mounted) return;

    if (ok) {
      if (SecurityService.isLegacyHash(_savedPin)) {
        // Migrasi hash SHA-256 lama ke PBKDF2 dengan salt acak
        _savedPin = await SecurityService.hashPin(_enteredPin);
        await DBHelper.instance.saveSetting('app_lock_pin', _savedPin);
      }
      _failedAttempts = 0;
      _lockoutUntil = null;
      await DBHelper.instance.saveSetting('pin_failed_attempts', '0');
      await DBHelper.instance.saveSetting('pin_lockout_until', '');
      if (!mounted) return;
      setState(() {
        _isLocked = false;
        _isVerifying = false;
        _enteredPin = '';
      });
      return;
    }

    _failedAttempts++;
    final lockout = SecurityService.lockoutFor(_failedAttempts);
    final lockedNow = lockout > Duration.zero && _failedAttempts % SecurityService.maxAttemptsBeforeLockout == 0;
    if (lockedNow) {
      _lockoutUntil = DateTime.now().add(lockout);
      await DBHelper.instance.saveSetting('pin_lockout_until', '${_lockoutUntil!.millisecondsSinceEpoch}');
    }
    await DBHelper.instance.saveSetting('pin_failed_attempts', '$_failedAttempts');
    if (!mounted) return;
    final remaining = SecurityService.maxAttemptsBeforeLockout -
        _failedAttempts % SecurityService.maxAttemptsBeforeLockout;
    setState(() {
      _isVerifying = false;
      _enteredPin = '';
      _pinError = lockedNow ? '' : 'PIN salah, sisa $remaining percobaan';
    });
    _startLockoutTicker();
  }

  void _onDeletePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _pinError = '';
      });
    }
  }

  Widget _buildLockScreen() {
    return Scaffold(
      backgroundColor: AppTheme.oledBlack,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/icons/app_icon.png',
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.lock, size: 64, color: AppTheme.accentCyan),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'KsHcans Terkunci',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Masukkan 4 digit PIN Anda untuk membuka',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 24),
                // PIN dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final filled = index < _enteredPin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled ? AppTheme.accentCyan : Colors.transparent,
                        border: Border.all(
                          color: filled ? AppTheme.accentCyan : Colors.white38,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
                if (_isLockedOut) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Terlalu banyak salah. Coba lagi dalam '
                    '${_lockoutUntil!.difference(DateTime.now()).inSeconds + 1} detik',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ] else if (_pinError.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _pinError,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ] else
                  const SizedBox(height: 28),

                // Numpad
                Container(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Column(
                    children: [
                      for (var row = 0; row < 3; row++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              for (var col = 1; col <= 3; col++)
                                _buildNumButton('${row * 3 + col}'),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            const SizedBox(width: 64, height: 64),
                            _buildNumButton('0'),
                            InkWell(
                              borderRadius: BorderRadius.circular(32),
                              onTap: _onDeletePressed,
                              child: Container(
                                width: 64,
                                height: 64,
                                alignment: Alignment.center,
                                child: const Icon(Icons.backspace_outlined, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumButton(String digit) {
    return InkWell(
      borderRadius: BorderRadius.circular(32),
      onTap: () => _onDigitPressed(digit),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.cardDark,
          border: Border.all(color: Colors.white12),
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return _buildLockScreen();
    }
    final screens = [
      const UpdatesScreen(),
      LibraryScreen(onExploreTap: () {
        setState(() {
          _currentIndex = 3;
        });
      }),
      const HistoryScreen(),
      const BrowseScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.whatshot_outlined),
            selectedIcon: Icon(Icons.whatshot),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark_outlined),
            selectedIcon: Icon(Icons.collections_bookmark),
            label: 'Pustaka',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Jelajahi',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_outlined),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'Lainnya',
          ),
        ],
      ),
    );
  }
}
