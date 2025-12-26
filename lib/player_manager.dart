import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'music_metadata.dart';

abstract class IPlayerManager {
  Stream<PlayerState> get playerStateStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<MusicMetadata?> get currentSongStream;
  MusicMetadata? get currentSong;

  Future<void> playSong(MusicMetadata song, List<MusicMetadata> playlist);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> next();
  Future<void> previous();
  void dispose();
}

class PlayerManager implements IPlayerManager {
  static final PlayerManager _instance = PlayerManager._internal();
  factory PlayerManager() => _instance;
  PlayerManager._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Streams
  @override
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;
  @override
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  @override
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  
  // Current song
  final BehaviorSubject<MusicMetadata?> _currentSongSubject = BehaviorSubject<MusicMetadata?>.seeded(null);
  @override
  Stream<MusicMetadata?> get currentSongStream => _currentSongSubject.stream;
  @override
  MusicMetadata? get currentSong => _currentSongSubject.value;

  // Playlist
  List<MusicMetadata> _playlist = [];
  int _currentIndex = -1;

  @override
  Future<void> playSong(MusicMetadata song, List<MusicMetadata> playlist) async {
    _playlist = playlist;
    _currentIndex = playlist.indexOf(song);
    _currentSongSubject.add(song);
    
    try {
      await _audioPlayer.setFilePath(song.filePath);
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
  void dispose() {
    _audioPlayer.dispose();
    _currentSongSubject.close();
  }
}
