import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:io';
import 'ui/screens/home_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/library_screen.dart';
import 'services/music_service.dart';
import 'services/settings_service.dart';
import 'ui/components/mini_player.dart';
import 'services/player_manager.dart';
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
  final initialThemeMode = await settingsService.loadThemeMode();
  final initialSeedColor = await settingsService.loadSeedColor();

  WindowOptions windowOptions = WindowOptions(
    size: savedBounds?.size ?? const Size(800, 800),
    center: savedBounds == null,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'Raku Music Dev',
  );
  
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (savedBounds != null) {
      await windowManager.setBounds(savedBounds);
    }
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(RakuMusicApp(
    initialThemeMode: initialThemeMode,
    initialSeedColor: initialSeedColor,
  ));
}

class RakuMusicApp extends StatefulWidget {
  final ThemeMode initialThemeMode;
  final Color initialSeedColor;

  const RakuMusicApp({
    super.key,
    required this.initialThemeMode,
    required this.initialSeedColor,
  });

  @override
  State<RakuMusicApp> createState() => _RakuMusicAppState();

  static _RakuMusicAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_RakuMusicAppState>()!;
}

class _RakuMusicAppState extends State<RakuMusicApp> {
  late ThemeMode _themeMode;
  late Color _seedColor;
  final SettingsService _settingsService = SettingsService();
  final SystemTray _systemTray = SystemTray();
  final AppWindow _appWindow = AppWindow();

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
    _seedColor = widget.initialSeedColor;
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

  void changeTheme(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
    _settingsService.saveThemeMode(mode);
  }

  void changeSeedColor(Color color) {
    setState(() {
      _seedColor = color;
    });
    _settingsService.saveSeedColor(color);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Raku Music Dev',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
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
      body: Column(
        children: [
          const CustomTitleBar(),
          Expanded(
            child: _pages.elementAt(_selectedIndex),
          ),
          const MiniPlayer(),
        ],
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

class CustomTitleBar extends StatefulWidget {
  const CustomTitleBar({super.key});

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _updateMaximizedState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _updateMaximizedState() async {
    final isMaximized = await windowManager.isMaximized();
    if (mounted) {
      setState(() {
        _isMaximized = isMaximized;
      });
    }
  }

  @override
  void onWindowMaximize() {
    setState(() {
      _isMaximized = true;
    });
  }

  @override
  void onWindowUnmaximize() {
    setState(() {
      _isMaximized = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.music_note,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Raku Music',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _WindowButton(
            icon: Icons.remove,
            onPressed: () => windowManager.minimize(),
          ),
          _WindowButton(
            icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
            onPressed: () {
              if (_isMaximized) {
                windowManager.unmaximize();
              } else {
                windowManager.maximize();
              }
            },
          ),
          _WindowButton(
            icon: Icons.close,
            isClose: true,
            onPressed: () => windowManager.close(),
          ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        hoverColor: isClose ? colorScheme.error : colorScheme.onSurface.withOpacity(0.1),
        child: Container(
          width: 48,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
