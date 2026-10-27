import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/app_http_overrides.dart';
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = AppHttpOverrides();
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAppLock();
  }

  @override
  void dispose() {
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
    final lockEnabled = await DBHelper.instance.getSetting('app_lock_enabled');
    final pin = await DBHelper.instance.getSetting('app_lock_pin');
    if (lockEnabled == 'true' && pin != null && pin.isNotEmpty && mounted) {
      setState(() {
        _isLocked = true;
        _savedPin = pin;
      });
    }
  }

  void _onDigitPressed(String digit) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
        _pinError = '';
      });
      if (_enteredPin.length == 4) {
        if (SecurityService.verifyPin(_enteredPin, _savedPin)) {
          setState(() {
            _isLocked = false;
            _enteredPin = '';
          });
        } else {
          setState(() {
            _pinError = 'PIN salah, coba lagi';
            _enteredPin = '';
          });
        }
      }
    }
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
                if (_pinError.isNotEmpty) ...[
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
