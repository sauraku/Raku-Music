class MusicMetadata {
  final String filePath;
  final String title;
  final String artist;
  final String album;
  final String year;
  int playCount;
  bool isLiked;
  int? color;

  MusicMetadata({
    required this.filePath,
    required this.title,
    required this.artist,
    required this.album,
    required this.year,
    this.playCount = 0,
    this.isLiked = false,
    this.color,
  });

  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'title': title,
      'artist': artist,
      'album': album,
      'year': year,
      'playCount': playCount,
      'isLiked': isLiked,
      'color': color,
    };
  }

  factory MusicMetadata.fromJson(Map<String, dynamic> json) {
    return MusicMetadata(
      filePath: json['filePath'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String,
      year: json['year'] as String,
      playCount: json['playCount'] as int? ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      color: json['color'] as int?,
    );
  }
}
