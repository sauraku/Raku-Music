import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../../services/music_service.dart';
import '../../services/settings_service.dart';
import '../../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              expandedHeight: 120.0,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                title: Text(
                  'Settings',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ];
        },
        body: Row(
          children: [
            // Left Panel: Navigation
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.settings_applications),
                  label: Text('General'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.library_music),
                  label: Text('Library'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.brightness_6),
                  label: Text('Theme'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            // Right Panel: Content
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: const [
                  GeneralSettingsPanel(),
                  LibrarySettingsPanel(),
                  ThemeSettingsPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GeneralSettingsPanel extends StatefulWidget {
  const GeneralSettingsPanel({super.key});

  @override
  State<GeneralSettingsPanel> createState() => _GeneralSettingsPanelState();
}

class _GeneralSettingsPanelState extends State<GeneralSettingsPanel> {
  final SettingsService _settingsService = SettingsService();
  CloseBehavior _currentBehavior = CloseBehavior.exit;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final behavior = await _settingsService.loadCloseBehavior();
    if (mounted) {
      setState(() {
        _currentBehavior = behavior;
      });
    }
  }

  void _updateCloseBehavior(CloseBehavior? behavior) {
    if (behavior != null) {
      setState(() {
        _currentBehavior = behavior;
      });
      _settingsService.saveCloseBehavior(behavior);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          'On Close Button',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Column(
            children: [
              RadioListTile<CloseBehavior>(
                title: const Text('Exit application'),
                subtitle: const Text('Closes the app completely.'),
                value: CloseBehavior.exit,
                groupValue: _currentBehavior,
                onChanged: _updateCloseBehavior,
              ),
              RadioListTile<CloseBehavior>(
                title: const Text('Minimize to tray'),
                subtitle: const Text('Keeps the app running in the background.'),
                value: CloseBehavior.minimize,
                groupValue: _currentBehavior,
                onChanged: _updateCloseBehavior,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class LibrarySettingsPanel extends StatefulWidget {
  const LibrarySettingsPanel({super.key});

  @override
  State<LibrarySettingsPanel> createState() => _LibrarySettingsPanelState();
}

class _LibrarySettingsPanelState extends State<LibrarySettingsPanel> {
  List<String> _musicFolders = [];
  bool _isScanning = false;
  final MusicService _musicService = MusicService();
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _loadMusicFolders();
  }

  Future<void> _loadMusicFolders() async {
    final folders = await _settingsService.loadMusicFolders();
    if (mounted) {
      setState(() {
        _musicFolders = folders;
      });
    }
  }

  Future<void> _saveMusicFolders(List<String> folders) async {
    await _settingsService.saveMusicFolders(folders);
  }

  Future<void> _scanMusic() async {
    if (_isScanning) return;
    
    // Request permissions on Android
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Storage permission denied')),
            );
          }
          return;
        }
      }
      
      // For Android 13+ (API 33+)
      if (await Permission.audio.status.isDenied) {
        await Permission.audio.request();
      }
    }

    setState(() {
      _isScanning = true;
    });

    await _musicService.scanFolders(_musicFolders);

    if (mounted) {
      setState(() {
        _isScanning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Music scan completed')),
      );
    }
  }

  Future<void> _pickFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      if (!_musicFolders.contains(selectedDirectory)) {
        setState(() {
          _musicFolders.add(selectedDirectory);
        });
        await _saveMusicFolders(_musicFolders);
        // Trigger scan when new folder is added
        _scanMusic();
      }
    }
  }

  Future<void> _removeFolder(int index) async {
    setState(() {
      _musicFolders.removeAt(index);
    });
    await _saveMusicFolders(_musicFolders);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text(
              'Music Library',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Music Folders'),
                    trailing: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _pickFolder,
                    ),
                  ),
                  if (_musicFolders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text('No folders selected. Add a folder to scan for music.'),
                    )
                  else
                    ..._musicFolders.asMap().entries.map((entry) {
                      final index = entry.key;
                      final folder = entry.value;
                      return ListTile(
                        title: Text(folder, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _removeFolder(index),
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: ListTile(
                title: const Text('Rescan Library'),
                leading: const Icon(Icons.refresh),
                onTap: _isScanning ? null : _scanMusic,
              ),
            ),
          ],
        ),
        if (_isScanning)
          const LinearProgressIndicator(),
      ],
    );
  }
}

class ThemeSettingsPanel extends StatefulWidget {
  const ThemeSettingsPanel({super.key});

  @override
  State<ThemeSettingsPanel> createState() => _ThemeSettingsPanelState();
}

class _ThemeSettingsPanelState extends State<ThemeSettingsPanel> {
  final SettingsService _settingsService = SettingsService();
  ThemeMode _currentThemeMode = ThemeMode.system;
  Color _currentSeedColor = Colors.deepPurple;

  final List<Color> _availableColors = [
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
    const Color(0xFF1A237E), // Dark Indigo
    const Color(0xFF004D40), // Dark Teal
    const Color(0xFFB71C1C), // Dark Red
    const Color(0xFF3E2723), // Dark Brown
    const Color(0xFF212121), // Dark Grey
  ];

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final mode = await _settingsService.loadThemeMode();
    final color = await _settingsService.loadSeedColor();
    if (mounted) {
      setState(() {
        _currentThemeMode = mode;
        _currentSeedColor = color;
      });
    }
  }

  void _updateTheme(ThemeMode? mode) {
    if (mode != null) {
      setState(() {
        _currentThemeMode = mode;
      });
      RakuMusicApp.of(context).changeTheme(mode);
    }
  }

  void _updateSeedColor(Color color) {
    setState(() {
      _currentSeedColor = color;
    });
    RakuMusicApp.of(context).changeSeedColor(color);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          'App Theme',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Column(
            children: [
              RadioListTile<ThemeMode>(
                title: const Text('System Default'),
                value: ThemeMode.system,
                groupValue: _currentThemeMode,
                onChanged: _updateTheme,
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Light'),
                value: ThemeMode.light,
                groupValue: _currentThemeMode,
                onChanged: _updateTheme,
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Dark'),
                value: ThemeMode.dark,
                groupValue: _currentThemeMode,
                onChanged: _updateTheme,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Accent Color',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _availableColors.map((color) {
                return GestureDetector(
                  onTap: () => _updateSeedColor(color),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: _currentSeedColor.value == color.value
                          ? Border.all(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 3,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _currentSeedColor.value == color.value
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
