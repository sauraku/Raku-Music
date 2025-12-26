import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:audiotags/audiotags.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'app_config.dart';
import 'music_metadata.dart';
import 'worker_service.dart';
import 'metadata_repository.dart';

abstract class IMusicService {
  Future<List<MusicMetadata>> loadMetadata();
  Future<void> scanFolders(List<String> folders);
  Future<void> toggleLike(MusicMetadata song);
  Future<void> incrementPlayCount(MusicMetadata song);
  Future<List<double>?> getWaveform(MusicMetadata song);
  Future<File?> getAlbumArt(MusicMetadata song);
  Future<Color?> getDominantColor(File imageFile);
  Future<void> updateSongColor(MusicMetadata song, int colorValue);
}

class MusicService implements IMusicService {
  static const String _waveformCacheVersion = '_v2';
  final WorkerService _worker = WorkerService();
  final MetadataRepository _repository = MetadataRepository();

  @override
  Future<List<MusicMetadata>> loadMetadata() async {
    await _repository.init();
    return _repository.getAllSongs();
  }

  @override
  Future<void> scanFolders(List<String> folders) async {
    await _repository.init();
    
    final existingSongs = _repository.getAllSongs();
    final existingPaths = existingSongs.map((s) => s.filePath).toSet();
    
    for (String folderPath in folders) {
      final directory = Directory(folderPath);
      if (!await directory.exists()) continue;

      await for (final entity in directory.list(recursive: true, followLinks: false)) {
        if (entity is File && _isAudioFile(entity.path) && !existingPaths.contains(entity.path)) {
          final metadata = await _extractMetadata(entity);
          await _repository.addOrUpdateSong(metadata);
        }
      }
    }
  }

  @override
  Future<void> toggleLike(MusicMetadata song) async {
    song.isLiked = !song.isLiked;
    await _repository.updateSong(song);
  }

  @override
  Future<void> incrementPlayCount(MusicMetadata song) async {
    song.playCount++;
    await _repository.updateSong(song);
  }

  @override
  Future<void> updateSongColor(MusicMetadata song, int colorValue) async {
    song.color = colorValue;
    await _repository.updateSong(song);
  }

  @override
  Future<List<double>?> getWaveform(MusicMetadata song) async {
    final configDir = await AppConfig.getAppConfigDirectory();
    final waveformsDir = Directory(p.join(configDir.path, 'waveforms'));
    if (!await waveformsDir.exists()) await waveformsDir.create();

    final hash = sha1.convert(utf8.encode(song.filePath + _waveformCacheVersion)).toString();
    final cacheFile = File(p.join(waveformsDir.path, '$hash.json'));

    if (await cacheFile.exists()) {
      try {
        final content = await cacheFile.readAsString();
        return (jsonDecode(content) as List<dynamic>).cast<double>();
      } catch (e) {
        print('Error reading waveform cache: $e');
      }
    }

    final waveformData = await _worker.getWaveform(song.filePath);
    if (waveformData != null) {
      await cacheFile.writeAsString(jsonEncode(waveformData));
    }
    return waveformData;
  }

  @override
  Future<File?> getAlbumArt(MusicMetadata song) async {
    final configDir = await AppConfig.getAppConfigDirectory();
    final artDir = Directory(p.join(configDir.path, 'album_art'));
    if (!await artDir.exists()) await artDir.create();

    final hash = sha1.convert(utf8.encode(song.filePath)).toString();
    final cacheFile = File(p.join(artDir.path, '$hash.jpg'));

    if (await cacheFile.exists()) {
      return cacheFile;
    }

    final artData = await _worker.getAlbumArt(song.filePath);
    if (artData != null) {
      await cacheFile.writeAsBytes(artData);
      return cacheFile;
    }
    return null;
  }

  @override
  Future<Color?> getDominantColor(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return _worker.getDominantColor(bytes);
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
