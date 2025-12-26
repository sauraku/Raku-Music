import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'player_manager.dart';
import 'music_service.dart';
import 'music_metadata.dart';
import 'waveform_progress_bar.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playerManager = PlayerManager();
    final musicService = MusicService();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Now Playing'),
        centerTitle: true,
      ),
      body: SizedBox(
        width: double.infinity,
        child: StreamBuilder<MusicMetadata?>(
          stream: playerManager.currentSongStream,
          builder: (context, snapshot) {
            final song = snapshot.data;
            if (song == null) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Album Art
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: FutureBuilder<File?>(
                        future: musicService.getAlbumArt(song),
                        builder: (context, artSnapshot) {
                          final artFile = artSnapshot.data;
                          return Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                              image: artFile != null
                                  ? DecorationImage(
                                      image: FileImage(artFile),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: artFile == null
                                ? const Icon(Icons.music_note, size: 120)
                                : null,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Song Info
                  Text(
                    song.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    song.artist,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 32),
                  // Waveform Progress Bar
                  FutureBuilder<List<double>?>(
                    future: musicService.getWaveform(song),
                    builder: (context, waveformSnapshot) {
                      final waveformData = waveformSnapshot.data;
                      if (waveformData == null || waveformData.isEmpty) {
                        return const SizedBox(height: 100, child: Center(child: Text("Generating waveform...")));
                      }
                      return StreamBuilder<Duration>(
                        stream: playerManager.positionStream,
                        builder: (context, positionSnapshot) {
                          final position = positionSnapshot.data ?? Duration.zero;
                          return StreamBuilder<Duration?>(
                            stream: playerManager.durationStream,
                            builder: (context, durationSnapshot) {
                              final duration = durationSnapshot.data ?? Duration.zero;
                              return WaveformProgressBar(
                                waveformData: waveformData,
                                progress: position,
                                total: duration,
                                onSeek: playerManager.seek,
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous, size: 32),
                        onPressed: playerManager.previous,
                      ),
                      StreamBuilder<PlayerState>(
                        stream: playerManager.playerStateStream,
                        builder: (context, snapshot) {
                          final playerState = snapshot.data;
                          final processingState = playerState?.processingState;
                          final playing = playerState?.playing;
                          
                          if (processingState == ProcessingState.loading ||
                              processingState == ProcessingState.buffering) {
                            return Container(
                              margin: const EdgeInsets.all(8.0),
                              width: 64.0,
                              height: 64.0,
                              child: const CircularProgressIndicator(),
                            );
                          } else if (playing != true) {
                            return IconButton(
                              icon: const Icon(Icons.play_circle_fill, size: 64),
                              color: Theme.of(context).colorScheme.primary,
                              onPressed: playerManager.play,
                            );
                          } else {
                            return IconButton(
                              icon: const Icon(Icons.pause_circle_filled, size: 64),
                              color: Theme.of(context).colorScheme.primary,
                              onPressed: playerManager.pause,
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next, size: 32),
                        onPressed: playerManager.next,
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
