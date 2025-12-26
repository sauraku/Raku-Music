import 'package:flutter/material.dart';
import '../../data/models/music_metadata.dart';
import '../../services/music_service.dart';
import '../../services/player_manager.dart';
import '../components/song_list_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MusicService _musicService = MusicService();
  final PlayerManager _playerManager = PlayerManager();
  List<MusicMetadata> _allSongs = [];
  List<MusicMetadata> _filteredSongs = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSongs();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.length >= 3) {
      setState(() {
        _filteredSongs = _allSongs.where((song) {
          final titleLower = song.title.toLowerCase();
          final artistLower = song.artist.toLowerCase();
          final albumLower = song.album.toLowerCase();
          final searchLower = query.toLowerCase();
          
          return titleLower.contains(searchLower) || 
                 artistLower.contains(searchLower) ||
                 albumLower.contains(searchLower);
        }).toList();
      });
    } else if (query.isEmpty) {
      setState(() {
        _filteredSongs = List.from(_allSongs);
      });
    }
    // If query length is 1 or 2, we don't update the list (keep previous state)
    // or we could show empty/full list. Usually showing full list until 3 chars is better UX.
    else {
       setState(() {
        _filteredSongs = List.from(_allSongs);
      });
    }
  }

  Future<void> _loadSongs() async {
    final songs = await _musicService.loadMetadata();
    if (mounted) {
      setState(() {
        _allSongs = songs;
        _filteredSongs = songs;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLike(MusicMetadata song) async {
    await _musicService.toggleLike(song);
    // Refresh the list to show updated state
    await _loadSongs();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredSongs = List.from(_allSongs);
      }
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
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                title: _isSearching
                    ? TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Search songs...',
                          border: InputBorder.none,
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 20,
                        ),
                      )
                    : Text(
                        'Library',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              actions: [
                IconButton(
                  icon: Icon(_isSearching ? Icons.close : Icons.search),
                  onPressed: _toggleSearch,
                ),
              ],
            ),
          ];
        },
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _filteredSongs.isEmpty && !_isSearching && _allSongs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.music_note, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'No music found',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text('Go to Settings to add music folders'),
                      ],
                    ),
                  )
                : SongListView(
                    songs: _filteredSongs,
                    onToggleLike: _toggleLike,
                    playerManager: _playerManager,
                  ),
      ),
    );
  }
}
