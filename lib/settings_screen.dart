import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'music_service.dart';
import 'settings_service.dart';
import 'main.dart';

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
              child: _selectedIndex == 0
                  ? const LibrarySettingsPanel()
                  : const ThemeSettingsPanel(),
            ),
          ],
        ),
      ),
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
    return Column(
      children: [
        if (_isScanning) const LinearProgressIndicator(),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              ListTile(
                title: const Text('Music Folders', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _pickFolder,
                ),
              ),
              if (_musicFolders.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No folders selected'),
                )
              else
                ..._musicFolders.asMap().entries.map((entry) {
                  final index = entry.key;
                  final folder = entry.value;
                  return ListTile(
                    title: Text(folder),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _removeFolder(index),
                    ),
                  );
                }),
              const Divider(),
              ListTile(
                title: const Text('Rescan Library'),
                leading: const Icon(Icons.refresh),
                onTap: _isScanning ? null : _scanMusic,
              ),
            ],
          ),
        ),
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

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final mode = await _settingsService.loadThemeMode();
    if (mounted) {
      setState(() {
        _currentThemeMode = mode;
      });
    }
  }

  void _updateTheme(ThemeMode? mode) {
    if (mode != null) {
      setState(() {
        _currentThemeMode = mode;
      });
      // Update the global app state
      RakuMusicApp.of(context).changeTheme(mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const ListTile(
          title: Text('App Theme', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
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
    );
  }
}
