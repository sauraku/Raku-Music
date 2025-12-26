import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:typed_data';
import 'package:audiotags/audiotags.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'app_config.dart';
import 'music_metadata.dart';

abstract class IMusicService {
  Future<List<MusicMetadata>> loadMetadata();
  Future<void> saveMetadata(List<MusicMetadata> metadataList);
  Future<void> scanFolders(List<String> folders);
  Future<void> toggleLike(MusicMetadata song);
  Future<void> incrementPlayCount(MusicMetadata song);
  Future<List<double>?> getWaveform(MusicMetadata song);
  Future<File?> getAlbumArt(MusicMetadata song);
}

class MusicService implements IMusicService {
  static const String _metadataFileName = 'settings.json'; // Re-using settings file for simplicity
  static const String _waveformCacheVersion = '_v2'; // Cache invalidation key

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
      final Map<String, dynamic> json = jsonDecode(content);
      final List<dynamic>? songsJson = json['songs'];
      if (songsJson != null) {
        return songsJson.map((s) => MusicMetadata.fromJson(s)).toList();
      }
      return [];
    } catch (e) {
      print('Error loading metadata: $e');
      return [];
    }
  }

  @override
  Future<void> saveMetadata(List<MusicMetadata> metadataList) async {
    final file = await _getMetadataFile();
    final jsonList = metadataList.map((m) => m.toJson()).toList();
    
    Map<String, dynamic> currentSettings = {};
    if (await file.exists()) {
      try {
        currentSettings = jsonDecode(await file.readAsString());
      } catch (e) { /* ignore */ }
    }
    currentSettings['songs'] = jsonList;
    await file.writeAsString(jsonEncode(currentSettings));
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

  @override
  Future<void> toggleLike(MusicMetadata song) async {
    List<MusicMetadata> allSongs = await loadMetadata();
    final index = allSongs.indexWhere((s) => s.filePath == song.filePath);
    
    if (index != -1) {
      allSongs[index].isLiked = !allSongs[index].isLiked;
      await saveMetadata(allSongs);
    }
  }

  @override
  Future<void> incrementPlayCount(MusicMetadata song) async {
    List<MusicMetadata> allSongs = await loadMetadata();
    final index = allSongs.indexWhere((s) => s.filePath == song.filePath);
    
    if (index != -1) {
      allSongs[index].playCount++;
      await saveMetadata(allSongs);
    }
  }

  @override
  Future<List<double>?> getWaveform(MusicMetadata song) async {
    final configDir = await AppConfig.getAppConfigDirectory();
    final waveformsDir = Directory(p.join(configDir.path, 'waveforms'));
    if (!await waveformsDir.exists()) {
      await waveformsDir.create();
    }

    final hash = sha1.convert(utf8.encode(song.filePath + _waveformCacheVersion)).toString();
    final cacheFile = File(p.join(waveformsDir.path, '$hash.json'));

    if (await cacheFile.exists()) {
      try {
        final content = await cacheFile.readAsString();
        final List<dynamic> data = jsonDecode(content);
        return data.map((d) => d as double).toList();
      } catch (e) {
        print('Error reading waveform cache: $e');
      }
    }

    // --- FFMPEG REAL WAVEFORM GENERATION ---
    try {
      final process = await Process.start('ffmpeg', [
        '-hide_banner',
        '-loglevel', 'error',
        '-i', song.filePath,
        '-ac', '1',
        '-filter:a', 'aresample=8000', // Increased sample rate for more detail
        '-map', '0:a',
        '-c:a', 'pcm_s16le',
        '-f', 'data',
        '-'
      ]);

      final completer = Completer<Uint8List>();
      final stdoutCollector = <int>[];
      
      process.stdout.listen(
        (data) => stdoutCollector.addAll(data),
        onDone: () => completer.complete(Uint8List.fromList(stdoutCollector)),
        onError: (error) => completer.completeError(error),
      );

      process.stderr.listen((_) {});

      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        print('ffmpeg process exited with code $exitCode');
        return null;
      }

      final pcmData = await completer.future;
      final waveform = _processPcmData(pcmData, 200); // Generate 200 points

      await cacheFile.writeAsString(jsonEncode(waveform));
      return waveform;

    } catch (e) {
      print('Error running ffmpeg. Is it installed and in your PATH? Error: $e');
      return null;
    }
  }

  List<double> _processPcmData(Uint8List pcmBytes, int targetSamples) {
    final byteData = ByteData.sublistView(pcmBytes);
    final totalSamples = pcmBytes.lengthInBytes ~/ 2;
    if (totalSamples == 0) return List.filled(targetSamples, 0.0);

    final samplesPerBar = totalSamples / targetSamples;
    
    final List<double> waveform = [];

    for (int i = 0; i < targetSamples; i++) {
      double maxSample = 0;
      final int start = (i * samplesPerBar).floor();
      final int end = ((i + 1) * samplesPerBar).floor();

      for (int j = start; j < end; j++) {
        if (j * 2 + 2 <= pcmBytes.lengthInBytes) {
          final sample = byteData.getInt16(j * 2, Endian.little).abs();
          if (sample > maxSample) {
            maxSample = sample.toDouble();
          }
        }
      }
      waveform.add(maxSample / 32768.0);
    }
    return waveform;
  }

  @override
  Future<File?> getAlbumArt(MusicMetadata song) async {
    final configDir = await AppConfig.getAppConfigDirectory();
    final artDir = Directory(p.join(configDir.path, 'album_art'));
    if (!await artDir.exists()) {
      await artDir.create();
    }

    final hash = sha1.convert(utf8.encode(song.filePath)).toString();
    final cacheFile = File(p.join(artDir.path, '$hash.jpg'));

    if (await cacheFile.exists()) {
      return cacheFile;
    }

    try {
      final tag = await AudioTags.read(song.filePath);
      final pictures = tag?.pictures;
      if (pictures != null && pictures.isNotEmpty) {
        final picture = pictures.first;
        // AudioTags returns picture data as Uint8List
        await cacheFile.writeAsBytes(picture.bytes);
        return cacheFile;
      }
    } catch (e) {
      print('Error extracting album art for ${song.filePath}: $e');
    }
    return null;
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
