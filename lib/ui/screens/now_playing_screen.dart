import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'dart:async';
import '../../services/player_manager.dart';
import '../../services/music_service.dart';
import '../../data/models/music_metadata.dart';
import '../components/waveform_progress_bar.dart';

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
  Color? _accentColor;
  Color? _textColor;
  Future<List<double>?>? _waveformFuture;
  Future<File?>? _artFuture;
  bool _isAnimationCompleted = false;
  StreamSubscription<MusicMetadata?>? _songSubscription;
  File? _currentArtFile;

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
    // Evict the current image from cache when leaving the screen
    if (_currentArtFile != null) {
      final imageProvider = FileImage(_currentArtFile!);
      imageProvider.evict();
      // Also evict the resized version
      ResizeImage(imageProvider, width: 800).evict();
    }
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
    
    // Evict previous image if exists
    if (_currentArtFile != null) {
      final imageProvider = FileImage(_currentArtFile!);
      imageProvider.evict();
      ResizeImage(imageProvider, width: 800).evict();
      _currentArtFile = null;
    }

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
        final color = Color(song.color!);
        _setColorsFromPalette(color);
      }
      return;
    }

    // 2. If not, generate and save it
    final artFile = await _artFuture;
    if (artFile != null) {
      _currentArtFile = artFile;
      // Use WorkerService to get dominant color instead of PaletteGenerator
      // This avoids creating a UI image and uploading texture to GPU
      final color = await _musicService.getDominantColor(artFile);

      if (color != null && mounted) {
        _setColorsFromPalette(color);
        // Save the color for future use
        await _musicService.updateSongColor(song, color.value);
      }
    } else if (mounted) {
      // Reset colors if no album art is available
      setState(() {
        _backgroundColor = null;
        _accentColor = null;
        _textColor = null;
      });
    }
  }

  void _setColorsFromPalette(Color color) {
    final isDark = color.computeLuminance() < 0.4;
    setState(() {
      _backgroundColor = color;
      _accentColor = isDark ? _lighten(color, 0.4) : _darken(color, 0.4);
      _textColor = isDark ? Colors.white : Colors.black;
    });
  }

  Color _darken(Color color, [double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  Color _lighten(Color color, [double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }

  Future<void> _toggleLike(MusicMetadata song) async {
    await _musicService.toggleLike(song);
    setState(() {
      // The state is now managed by the repository, just need to trigger a rebuild
    });
  }

  void _togglePlayPause() {
    _playerManager.togglePlayPause();
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

  void _showSpeedDialog(BuildContext context) {
    final dialogBackgroundColor = _accentColor ?? Theme.of(context).colorScheme.primary;
    final sliderActiveColor = _backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;
    final dialogTextColor = dialogBackgroundColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: dialogBackgroundColor,
          title: Text('Playback Speed', style: TextStyle(color: dialogTextColor)),
          content: StreamBuilder<double>(
            stream: _playerManager.speedStream,
            builder: (context, snapshot) {
              final speed = snapshot.data ?? 1.0;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${speed.toStringAsFixed(1)}x',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: dialogTextColor),
                  ),
                  Slider(
                    value: speed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    activeColor: sliderActiveColor,
                    inactiveColor: sliderActiveColor.withOpacity(0.3),
                    onChanged: (value) {
                      _playerManager.setSpeed(value);
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close', style: TextStyle(color: dialogTextColor)),
            ),
          ],
        );
      },
    );
  }

  void _showEditMetadataDialog(BuildContext context, MusicMetadata song) async {
    final titleController = TextEditingController(text: song.title);
    final artistController = TextEditingController(text: song.artist);
    final albumController = TextEditingController(text: song.album);
    final dialogBackgroundColor = _accentColor ?? Theme.of(context).colorScheme.primary;
    final dialogTextColor = dialogBackgroundColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    // Fetch autocomplete options
    final allArtists = await _musicService.getAllArtists();
    final allAlbums = await _musicService.getAllAlbums();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: dialogBackgroundColor,
          title: Text('Edit Info', style: TextStyle(color: dialogTextColor)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(color: dialogTextColor.withOpacity(0.7)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: dialogTextColor.withOpacity(0.5))),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: dialogTextColor)),
                  ),
                  style: TextStyle(color: dialogTextColor),
                ),
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') {
                      return const Iterable<String>.empty();
                    }
                    return allArtists.where((String option) {
                      return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String selection) {
                    artistController.text = selection;
                  },
                  fieldViewBuilder: (BuildContext context, TextEditingController fieldController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
                    // Set initial value
                    fieldController.text = artistController.text;
                    return TextField(
                      controller: fieldController,
                      focusNode: fieldFocusNode,
                      decoration: InputDecoration(
                        labelText: 'Artist',
                        labelStyle: TextStyle(color: dialogTextColor.withOpacity(0.7)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: dialogTextColor.withOpacity(0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: dialogTextColor)),
                      ),
                      style: TextStyle(color: dialogTextColor),
                      onChanged: (text) => artistController.text = text,
                    );
                  },
                ),
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') {
                      return const Iterable<String>.empty();
                    }
                    return allAlbums.where((String option) {
                      return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String selection) {
                    albumController.text = selection;
                  },
                  fieldViewBuilder: (BuildContext context, TextEditingController fieldController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
                    // Set initial value
                    fieldController.text = albumController.text;
                    return TextField(
                      controller: fieldController,
                      focusNode: fieldFocusNode,
                      decoration: InputDecoration(
                        labelText: 'Album',
                        labelStyle: TextStyle(color: dialogTextColor.withOpacity(0.7)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: dialogTextColor.withOpacity(0.5))),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: dialogTextColor)),
                      ),
                      style: TextStyle(color: dialogTextColor),
                      onChanged: (text) => albumController.text = text,
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: dialogTextColor)),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await _musicService.updateMetadata(
                    song,
                    titleController.text,
                    artistController.text,
                    albumController.text,
                  );
                  
                  final updatedSong = MusicMetadata(
                    filePath: song.filePath,
                    title: titleController.text,
                    artist: artistController.text,
                    album: albumController.text,
                    year: song.year,
                    playCount: song.playCount,
                    isLiked: song.isLiked,
                    color: song.color,
                  );
                  _playerManager.updateCurrentSongMetadata(updatedSong);

                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Metadata updated successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating metadata: $e')),
                    );
                  }
                }
              },
              child: Text('Save', style: TextStyle(color: dialogTextColor, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _accentColor ?? Theme.of(context).colorScheme.primary;
    final textColor = _textColor ?? Theme.of(context).textTheme.bodyMedium?.color;
    final secondaryTextColor = textColor?.withOpacity(0.7);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      color: _backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
            ? DragToMoveArea(
                child: _buildAppBar(context, textColor),
              )
            : _buildAppBar(context, textColor),
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
                      child: GestureDetector(
                        onTap: _togglePlayPause,
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
                                            image: ResizeImage(FileImage(artFile), width: 800),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: artFile == null
                                      ? LayoutBuilder(
                                          builder: (context, constraints) {
                                            return Icon(
                                              Icons.music_note,
                                              size: constraints.maxWidth * 0.7,
                                              color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.5),
                                            );
                                          },
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Song Info
                    Text(
                      song.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      song.artist,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: secondaryTextColor,
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
                                          return Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                child: WaveformProgressBar(
                                                  waveformData: waveformSnapshot.data!,
                                                  progress: positionSnapshot.data ?? Duration.zero,
                                                  total: durationSnapshot.data ?? Duration.zero,
                                                  onSeek: _playerManager.seek,
                                                  color: accentColor,
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      _formatDuration(positionSnapshot.data),
                                                      style: TextStyle(color: secondaryTextColor, fontSize: 12),
                                                    ),
                                                    Text(
                                                      _formatDuration(durationSnapshot.data),
                                                      style: TextStyle(color: secondaryTextColor, fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
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
                                          return Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                child: Center(
                                                  child: LinearProgressIndicator(
                                                    value: progress,
                                                    backgroundColor: secondaryTextColor?.withOpacity(0.2),
                                                    valueColor: AlwaysStoppedAnimation<Color>(
                                                      accentColor,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      _formatDuration(position),
                                                      style: TextStyle(color: secondaryTextColor, fontSize: 12),
                                                    ),
                                                    Text(
                                                      _formatDuration(duration),
                                                      style: TextStyle(color: secondaryTextColor, fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
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
                            color: song.isLiked ? accentColor : accentColor.withOpacity(0.7),
                          ),
                          onPressed: () => _toggleLike(song),
                        ),
                        IconButton(
                          icon: Icon(Icons.skip_previous, size: 32, color: accentColor),
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
                                child: CircularProgressIndicator(color: accentColor),
                              );
                            } else if (playing != true) {
                              return IconButton(
                                icon: Icon(Icons.play_circle_fill, size: 64, color: accentColor),
                                onPressed: _playerManager.play,
                              );
                            } else {
                              return IconButton(
                                icon: Icon(Icons.pause_circle_filled, size: 64, color: accentColor),
                                onPressed: _playerManager.pause,
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.skip_next, size: 32, color: accentColor),
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
                                color = secondaryTextColor;
                                break;
                              case LoopMode.all:
                                icon = Icons.repeat;
                                color = accentColor;
                                break;
                              case LoopMode.one:
                                icon = Icons.repeat_one;
                                color = accentColor;
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

  Widget _buildAppBar(BuildContext context, Color? textColor) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.keyboard_arrow_down, color: textColor),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text('Now Playing', style: TextStyle(color: textColor)),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(Icons.edit, color: textColor),
          onPressed: () {
            final song = _playerManager.currentSong;
            if (song != null) {
              _showEditMetadataDialog(context, song);
            }
          },
        ),
        IconButton(
          icon: Icon(Icons.speed, color: textColor),
          onPressed: () => _showSpeedDialog(context),
        ),
      ],
    );
  }
}
