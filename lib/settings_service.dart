import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'app_config.dart';

abstract class ISettingsService {
  Future<List<String>> loadMusicFolders();
  Future<void> saveMusicFolders(List<String> folders);
  Future<ThemeMode> loadThemeMode();
  Future<void> saveThemeMode(ThemeMode mode);
  Future<Rect?> loadWindowBounds();
  Future<void> saveWindowBounds(Rect bounds);
}

class SettingsService implements ISettingsService {
  static const String _settingsFileName = 'settings.json';

  Future<File> _getSettingsFile() async {
    final directory = await AppConfig.getAppConfigDirectory();
    return File(p.join(directory.path, _settingsFileName));
  }

  Future<Map<String, dynamic>> _loadSettings() async {
    final file = await _getSettingsFile();
    if (!await file.exists()) {
      return {};
    }
    try {
      final content = await file.readAsString();
      return jsonDecode(content);
    } catch (e) {
      print('Error loading settings: $e');
      return {};
    }
  }

  Future<void> _saveSettings(Map<String, dynamic> settings) async {
    final file = await _getSettingsFile();
    await file.writeAsString(jsonEncode(settings));
  }

  @override
  Future<List<String>> loadMusicFolders() async {
    final settings = await _loadSettings();
    final List<dynamic>? folders = settings['music_folders'];
    if (folders != null) {
      return folders.cast<String>().toList();
    }
    return [];
  }

  @override
  Future<void> saveMusicFolders(List<String> folders) async {
    final settings = await _loadSettings();
    settings['music_folders'] = folders;
    await _saveSettings(settings);
  }

  @override
  Future<ThemeMode> loadThemeMode() async {
    final settings = await _loadSettings();
    final String? themeName = settings['theme_mode'];
    if (themeName == 'light') {
      return ThemeMode.light;
    } else if (themeName == 'dark') {
      return ThemeMode.dark;
    } else {
      return ThemeMode.system;
    }
  }

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    final settings = await _loadSettings();
    String themeName;
    switch (mode) {
      case ThemeMode.light:
        themeName = 'light';
        break;
      case ThemeMode.dark:
        themeName = 'dark';
        break;
      case ThemeMode.system:
      default:
        themeName = 'system';
        break;
    }
    settings['theme_mode'] = themeName;
    await _saveSettings(settings);
  }

  @override
  Future<Rect?> loadWindowBounds() async {
    final settings = await _loadSettings();
    if (settings['window_bounds'] != null) {
      final bounds = settings['window_bounds'];
      return Rect.fromLTWH(
        bounds['left'],
        bounds['top'],
        bounds['width'],
        bounds['height'],
      );
    }
    return null;
  }

  @override
  Future<void> saveWindowBounds(Rect bounds) async {
    final settings = await _loadSettings();
    settings['window_bounds'] = {
      'left': bounds.left,
      'top': bounds.top,
      'width': bounds.width,
      'height': bounds.height,
    };
    await _saveSettings(settings);
  }
}
