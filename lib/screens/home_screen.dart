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
  String _selectedCountry = 'All';
  final TextEditingController _searchController = TextEditingController();

  static const List<Map<String, String>> _countries = [
    {'id': 'All', 'label': '🌏 All Asia'},
    {'id': 'Japan', 'label': '🇯🇵 Japan'},
    {'id': 'South Korea', 'label': '🇰🇷 South Korea'},
    {'id': 'China', 'label': '🇨🇳 China'},
  ];

  // Dynamic set of stream URLs that have failed during this session
  final Set<String> _unavailableStreamUrls = {};

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

  // Callback to mark a specific stream URL as unavailable when it fails in the player
  void _markAsUnavailable(String streamUrl) {
    if (!_unavailableStreamUrls.contains(streamUrl)) {
      setState(() {
        _unavailableStreamUrls.add(streamUrl);
      });
    }
  }

  String _countryBadge(String country) {
    switch (country) {
      case 'Japan':
        return 'JP';
      case 'South Korea':
        return 'KR';
      case 'China':
        return 'CN';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'StreamEast',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
        backgroundColor: Colors.black,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh Channels',
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              setState(() {
                _channelsFuture = _channelService.fetchChannels();
                _unavailableStreamUrls.clear();
              });
              _loadFavorites();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search channels, categories, or countries...',
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
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  itemCount: _countries.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = _countries[index];
                    final id = item['id']!;
                    final label = item['label']!;
                    final isSelected = _selectedCountry == id;
                    return ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _selectedCountry = id;
                        });
                      },
                      selectedColor: Colors.deepPurpleAccent,
                      backgroundColor: Colors.grey[900],
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  },
                ),
              ),
            ],
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
                  Text('Loading Asian TV Channels (JP / KR / CN)...'),
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
                    'Failed to load channels.\nCheck your network connection.',
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

          // Filter based on country and search query
          final filteredChannels = allChannels.where((c) {
            final matchesCountry = _selectedCountry == 'All' || c.country == _selectedCountry;
            if (!matchesCountry) return false;
            if (_searchQuery.isEmpty) return true;
            return c.name.toLowerCase().contains(_searchQuery) ||
                c.category.toLowerCase().contains(_searchQuery) ||
                c.country.toLowerCase().contains(_searchQuery);
          }).toList();

          if (filteredChannels.isEmpty) {
            return const Center(child: Text('No channels match your filter.'));
          }

          // Split channels into "Working" and "Unavailable"
          final List<Channel> workingChannels = [];
          final List<Channel> unavailableChannels = [];

          for (var channel in filteredChannels) {
            if (_unavailableStreamUrls.contains(channel.streamUrl)) {
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
                _unavailableStreamUrls.clear(); // Clear failures on manual refresh
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
                  if (adjustedIndex == 0) {
                    return _HeroBanner(
                      totalCount: workingChannels.length,
                      selectedCountry: _selectedCountry,
                    );
                  }
                  adjustedIndex--;
                }

                // 2. Favorites
                if (favoriteChannels.isNotEmpty) {
                  if (adjustedIndex == 0) {
                    return _buildCategoryRow('Your Favorites', favoriteChannels);
                  }
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
                  return _buildCategoryRow(
                    'Currently Unavailable',
                    unavailableChannels,
                    isUnavailable: true,
                  );
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
      key: PageStorageKey('${_selectedCountry}_$categoryName'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Text(
                categoryName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isUnavailable ? Colors.white38 : Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${channels.length})',
                style: const TextStyle(fontSize: 14, color: Colors.white54),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: channels.length,
            itemBuilder: (context, index) {
              final channel = channels[index];
              final isFav = _favoriteNames.contains(channel.name);
              final badge = _countryBadge(channel.country);

              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlayerScreen(
                        channel: channel,
                        onError: () => _markAsUnavailable(channel.streamUrl),
                      ),
                    ),
                  );
                },
                child: Opacity(
                  opacity: isUnavailable ? 0.5 : 1.0,
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: channel.logoUrl.isNotEmpty
                                      ? Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Image.network(
                                            channel.logoUrl,
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error, stackTrace) =>
                                                const Center(child: Icon(Icons.tv, color: Colors.white54, size: 40)),
                                          ),
                                        )
                                      : const Center(child: Icon(Icons.tv, color: Colors.white54, size: 40)),
                                ),
                              ),
                              if (badge.isNotEmpty)
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      badge,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
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
                                        color: Colors.black.withValues(alpha: 0.6),
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
                          padding: const EdgeInsets.only(top: 8.0, left: 4.0, right: 4.0),
                          child: Text(
                            channel.name,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
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
  final int totalCount;
  final String selectedCountry;

  const _HeroBanner({
    required this.totalCount,
    required this.selectedCountry,
  });

  @override
  Widget build(BuildContext context) {
    final regionTitle = selectedCountry == 'All'
        ? 'Asian Live TV (JP • KR • CN)'
        : '$selectedCountry Live TV';

    return Container(
      height: 220,
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
            colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              regionTitle,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              '$totalCount channels available to stream live',
              style: const TextStyle(fontSize: 15, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
