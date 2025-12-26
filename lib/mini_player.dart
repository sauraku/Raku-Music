import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'player_manager.dart';
import 'music_metadata.dart';
import 'now_playing_screen.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final playerManager = PlayerManager();

    return StreamBuilder<MusicMetadata?>(
      stream: playerManager.currentSongStream,
      builder: (context, snapshot) {
        final song = snapshot.data;
        if (song == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (context) => const NowPlayingScreen(),
            );
          },
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              children: [
                // Progress Bar (Thin line at top)
                StreamBuilder<Duration>(
                  stream: playerManager.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    return StreamBuilder<Duration?>(
                      stream: playerManager.durationStream,
                      builder: (context, snapshot) {
                        final duration = snapshot.data ?? Duration.zero;
                        if (duration == Duration.zero) return const SizedBox(height: 2);
                        return LinearProgressIndicator(
                          value: position.inMilliseconds / duration.inMilliseconds,
                          minHeight: 2,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        );
                      },
                    );
                  },
                ),
                Expanded(
                  child: Row(
                    children: [
                      // Album Art Placeholder
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.music_note),
                          ),
                        ),
                      ),
                      // Song Info
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      // Controls
                      StreamBuilder<PlayerState>(
                        stream: playerManager.playerStateStream,
                        builder: (context, snapshot) {
                          final playerState = snapshot.data;
                          final processingState = playerState?.processingState;
                          final playing = playerState?.playing;
                          
                          if (processingState == ProcessingState.loading ||
                              processingState == ProcessingState.buffering) {
                            return const IconButton(
                              icon: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              onPressed: null,
                            );
                          } else if (playing != true) {
                            return IconButton(
                              icon: const Icon(Icons.play_arrow),
                              onPressed: playerManager.play,
                            );
                          } else {
                            return IconButton(
                              icon: const Icon(Icons.pause),
                              onPressed: playerManager.pause,
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        onPressed: playerManager.next,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
