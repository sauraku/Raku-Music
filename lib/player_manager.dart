import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:audio_service/audio_service.dart';
import 'music_metadata.dart';
import 'music_service.dart';

abstract class IPlayerManager {
  Stream<PlayerState> get playerStateStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<MusicMetadata?> get currentSongStream;
  Stream<LoopMode> get loopModeStream;
  MusicMetadata? get currentSong;

  Future<void> playSong(MusicMetadata song, List<MusicMetadata> playlist);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> next();
  Future<void> previous();
  Future<void> setLoopMode(LoopMode loopMode);
  void dispose();
}

class PlayerManager extends BaseAudioHandler implements IPlayerManager {
  static final PlayerManager _instance = PlayerManager._internal();
  factory PlayerManager() => _instance;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final MusicService _musicService = MusicService();
  
  // Streams
  @override
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;
  @override
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  @override
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  @override
  Stream<LoopMode> get loopModeStream => _audioPlayer.loopModeStream;
  
  // Current song
  final BehaviorSubject<MusicMetadata?> _currentSongSubject = BehaviorSubject<MusicMetadata?>.seeded(null);
  @override
  Stream<MusicMetadata?> get currentSongStream => _currentSongSubject.stream;
  @override
  MusicMetadata? get currentSong => _currentSongSubject.value;

  // Playlist
  List<MusicMetadata> _playlist = [];
  int _currentIndex = -1;
  bool _playCountIncrementedForCurrentSong = false;

  PlayerManager._internal() {
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        // Let just_audio handle looping, only auto-play next if not looping
        if (_audioPlayer.loopMode != LoopMode.one) {
          next();
        }
      }
      _updatePlaybackState(state);
    });

    _audioPlayer.positionStream.listen((position) {
      _updatePlaybackState(_audioPlayer.playerState);
      _checkAndIncrementPlayCount(position);
    });
  }

  void _checkAndIncrementPlayCount(Duration position) {
    final duration = _audioPlayer.duration;
    if (duration == null || duration.inSeconds == 0) return;
    if (_playCountIncrementedForCurrentSong) return;

    final tenPercent = duration.inSeconds * 0.1;
    if (position.inSeconds >= tenPercent) {
      if (_currentSongSubject.value != null) {
        _musicService.incrementPlayCount(_currentSongSubject.value!);
        _playCountIncrementedForCurrentSong = true;
      }
    }
  }

  void _updatePlaybackState(PlayerState state) {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (state.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[state.processingState]!,
      playing: state.playing,
      updatePosition: _audioPlayer.position,
      bufferedPosition: _audioPlayer.bufferedPosition,
      speed: _audioPlayer.speed,
      queueIndex: _currentIndex,
    ));
  }

  void _updateMediaItem(MusicMetadata song) {
    mediaItem.add(MediaItem(
      id: song.filePath,
      album: song.album,
      title: song.title,
      artist: song.artist,
      duration: _audioPlayer.duration,
      artUri: null,
    ));
  }

  @override
  Future<void> playSong(MusicMetadata song, List<MusicMetadata> playlist) async {
    _playlist = playlist;
    _currentIndex = playlist.indexOf(song);
    _currentSongSubject.add(song);
    _playCountIncrementedForCurrentSong = false;
    
    try {
      await _audioPlayer.setFilePath(song.filePath);
      _updateMediaItem(song);
      await _audioPlayer.play();
    } catch (e) {
      print("Error playing song: $e");
    }
  }

  @override
  Future<void> play() async {
    await _audioPlayer.play();
  }

  @override
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  @override
  Future<void> next() async {
    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
      await playSong(_playlist[_currentIndex], _playlist);
    } else if (_audioPlayer.loopMode == LoopMode.all) {
      _currentIndex = 0;
      await playSong(_playlist[_currentIndex], _playlist);
    }
  }

  @override
  Future<void> previous() async {
    if (_currentIndex > 0) {
      _currentIndex--;
      await playSong(_playlist[_currentIndex], _playlist);
    }
  }
  
  @override
  Future<void> skipToNext() => next();

  @override
  Future<void> skipToPrevious() => previous();

  @override
  Future<void> setLoopMode(LoopMode loopMode) async {
    await _audioPlayer.setLoopMode(loopMode);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _currentSongSubject.close();
  }
}
