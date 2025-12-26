import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:math';
import 'package:audiotags/audiotags.dart';
import 'package:image/image.dart' as img;
import 'package:palette_generator/palette_generator.dart';
import 'package:flutter/material.dart';

// --- Isolate Entry Point ---
void workerIsolate(SendPort sendPort) {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((message) async {
    final Map<String, dynamic> request = message;
    final String type = request['type'];
    final SendPort replyPort = request['replyPort'];

    try {
      if (type == 'waveform') {
        final String filePath = request['filePath'];
        final result = await _generateWaveform(filePath);
        replyPort.send(result);
      } else if (type == 'album_art') {
        final String filePath = request['filePath'];
        final result = await _extractAlbumArt(filePath);
        replyPort.send(result);
      } else if (type == 'palette') {
        final Uint8List imageBytes = request['imageBytes'];
        final result = await _generatePalette(imageBytes);
        replyPort.send(result);
      }
    } catch (e) {
      replyPort.send({'error': e.toString()});
    }
  });
}

// --- Task Implementations (run inside the isolate) ---

Future<int?> _generatePalette(Uint8List imageBytes) async {
  try {
    // Use the 'image' package to decode, as it has no Flutter dependency
    final image = img.decodeImage(imageBytes);
    if (image == null) return null;

    // We can't use PaletteGenerator here because it depends on dart:ui.
    // We need a pure Dart algorithm to find the dominant color.
    // A simple approach is to average the pixels or find the most frequent color.
    // For better results, we can use a simple quantization algorithm.
    
    // Simple average for now to avoid heavy dependencies or complex code
    // This is a placeholder. For real dominant color, we'd need a quantization algo.
    // Let's iterate and find the average color.
    
    int r = 0, g = 0, b = 0, count = 0;
    // Sample every 10th pixel for speed
    for (int y = 0; y < image.height; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        final pixel = image.getPixel(x, y);
        r += pixel.r.toInt();
        g += pixel.g.toInt();
        b += pixel.b.toInt();
        count++;
      }
    }
    
    if (count == 0) return null;
    
    return Color.fromARGB(255, r ~/ count, g ~/ count, b ~/ count).value;

  } catch (e) {
    print('Isolate palette error: $e');
    return null;
  }
}

Future<Uint8List?> _extractAlbumArt(String filePath) async {
  try {
    final tag = await AudioTags.read(filePath);
    return tag?.pictures?.first.bytes;
  } catch (e) {
    print('Isolate album art error: $e');
    return null;
  }
}

Future<List<double>?> _generateWaveform(String filePath) async {
  try {
    final process = await Process.start('ffmpeg', [
      '-hide_banner', '-loglevel', 'error', '-i', filePath,
      '-ac', '1', '-filter:a', 'aresample=8000', '-map', '0:a',
      '-c:a', 'pcm_s16le', '-f', 'data', '-'
    ]);
    final pcmData = await process.stdout.fold<List<int>>([], (p, e) => p..addAll(e));
    final exitCode = await process.exitCode;
    if (exitCode != 0) return null;
    return _processPcmData(Uint8List.fromList(pcmData), 200);
  } catch (e) {
    print('Isolate ffmpeg run error: $e');
    return null;
  }
}

List<double> _processPcmData(Uint8List pcmBytes, int targetSamples) {
  final byteData = ByteData.sublistView(pcmBytes);
  final totalSamples = pcmBytes.lengthInBytes ~/ 2;
  if (totalSamples == 0) return List.filled(targetSamples, 0.0);

  final samplesPerBar = totalSamples / targetSamples;
  final waveform = <double>[];
  
  // First pass: collect RMS values instead of Peak
  // RMS (Root Mean Square) gives a better representation of loudness/energy
  // and avoids the "brick wall" look of compressed audio where peaks are always maxed.
  double globalMax = 0;
  for (int i = 0; i < targetSamples; i++) {
    double sumSquares = 0;
    int count = 0;
    
    final int start = (i * samplesPerBar).floor();
    final int end = ((i + 1) * samplesPerBar).floor();

    for (int j = start; j < end; j++) {
      if (j * 2 + 2 <= pcmBytes.lengthInBytes) {
        final sample = byteData.getInt16(j * 2, Endian.little);
        sumSquares += sample * sample;
        count++;
      }
    }
    
    final double rms = count > 0 ? sqrt(sumSquares / count) : 0.0;
    waveform.add(rms);
    if (rms > globalMax) globalMax = rms;
  }

  // Second pass: normalize relative to the song's max RMS
  // Use a minimum threshold to avoid amplifying silence too much
  final double normalizationFactor = globalMax > 100 ? globalMax : 32768.0;
  
  return waveform.map((sample) {
    double normalized = sample / normalizationFactor;
    // Use linear scaling (no power function) to preserve the natural dynamic range
    // This prevents the "maxed out" look by allowing quieter parts to actually look quieter
    return normalized;
  }).toList();
}

// --- Service to manage the isolate from the main UI thread ---

class WorkerService {
  static final WorkerService _instance = WorkerService._internal();
  factory WorkerService() => _instance;

  late Isolate _isolate;
  late SendPort _sendPort;
  bool _isInitialized = false;

  WorkerService._internal() {
    _init();
  }

  Future<void> _init() async {
    if (_isInitialized) return;
    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(workerIsolate, receivePort.sendPort);
    _sendPort = await receivePort.first;
    _isInitialized = true;
  }

  Future<dynamic> _postRequest(Map<String, dynamic> message) async {
    if (!_isInitialized) await _init();
    final receivePort = ReceivePort();
    message['replyPort'] = receivePort.sendPort;
    _sendPort.send(message);
    final result = await receivePort.first;
    if (result is Map && result.containsKey('error')) {
      print('Worker error: ${result['error']}');
      return null;
    }
    return result;
  }

  Future<List<double>?> getWaveform(String filePath) async {
    final result = await _postRequest({'type': 'waveform', 'filePath': filePath});
    return (result as List<dynamic>?)?.cast<double>();
  }

  Future<Uint8List?> getAlbumArt(String filePath) async {
    return await _postRequest({'type': 'album_art', 'filePath': filePath}) as Uint8List?;
  }

  Future<Color?> getDominantColor(Uint8List imageBytes) async {
    final colorValue = await _postRequest({'type': 'palette', 'imageBytes': imageBytes});
    return colorValue != null ? Color(colorValue) : null;
  }

  void dispose() {
    _isolate.kill();
  }
}
