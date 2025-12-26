import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'music_service.dart';
import 'settings_service.dart';
import 'mini_player.dart';

void main() {
  JustAudioMediaKit.ensureInitialized();
  runApp(const RakuMusicApp());
}

class RakuMusicApp extends StatefulWidget {
  const RakuMusicApp({super.key});

  @override
  State<RakuMusicApp> createState() => _RakuMusicAppState();

  static _RakuMusicAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_RakuMusicAppState>()!;
}

class _RakuMusicAppState extends State<RakuMusicApp> {
  ThemeMode _themeMode = ThemeMode.system;
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final mode = await _settingsService.loadThemeMode();
    setState(() {
      _themeMode = mode;
    });
  }

  void changeTheme(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
    _settingsService.saveThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Raku Music',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final MusicService _musicService = MusicService();
  final SettingsService _settingsService = SettingsService();

  static const List<Widget> _pages = <Widget>[
    HomeScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initialScan();
  }

  Future<void> _initialScan() async {
    final folders = await _settingsService.loadMusicFolders();
    if (folders.isNotEmpty) {
      await _musicService.scanFolders(folders);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _pages.elementAt(_selectedIndex),
            ),
            const MiniPlayer(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
