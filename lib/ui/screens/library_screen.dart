import 'package:flutter/material.dart';
import '../../data/models/music_metadata.dart';
import '../../services/music_service.dart';
import '../../services/player_manager.dart';
import '../components/song_list_view.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final MusicService _musicService = MusicService();
  final PlayerManager _playerManager = PlayerManager();

  // Data for playlists
  List<MusicMetadata> _topSongs = [];
  List<MusicMetadata> _likedSongs = [];
  bool _isLoading = true;

  // State for showing song list
  List<MusicMetadata>? _selectedPlaylistSongs;
  String? _selectedPlaylistTitle;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Reload data when the widget becomes visible again (e.g., switching tabs)
  @override
  void didUpdateWidget(LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only reload if we are on the main library view
    if (_selectedPlaylistSongs == null) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final allSongs = await _musicService.loadMetadata();
    
    final liked = allSongs.where((s) => s.isLiked).toList();
    
    final top = List<MusicMetadata>.from(allSongs);
    top.sort((a, b) => b.playCount.compareTo(a.playCount));
    final top10 = top.take(10).toList();

    if (mounted) {
      setState(() {
        _likedSongs = liked;
        _topSongs = top10;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLike(MusicMetadata song) async {
    await _musicService.toggleLike(song);
    // Refresh all data to ensure consistency across lists
    await _loadData();
    // Also update the currently viewed list if there is one
    if (_selectedPlaylistSongs != null) {
      setState(() {
        final index = _selectedPlaylistSongs!.indexWhere((s) => s.filePath == song.filePath);
        if (index != -1) {
          _selectedPlaylistSongs![index].isLiked = !_selectedPlaylistSongs![index].isLiked;
          // If viewing liked songs, remove it from the view
          if (_selectedPlaylistTitle == 'Liked Songs') {
            _selectedPlaylistSongs!.removeAt(index);
          }
        }
      });
    }
  }

  void _showPlaylist(String title, List<MusicMetadata> songs) {
    setState(() {
      _selectedPlaylistTitle = title;
      _selectedPlaylistSongs = songs;
    });
  }

  void _goBackToLibrary() {
    setState(() {
      _selectedPlaylistTitle = null;
      _selectedPlaylistSongs = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              expandedHeight: 120.0,
              floating: false,
              pinned: true,
              leading: _selectedPlaylistSongs != null
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _goBackToLibrary,
                    )
                  : null,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: _selectedPlaylistSongs != null
                    ? const EdgeInsets.only(left: 56, bottom: 16)
                    : const EdgeInsets.only(left: 16, bottom: 16),
                title: Text(
                  _selectedPlaylistTitle ?? 'My Library',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ];
        },
        body: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_selectedPlaylistSongs != null) {
      return SongListView(
        songs: _selectedPlaylistSongs!,
        onToggleLike: _toggleLike,
        playerManager: _playerManager,
      );
    } else {
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildPlaylistTile(
            context,
            title: 'Top 10 Played',
            icon: Icons.bar_chart,
            songs: _topSongs,
          ),
          _buildPlaylistTile(
            context,
            title: 'Liked Songs',
            icon: Icons.favorite,
            songs: _likedSongs,
          ),
        ],
      );
    }
  }

  Widget _buildPlaylistTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<MusicMetadata> songs,
  }) {
    return ListTile(
      leading: Icon(icon, size: 32),
      title: Text(title),
      subtitle: Text('${songs.length} songs'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showPlaylist(title, songs),
    );
  }
}
