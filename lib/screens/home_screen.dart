import 'package:flutter/material.dart';
import 'package:iptv_app/models/channel_model.dart';
import 'package:iptv_app/screens/player_screen.dart';
import 'package:iptv_app/services/channel_service.dart';
import 'package:iptv_app/services/favorites_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ChannelService _channelService = ChannelService();
  final FavoritesService _favoritesService = FavoritesService();

  late Future<List<Channel>> _channelsFuture;
  List<String> _favoriteNames = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Dynamic set of channels that have failed during this session
  final Set<String> _unavailableChannelNames = {};

  @override
  void initState() {
    super.initState();
    _channelsFuture = _channelService.fetchChannels();
    _loadFavorites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final favorites = await _favoritesService.getFavorites();
    if (mounted) {
      setState(() {
        _favoriteNames = favorites;
      });
    }
  }

  Future<void> _toggleFavorite(String name) async {
    await _favoritesService.toggleFavorite(name);
    await _loadFavorites();
  }

  // Callback to mark a channel as unavailable when it fails in the player
  void _markAsUnavailable(String name) {
    if (!_unavailableChannelNames.contains(name)) {
      setState(() {
        _unavailableChannelNames.add(name);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searchQuery.isEmpty ? const Text('StreamEast') : null,
        backgroundColor: Colors.black,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search channels...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Channel>>(
        future: _channelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Loading Channels...'),
                ],
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 20),
                  const Text(
                    'Failed to load channels.\nCheck your WiFi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _channelsFuture = _channelService.fetchChannels();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No channels found.'));
          }

          final allChannels = snapshot.data!;

          // Filter based on search
          final filteredChannels = _searchQuery.isEmpty
              ? allChannels
              : allChannels.where((c) =>
                  c.name.toLowerCase().contains(_searchQuery) ||
                  c.category.toLowerCase().contains(_searchQuery)).toList();

          if (filteredChannels.isEmpty) {
            return const Center(child: Text('No channels match your search.'));
          }

          // Split channels into "Working" and "Unavailable"
          final List<Channel> workingChannels = [];
          final List<Channel> unavailableChannels = [];

          for (var channel in filteredChannels) {
            if (_unavailableChannelNames.contains(channel.name)) {
              unavailableChannels.add(channel);
            } else {
              workingChannels.add(channel);
            }
          }

          // Group working channels
          final Map<String, List<Channel>> grouped = {};
          for (var channel in workingChannels) {
            grouped.putIfAbsent(channel.category, () => []).add(channel);
          }
          final sortedCategories = grouped.keys.toList()..sort();

          final favoriteChannels = workingChannels
              .where((c) => _favoriteNames.contains(c.name))
              .toList();

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _channelsFuture = _channelService.fetchChannels();
                _unavailableChannelNames.clear(); // Clear failures on manual refresh
              });
              await _loadFavorites();
            },
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: sortedCategories.length + 
                        (_searchQuery.isEmpty ? 1 : 0) + 
                        (favoriteChannels.isNotEmpty ? 1 : 0) + 
                        (unavailableChannels.isNotEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                int adjustedIndex = index;

                // 1. Hero Banner
                if (_searchQuery.isEmpty) {
                  if (adjustedIndex == 0) return const _HeroBanner();
                  adjustedIndex--;
                }

                // 2. Favorites
                if (favoriteChannels.isNotEmpty) {
                  if (adjustedIndex == 0) return _buildCategoryRow('Your Favorites', favoriteChannels);
                  adjustedIndex--;
                }

                // 3. Normal Categories
                if (adjustedIndex < sortedCategories.length) {
                  final category = sortedCategories[adjustedIndex];
                  return _buildCategoryRow(category, grouped[category]!);
                }
                adjustedIndex -= sortedCategories.length;

                // 4. Currently Unavailable Section
                if (unavailableChannels.isNotEmpty && adjustedIndex == 0) {
                  return _buildCategoryRow('Currently Unavailable', unavailableChannels, isUnavailable: true);
                }

                return const SizedBox.shrink();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryRow(String categoryName, List<Channel> channels, {bool isUnavailable = false}) {
    return Column(
      key: PageStorageKey(categoryName),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            categoryName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isUnavailable ? Colors.white38 : Colors.white,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: channels.length,
            itemBuilder: (context, index) {
              final channel = channels[index];
              final isFav = _favoriteNames.contains(channel.name);

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlayerScreen(
                        channel: channel,
                        onError: () => _markAsUnavailable(channel.name),
                      ),
                    ),
                  );
                },
                child: Opacity(
                  opacity: isUnavailable ? 0.5 : 1.0,
                  child: Container(
                    width: 120,
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    channel.logoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Center(child: Icon(Icons.tv, color: Colors.white54, size: 40)),
                                  ),
                                ),
                              ),
                              if (!isUnavailable)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _toggleFavorite(channel.name),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isFav ? Icons.favorite : Icons.favorite_border,
                                        color: isFav ? Colors.red : Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                          child: Text(
                            channel.name,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1536440136628-849c177e76a1?q=80&w=2000&auto=format&fit=crop'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Featured Content', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('Watch the latest live streams now', style: TextStyle(fontSize: 16, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
