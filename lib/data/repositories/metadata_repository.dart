import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../app/app_config.dart';
import '../models/music_metadata.dart';

class MetadataRepository {
  static final MetadataRepository _instance = MetadataRepository._internal();
  factory MetadataRepository() => _instance;
  MetadataRepository._internal();

  static const String _metadataFileName = 'settings.json';
  // Use a Map for O(1) access by filePath
  Map<String, MusicMetadata> _songsMap = {};
  bool _isLoaded = false;

  Future<void> init() async {
    if (_isLoaded) return;
    await _loadFromDisk();
    _isLoaded = true;
  }

  Future<void> _loadFromDisk() async {
    final file = await _getMetadataFile();
    if (!await file.exists()) {
      _songsMap = {};
      return;
    }

    try {
      final content = await file.readAsString();
      final Map<String, dynamic> json = jsonDecode(content);
      final dynamic songsData = json['songs'];
      
      if (songsData is Map) {
        _songsMap = {};
        songsData.forEach((key, value) {
          if (value is Map<String, dynamic>) {
             _songsMap[key.toString()] = MusicMetadata.fromJson(value);
          }
        });
      } else {
        _songsMap = {};
      }
    } catch (e) {
      print('Error loading metadata: $e');
      _songsMap = {};
    }
  }

  Future<void> _saveToDisk() async {
    final file = await _getMetadataFile();
    // Save as a Map for O(1) lookup structure in JSON
    final songsJsonMap = _songsMap.map((key, value) => MapEntry(key, value.toJson()));
    
    Map<String, dynamic> currentSettings = {};
    if (await file.exists()) {
      try {
        currentSettings = jsonDecode(await file.readAsString());
      } catch (e) { /* ignore */ }
    }
    currentSettings['songs'] = songsJsonMap;
    await file.writeAsString(jsonEncode(currentSettings));
  }

  Future<File> _getMetadataFile() async {
    final directory = await AppConfig.getAppConfigDirectory();
    return File(p.join(directory.path, _metadataFileName));
  }

  // --- Public API ---

  List<MusicMetadata> getAllSongs() {
    return _songsMap.values.toList();
  }

  MusicMetadata? getSong(String filePath) {
    return _songsMap[filePath];
  }

  Future<void> addOrUpdateSong(MusicMetadata song) async {
    if (_songsMap.containsKey(song.filePath)) {
      // Preserve existing user data if scanning
      final existing = _songsMap[song.filePath]!;
      song.playCount = existing.playCount;
      song.isLiked = existing.isLiked;
      song.color = existing.color;
    }
    _songsMap[song.filePath] = song;
    await _saveToDisk();
  }

  Future<void> updateSong(MusicMetadata song) async {
    if (_songsMap.containsKey(song.filePath)) {
      _songsMap[song.filePath] = song;
      // Don't await saveToDisk for UI responsiveness, fire and forget
      _saveToDisk();
    }
  }

  Future<void> saveAll(List<MusicMetadata> songs) async {
    _songsMap = {for (var song in songs) song.filePath: song};
    await _saveToDisk();
  }
}
