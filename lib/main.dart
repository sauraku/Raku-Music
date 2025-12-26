import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:io';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'library_screen.dart';
import 'music_service.dart';
import 'settings_service.dart';
import 'mini_player.dart';
import 'player_manager.dart';
import 'package:path/path.dart' as p;

late AudioHandler _audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  JustAudioMediaKit.ensureInitialized();
  await windowManager.ensureInitialized();

  _audioHandler = await AudioService.init(
    builder: () => PlayerManager(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.raku_music.channel.audio',
      androidNotificationChannelName: 'Music playback',
    ),
  );

  final settingsService = SettingsService();
  final savedBounds = await settingsService.loadWindowBounds();

  WindowOptions windowOptions = WindowOptions(
    size: savedBounds?.size ?? const Size(800, 800),
    center: savedBounds == null,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'Raku Music Dev',
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (savedBounds != null) {
      await windowManager.setBounds(savedBounds);
    }
    await windowManager.show();
    await windowManager.focus();
  });

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
  final SystemTray _systemTray = SystemTray();
  final AppWindow _appWindow = AppWindow();

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _initSystemTray();
    windowManager.setPreventClose(true);
  }

  Future<void> _initSystemTray() async {
    String path = Platform.isWindows ? 'assets/app.ico' : 'assets/app.png';
    
    if (Platform.isLinux) {
      final String executableDir = p.dirname(Platform.resolvedExecutable);
      final String assetsPath = p.join(executableDir, 'data', 'flutter_assets', 'assets', 'app.png');
      
      if (await File(assetsPath).exists()) {
        path = assetsPath;
      } else {
        final String projectRootAssets = p.join(Directory.current.path, 'assets', 'app.png');
        if (await File(projectRootAssets).exists()) {
          path = projectRootAssets;
        }
      }
    }

    await _systemTray.initSystemTray(
      title: "Raku Music",
      iconPath: path,
    );

    final Menu menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(label: 'Show', onClicked: (menuItem) => _appWindow.show()),
      MenuItemLabel(label: 'Hide', onClicked: (menuItem) => _appWindow.hide()),
      MenuItemLabel(label: 'Exit', onClicked: (menuItem) => _appWindow.close()),
    ]);

    await _systemTray.setContextMenu(menu);

    _systemTray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        Platform.isWindows ? _appWindow.show() : _systemTray.popUpContextMenu();
      } else if (eventName == kSystemTrayEventRightClick) {
        Platform.isWindows ? _systemTray.popUpContextMenu() : _appWindow.show();
      }
    });
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
      title: 'Raku Music Dev',
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

class _MainScreenState extends State<MainScreen> with WindowListener {
  int _selectedIndex = 0;
  final MusicService _musicService = MusicService();
  final SettingsService _settingsService = SettingsService();

  static const List<Widget> _pages = <Widget>[
    HomeScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initialScan();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    bool _isPreventClose = await windowManager.isPreventClose();
    if (_isPreventClose) {
      await windowManager.hide();
    }
  }

  @override
  void onWindowResized() async {
    final bounds = await windowManager.getBounds();
    await _settingsService.saveWindowBounds(bounds);
  }

  @override
  void onWindowMoved() async {
    final bounds = await windowManager.getBounds();
    await _settingsService.saveWindowBounds(bounds);
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
            icon: Icon(Icons.library_music),
            label: 'Library',
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
