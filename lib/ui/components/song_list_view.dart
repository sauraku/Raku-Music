import 'package:flutter/material.dart';
import 'dart:math';
import '../../data/models/music_metadata.dart';
import '../../services/player_manager.dart';

class SongListView extends StatelessWidget {
  final List<MusicMetadata> songs;
  final Function(MusicMetadata) onToggleLike;
  final PlayerManager playerManager;

  const SongListView({
    super.key,
    required this.songs,
    required this.onToggleLike,
    required this.playerManager,
  });

  void _shufflePlay() {
    if (songs.isEmpty) return;
    final random = Random();
    final shuffledList = List<MusicMetadata>.from(songs)..shuffle(random);
    playerManager.playSong(shuffledList[0], shuffledList);
  }

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No songs found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        StreamBuilder<MusicMetadata?>(
          stream: playerManager.currentSongStream,
          builder: (context, snapshot) {
            final currentSong = snapshot.data;
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 80), // Add padding for FAB
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                final isPlaying = currentSong?.filePath == song.filePath;

                return ListTile(
                  selected: isPlaying,
                  selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  leading: CircleAvatar(
                    backgroundColor: isPlaying
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.primaryContainer,
                    child: isPlaying
                        ? Icon(Icons.graphic_eq, color: Theme.of(context).colorScheme.onPrimary)
                        : const Icon(Icons.music_note),
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                      color: isPlaying ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                  subtitle: Text(
                    '${song.artist} • ${song.album}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      song.isLiked ? Icons.favorite : Icons.favorite_border,
                      color: song.isLiked ? Theme.of(context).colorScheme.primary : null,
                    ),
                    onPressed: () => onToggleLike(song),
                  ),
                  onTap: () {
                    playerManager.playSong(song, songs);
                  },
                );
              },
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: _shufflePlay,
            child: const Icon(Icons.shuffle),
          ),
        ),
      ],
    );
  }
}
