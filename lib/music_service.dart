import 'dart:convert';
import 'dart:io';
import 'package:audiotags/audiotags.dart';
import 'package:path/path.dart' as p;
import 'app_config.dart';
import 'music_metadata.dart';

abstract class IMusicService {
  Future<List<MusicMetadata>> loadMetadata();
  Future<void> saveMetadata(List<MusicMetadata> metadataList);
  Future<void> scanFolders(List<String> folders);
}

class MusicService implements IMusicService {
  static const String _metadataFileName = 'music_metadata.json';

  Future<File> _getMetadataFile() async {
    final directory = await AppConfig.getAppConfigDirectory();
    return File(p.join(directory.path, _metadataFileName));
  }

  @override
  Future<List<MusicMetadata>> loadMetadata() async {
    final file = await _getMetadataFile();
    if (!await file.exists()) {
      return [];
    }

    try {
      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((json) => MusicMetadata.fromJson(json)).toList();
    } catch (e) {
      print('Error loading metadata: $e');
      return [];
    }
  }

  @override
  Future<void> saveMetadata(List<MusicMetadata> metadataList) async {
    final file = await _getMetadataFile();
    final jsonList = metadataList.map((m) => m.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  @override
  Future<void> scanFolders(List<String> folders) async {
    List<MusicMetadata> existingMetadata = await loadMetadata();
    Map<String, MusicMetadata> metadataMap = {
      for (var m in existingMetadata) m.filePath: m
    };

    bool hasChanges = false;

    for (String folderPath in folders) {
      final directory = Directory(folderPath);
      if (!await directory.exists()) continue;

      await for (final entity in directory.list(recursive: true, followLinks: false)) {
        if (entity is File && _isAudioFile(entity.path)) {
          if (!metadataMap.containsKey(entity.path)) {
            final metadata = await _extractMetadata(entity);
            metadataMap[entity.path] = metadata;
            hasChanges = true;
          }
        }
      }
    }

    if (hasChanges) {
      await saveMetadata(metadataMap.values.toList());
    }
  }

  bool _isAudioFile(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.mp3', '.flac', '.m4a', '.wav', '.ogg'].contains(ext);
  }

  Future<MusicMetadata> _extractMetadata(File file) async {
    try {
      final tag = await AudioTags.read(file.path);
      return MusicMetadata(
        filePath: file.path,
        title: tag?.title ?? p.basenameWithoutExtension(file.path),
        artist: tag?.trackArtist ?? 'Unknown Artist',
        album: tag?.album ?? 'Unknown Album',
        year: tag?.year.toString() ?? 'Unknown Year',
      );
    } catch (e) {
      print('Error reading tags for ${file.path}: $e');
      return MusicMetadata(
        filePath: file.path,
        title: p.basenameWithoutExtension(file.path),
        artist: 'Unknown Artist',
        album: 'Unknown Album',
        year: 'Unknown Year',
      );
    }
  }
}
