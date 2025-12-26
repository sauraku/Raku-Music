import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'player_manager.dart';
import 'music_metadata.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playerManager = PlayerManager();

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
                      child: Container(
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
                        ),
                        child: const Icon(Icons.music_note, size: 120),
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
                  // Progress Bar
                  StreamBuilder<Duration>(
                    stream: playerManager.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      return StreamBuilder<Duration?>(
                        stream: playerManager.durationStream,
                        builder: (context, snapshot) {
                          final duration = snapshot.data ?? Duration.zero;
                          return ProgressBar(
                            progress: position,
                            total: duration,
                            onSeek: playerManager.seek,
                            baseBarColor: Theme.of(context).colorScheme.surfaceVariant,
                            progressBarColor: Theme.of(context).colorScheme.primary,
                            thumbColor: Theme.of(context).colorScheme.primary,
                            timeLabelLocation: TimeLabelLocation.sides,
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
