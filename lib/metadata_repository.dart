import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'app_config.dart';
import 'music_metadata.dart';

class MetadataRepository {
  static final MetadataRepository _instance = MetadataRepository._internal();
  factory MetadataRepository() => _instance;
  MetadataRepository._internal();

  static const String _metadataFileName = 'settings.json';
  List<MusicMetadata> _songs = [];
  bool _isLoaded = false;

  Future<void> init() async {
    if (_isLoaded) return;
    await _loadFromDisk();
    _isLoaded = true;
  }

  Future<void> _loadFromDisk() async {
    final file = await _getMetadataFile();
    if (!await file.exists()) {
      _songs = [];
      return;
    }

    try {
      final content = await file.readAsString();
      final Map<String, dynamic> json = jsonDecode(content);
      final List<dynamic>? songsJson = json['songs'];
      if (songsJson != null) {
        _songs = songsJson.map((s) => MusicMetadata.fromJson(s)).toList();
      } else {
        _songs = [];
      }
    } catch (e) {
      print('Error loading metadata: $e');
      _songs = [];
    }
  }

  Future<void> _saveToDisk() async {
    final file = await _getMetadataFile();
    final jsonList = _songs.map((m) => m.toJson()).toList();
    
    Map<String, dynamic> currentSettings = {};
    if (await file.exists()) {
      try {
        currentSettings = jsonDecode(await file.readAsString());
      } catch (e) { /* ignore */ }
    }
    currentSettings['songs'] = jsonList;
    await file.writeAsString(jsonEncode(currentSettings));
  }

  Future<File> _getMetadataFile() async {
    final directory = await AppConfig.getAppConfigDirectory();
    return File(p.join(directory.path, _metadataFileName));
  }

  // --- Public API ---

  List<MusicMetadata> getAllSongs() {
    return List.unmodifiable(_songs);
  }

  MusicMetadata? getSong(String filePath) {
    try {
      return _songs.firstWhere((s) => s.filePath == filePath);
    } catch (e) {
      return null;
    }
  }

  Future<void> addOrUpdateSong(MusicMetadata song) async {
    final index = _songs.indexWhere((s) => s.filePath == song.filePath);
    if (index != -1) {
      // Preserve existing user data if scanning
      final existing = _songs[index];
      song.playCount = existing.playCount;
      song.isLiked = existing.isLiked;
      song.color = existing.color;
      _songs[index] = song;
    } else {
      _songs.add(song);
    }
    await _saveToDisk();
  }

  Future<void> updateSong(MusicMetadata song) async {
    final index = _songs.indexWhere((s) => s.filePath == song.filePath);
    if (index != -1) {
      _songs[index] = song;
      await _saveToDisk();
    }
  }

  Future<void> saveAll(List<MusicMetadata> songs) async {
    _songs = songs;
    await _saveToDisk();
  }
}
