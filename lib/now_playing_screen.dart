import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:palette_generator/palette_generator.dart';
import 'dart:io';
import 'dart:async';
import 'player_manager.dart';
import 'music_service.dart';
import 'music_metadata.dart';
import 'waveform_progress_bar.dart';

class NowPlayingScreen extends StatefulWidget {
  final Animation<double>? animation;

  const NowPlayingScreen({
    super.key,
    this.animation,
  });

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  final PlayerManager _playerManager = PlayerManager();
  final MusicService _musicService = MusicService();
  Color? _backgroundColor;
  Future<List<double>?>? _waveformFuture;
  Future<File?>? _artFuture;
  bool _isAnimationCompleted = false;
  StreamSubscription<MusicMetadata?>? _songSubscription;

  @override
  void initState() {
    super.initState();
    
    if (widget.animation != null) {
      widget.animation!.addStatusListener(_onAnimationStatusChanged);
      if (widget.animation!.status == AnimationStatus.completed) {
        _onAnimationStatusChanged(AnimationStatus.completed);
      }
    } else {
      // If no animation provided (e.g. direct navigation), load immediately
      _isAnimationCompleted = true;
      _loadDataForSong(_playerManager.currentSong);
    }

    _songSubscription = _playerManager.currentSongStream.listen((song) {
      if (_isAnimationCompleted) {
        _loadDataForSong(song);
      }
    });
  }

  @override
  void dispose() {
    _songSubscription?.cancel();
    widget.animation?.removeStatusListener(_onAnimationStatusChanged);
    super.dispose();
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // Postpone heavy loading until animation is fully done
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isAnimationCompleted = true;
          });
          _loadDataForSong(_playerManager.currentSong);
        }
      });
    }
  }

  void _loadDataForSong(MusicMetadata? song) {
    if (song == null) return;
    if (mounted) {
      setState(() {
        _artFuture = _musicService.getAlbumArt(song);
        _waveformFuture = _musicService.getWaveform(song);
        _updatePalette(song);
      });
    }
  }

  Future<void> _updatePalette(MusicMetadata song) async {
    // 1. Use cached color if available
    if (song.color != null) {
      if (mounted) {
        setState(() {
          _backgroundColor = Color(song.color!);
        });
      }
      return;
    }

    // 2. If not, generate and save it
    final artFile = await _artFuture;
    if (artFile != null) {
      final palette = await PaletteGenerator.fromImageProvider(
        FileImage(artFile),
        maximumColorCount: 20,
      );
      final color = palette.dominantColor?.color;
      if (color != null && mounted) {
        setState(() {
          _backgroundColor = color;
        });
        // Save the color for future use
        await _musicService.updateSongColor(song, color.value);
      }
    } else if (mounted) {
      setState(() {
        _backgroundColor = null;
      });
    }
  }

  Future<void> _toggleLike(MusicMetadata song) async {
    await _musicService.toggleLike(song);
    setState(() {
      // The state is now managed by the repository, just need to trigger a rebuild
    });
  }

  void _toggleLoopMode(LoopMode currentMode) {
    LoopMode nextMode;
    switch (currentMode) {
      case LoopMode.off:
        nextMode = LoopMode.all;
        break;
      case LoopMode.all:
        nextMode = LoopMode.one;
        break;
      case LoopMode.one:
        nextMode = LoopMode.off;
        break;
    }
    _playerManager.setLoopMode(nextMode);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      color: _backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
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
            stream: _playerManager.currentSongStream,
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
                          future: _artFuture,
                          builder: (context, artSnapshot) {
                            final artFile = artSnapshot.data;
                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              child: Container(
                                key: ValueKey(artFile?.path ?? 'placeholder'),
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
                              ),
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
                    SizedBox(
                      height: 100,
                      child: FutureBuilder<List<double>?>(
                        future: _waveformFuture,
                        builder: (context, waveformSnapshot) {
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            child: (waveformSnapshot.hasData && waveformSnapshot.data!.isNotEmpty)
                                ? StreamBuilder<Duration>(
                                    stream: _playerManager.positionStream,
                                    builder: (context, positionSnapshot) {
                                      return StreamBuilder<Duration?>(
                                        stream: _playerManager.durationStream,
                                        builder: (context, durationSnapshot) {
                                          return WaveformProgressBar(
                                            waveformData: waveformSnapshot.data!,
                                            progress: positionSnapshot.data ?? Duration.zero,
                                            total: durationSnapshot.data ?? Duration.zero,
                                            onSeek: _playerManager.seek,
                                          );
                                        },
                                      );
                                    },
                                  )
                                : StreamBuilder<Duration>(
                                    stream: _playerManager.positionStream,
                                    builder: (context, positionSnapshot) {
                                      return StreamBuilder<Duration?>(
                                        stream: _playerManager.durationStream,
                                        builder: (context, durationSnapshot) {
                                          final position = positionSnapshot.data ?? Duration.zero;
                                          final duration = durationSnapshot.data ?? Duration.zero;
                                          double progress = 0.0;
                                          if (duration.inMilliseconds > 0) {
                                            progress = position.inMilliseconds / duration.inMilliseconds;
                                          }
                                          return Center(
                                            child: LinearProgressIndicator(
                                              value: progress,
                                              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Theme.of(context).colorScheme.primary,
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(
                            song.isLiked ? Icons.favorite : Icons.favorite_border,
                            color: song.isLiked ? Colors.red : null,
                          ),
                          onPressed: () => _toggleLike(song),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_previous, size: 32),
                          onPressed: _playerManager.previous,
                        ),
                        StreamBuilder<PlayerState>(
                          stream: _playerManager.playerStateStream,
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
                                onPressed: _playerManager.play,
                              );
                            } else {
                              return IconButton(
                                icon: const Icon(Icons.pause_circle_filled, size: 64),
                                color: Theme.of(context).colorScheme.primary,
                                onPressed: _playerManager.pause,
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next, size: 32),
                          onPressed: _playerManager.next,
                        ),
                        StreamBuilder<LoopMode>(
                          stream: _playerManager.loopModeStream,
                          builder: (context, snapshot) {
                            final loopMode = snapshot.data ?? LoopMode.off;
                            IconData icon;
                            Color? color;
                            switch (loopMode) {
                              case LoopMode.off:
                                icon = Icons.repeat;
                                color = Theme.of(context).disabledColor;
                                break;
                              case LoopMode.all:
                                icon = Icons.repeat;
                                color = Theme.of(context).colorScheme.primary;
                                break;
                              case LoopMode.one:
                                icon = Icons.repeat_one;
                                color = Theme.of(context).colorScheme.primary;
                                break;
                            }
                            return IconButton(
                              icon: Icon(icon, color: color),
                              onPressed: () => _toggleLoopMode(loopMode),
                            );
                          },
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
      ),
    );
  }
}
