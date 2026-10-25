import 'dart:math';
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
  final Random _random = Random();

  late Future<List<Channel>> _channelsFuture;
  List<String> _favoriteNames = [];
  String _searchQuery = '';
  String _selectedCountry = 'All';
  String _selectedCategory = 'All';
  int _featuredSeed = 0;

  final TextEditingController _searchController = TextEditingController();
  final Set<String> _unavailableStreamUrls = {};

  static const List<Map<String, String>> _regions = [
    {'id': 'All', 'flag': '🌏', 'label': 'All Asia'},
    {'id': 'Japan', 'flag': '🇯🇵', 'label': 'Japan'},
    {'id': 'South Korea', 'flag': '🇰🇷', 'label': 'Korea'},
    {'id': 'China', 'flag': '🇨🇳', 'label': 'China'},
    {'id': 'Favorites', 'flag': '❤️', 'label': 'Favorites'},
  ];

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

  void _markAsUnavailable(String streamUrl) {
    if (!_unavailableStreamUrls.contains(streamUrl)) {
      setState(() {
        _unavailableStreamUrls.add(streamUrl);
      });
    }
  }

  void _openPlayer(List<Channel> playlist, Channel target) {
    final idx = playlist.indexWhere((c) => c.streamUrl == target.streamUrl);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          channel: target,
          channels: playlist,
          initialIndex: idx >= 0 ? idx : 0,
          onChannelError: _markAsUnavailable,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0B0E),
      body: FutureBuilder<List<Channel>>(
        future: _channelsFuture,
        builder: (context, snapshot) {
          final allLoaded = snapshot.data ?? const <Channel>[];

          return Column(
            children: [
              // 1. TOP SMART-TV NAVIGATION BAR (Compact 74px height for 1360x768 TV)
              _buildTopNavBar(allLoaded),

              // 2. MAIN BODY
              Expanded(
                child: _buildBody(snapshot),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopNavBar(List<Channel> allChannels) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1117),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Brand Logo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE50914),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE50914).withValues(alpha: 0.45),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(Icons.live_tv_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                  children: [
                    TextSpan(text: 'STREAM', style: TextStyle(color: Color(0xFFE50914))),
                    TextSpan(text: 'EAST', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Text(
                  'TV',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 24),

          // Region / Favorites Navigation Pills
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _regions.map((region) {
                  final id = region['id']!;
                  final flag = region['flag']!;
                  final label = region['label']!;
                  final isSelected = _selectedCountry == id;

                  int count = 0;
                  if (allChannels.isNotEmpty) {
                    if (id == 'All') {
                      count = allChannels.length;
                    } else if (id == 'Favorites') {
                      count = allChannels.where((c) => _favoriteNames.contains(c.name)).length;
                    } else {
                      count = allChannels.where((c) => c.country == id).length;
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() {
                            _selectedCountry = id;
                            _selectedCategory = 'All';
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFE50914)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFF4D58)
                                  : Colors.white.withValues(alpha: 0.08),
                              width: 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFE50914).withValues(alpha: 0.4),
                                      blurRadius: 12,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(flag, style: const TextStyle(fontSize: 17)),
                              const SizedBox(width: 7),
                              Text(
                                label,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white70,
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                ),
                              ),
                              if (count > 0) ...[
                                const SizedBox(width: 7),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.black.withValues(alpha: 0.28)
                                        : Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white60,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Search Box (TV-sized)
          SizedBox(
            width: 240,
            height: 44,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search channels...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 15),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.white70, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1A1D26),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE50914), width: 1.8),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Refresh Button
          IconButton.filledTonal(
            tooltip: 'Reload Playlists',
            onPressed: () {
              setState(() {
                _channelsFuture = _channelService.fetchChannels();
                _unavailableStreamUrls.clear();
              });
              _loadFavorites();
            },
            icon: const Icon(Icons.refresh_rounded, size: 22),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              foregroundColor: Colors.white,
              minimumSize: const Size(44, 44),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AsyncSnapshot<List<Channel>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                color: Color(0xFFE50914),
                strokeWidth: 4,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Loading Live Asian TV Guide...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Japan • South Korea • China',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      );
    } else if (snapshot.hasError) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF14161E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, color: Color(0xFFE50914), size: 64),
              const SizedBox(height: 16),
              const Text(
                'Unable to Reach Channel Guide',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Check your network connection and try again.',
                style: TextStyle(color: Colors.white60, fontSize: 16),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE50914),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                ),
                onPressed: () {
                  setState(() {
                    _channelsFuture = _channelService.fetchChannels();
                  });
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry Connection', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return const Center(
        child: Text('No channels found.', style: TextStyle(fontSize: 20, color: Colors.white70)),
      );
    }

    final allChannels = snapshot.data!;

    // 1. Filter by Region / Favorites
    final regionChannels = allChannels.where((c) {
      if (_selectedCountry == 'All') return true;
      if (_selectedCountry == 'Favorites') return _favoriteNames.contains(c.name);
      return c.country == _selectedCountry;
    }).toList();

    // Collect available categories in this region
    final Set<String> availableCategoriesSet = {
      for (final c in regionChannels) c.category,
    };
    final List<String> categoryChips = [
      'All',
      ...(availableCategoriesSet.toList()..sort()),
    ];

    // 2. Filter by Category & Search Query
    final filteredChannels = regionChannels.where((c) {
      if (_selectedCategory != 'All' && c.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      return c.name.toLowerCase().contains(_searchQuery) ||
          c.category.toLowerCase().contains(_searchQuery) ||
          c.country.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filteredChannels.isEmpty) {
      return Column(
        children: [
          _buildCategoryChipBar(categoryChips),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _selectedCountry == 'Favorites' ? Icons.favorite_border_rounded : Icons.search_off_rounded,
                    color: Colors.white30,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedCountry == 'Favorites'
                        ? 'No favorite channels saved yet.'
                        : 'No channels match your current filter.',
                    style: const TextStyle(color: Colors.white70, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedCountry == 'Favorites'
                        ? 'Click the heart icon on any channel card to pin it here.'
                        : 'Try selecting another category or clearing the search bar.',
                    style: const TextStyle(color: Colors.white38, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Split channels into working and unavailable
    final List<Channel> workingChannels = [];
    final List<Channel> unavailableChannels = [];

    for (final channel in filteredChannels) {
      if (_unavailableStreamUrls.contains(channel.streamUrl)) {
        unavailableChannels.add(channel);
      } else {
        workingChannels.add(channel);
      }
    }

    final Map<String, List<Channel>> grouped = {};
    for (final channel in workingChannels) {
      grouped.putIfAbsent(channel.category, () => []).add(channel);
    }
    final sortedCategories = grouped.keys.toList()..sort();

    final favoriteChannels = workingChannels
        .where((c) => _favoriteNames.contains(c.name))
        .toList();

    // Pick a Featured Channel for the Hero Spotlight
    final spotlightPool = workingChannels.where((c) => !c.isGeoBlocked && c.logoUrl.isNotEmpty).toList();
    final Channel? featuredChannel = spotlightPool.isNotEmpty
        ? spotlightPool[_featuredSeed % spotlightPool.length]
        : (workingChannels.isNotEmpty ? workingChannels[_featuredSeed % workingChannels.length] : null);

    final bool showHero = _searchQuery.isEmpty && featuredChannel != null;
    final bool showFavoritesRow = _selectedCountry != 'Favorites' &&
        _selectedCategory == 'All' &&
        favoriteChannels.isNotEmpty;

    return Column(
      children: [
        // Category Quick-Jump Bar
        _buildCategoryChipBar(categoryChips),

        // Main Scrollable TV Guide
        Expanded(
          child: RefreshIndicator(
            color: const Color(0xFFE50914),
            onRefresh: () async {
              setState(() {
                _channelsFuture = _channelService.fetchChannels();
                _unavailableStreamUrls.clear();
              });
              await _loadFavorites();
            },
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 36),
              itemCount: (showHero ? 1 : 0) +
                  (showFavoritesRow ? 1 : 0) +
                  sortedCategories.length +
                  (unavailableChannels.isNotEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                int adjustedIndex = index;

                // 1. Hero Spotlight Banner
                if (showHero) {
                  if (adjustedIndex == 0) {
                    return _buildHeroSpotlight(featuredChannel, workingChannels);
                  }
                  adjustedIndex--;
                }

                // 2. Pinned Favorites Row
                if (showFavoritesRow) {
                  if (adjustedIndex == 0) {
                    return _TvCategoryRow(
                      key: PageStorageKey('fav_$_selectedCountry'),
                      categoryName: '❤️ Your Pinned Favorites',
                      channels: favoriteChannels,
                      allWorkingChannels: workingChannels,
                      favoriteNames: _favoriteNames,
                      onSelectChannel: (ch) => _openPlayer(workingChannels, ch),
                      onToggleFavorite: _toggleFavorite,
                    );
                  }
                  adjustedIndex--;
                }

                // 3. Category Rows
                if (adjustedIndex < sortedCategories.length) {
                  final category = sortedCategories[adjustedIndex];
                  final rowChannels = grouped[category]!;
                  return _TvCategoryRow(
                    key: PageStorageKey('${_selectedCountry}_${_selectedCategory}_$category'),
                    categoryName: category,
                    channels: rowChannels,
                    allWorkingChannels: workingChannels,
                    favoriteNames: _favoriteNames,
                    onSelectChannel: (ch) => _openPlayer(workingChannels, ch),
                    onToggleFavorite: _toggleFavorite,
                  );
                }
                adjustedIndex -= sortedCategories.length;

                // 4. Unavailable Section
                if (unavailableChannels.isNotEmpty && adjustedIndex == 0) {
                  return _TvCategoryRow(
                    key: PageStorageKey('unavail_$_selectedCountry'),
                    categoryName: 'Currently Offline Streams',
                    channels: unavailableChannels,
                    allWorkingChannels: unavailableChannels,
                    favoriteNames: _favoriteNames,
                    isUnavailable: true,
                    onSelectChannel: (ch) => _openPlayer(unavailableChannels, ch),
                    onToggleFavorite: _toggleFavorite,
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChipBar(List<String> categories) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0E14),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final cat = categories[idx];
          final isSelected = _selectedCategory == cat;
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              setState(() {
                _selectedCategory = cat;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white12,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                cat == 'All' ? 'All Categories' : cat,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroSpotlight(Channel featured, List<Channel> workingChannels) {
    final isFav = _favoriteNames.contains(featured.name);

    return Container(
      height: 215,
      margin: const EdgeInsets.fromLTRB(24, 14, 24, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A0C14),
            Color(0xFF141824),
            Color(0xFF0E1017),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative ambient glow on the right
          Positioned(
            right: -40,
            top: -40,
            bottom: -40,
            width: 380,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFE50914).withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            child: Row(
              children: [
                // Left Info Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Badges Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE50914),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, color: Colors.white, size: 8),
                                SizedBox(width: 6),
                                Text(
                                  'FEATURED LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${featured.countryFlag} ${featured.country}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              featured.category,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (featured.quality != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00C853).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                featured.quality!,
                                style: const TextStyle(
                                  color: Color(0xFF69F0AE),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Channel Title
                      Text(
                        featured.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Action Buttons
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: () => _openPlayer(workingChannels, featured),
                            icon: const Icon(Icons.play_arrow_rounded, size: 28),
                            label: const Text(
                              'Watch Live',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFE50914),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () => _toggleFavorite(featured.name),
                            icon: Icon(
                              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: isFav ? const Color(0xFFE50914) : Colors.white,
                              size: 22,
                            ),
                            label: Text(
                              isFav ? 'Pinned' : 'Favorite',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24, width: 1.5),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton.filledTonal(
                            tooltip: 'Next Spotlight Channel',
                            onPressed: () {
                              setState(() {
                                _featuredSeed = _random.nextInt(100000);
                              });
                            },
                            icon: const Icon(Icons.shuffle_rounded, size: 22),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.08),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(48, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 24),

                // Right Featured Channel Logo Showcase
                GestureDetector(
                  onTap: () => _openPlayer(workingChannels, featured),
                  child: Container(
                    width: 240,
                    height: 155,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1E29),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: featured.logoUrl.isNotEmpty
                        ? Image.network(
                            featured.logoUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.live_tv_rounded, color: Colors.white54, size: 56),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.live_tv_rounded, color: Colors.white54, size: 56),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TvCategoryRow extends StatefulWidget {
  final String categoryName;
  final List<Channel> channels;
  final List<Channel> allWorkingChannels;
  final List<String> favoriteNames;
  final bool isUnavailable;
  final ValueChanged<Channel> onSelectChannel;
  final ValueChanged<String> onToggleFavorite;

  const _TvCategoryRow({
    super.key,
    required this.categoryName,
    required this.channels,
    required this.allWorkingChannels,
    required this.favoriteNames,
    required this.onSelectChannel,
    required this.onToggleFavorite,
    this.isUnavailable = false,
  });

  @override
  State<_TvCategoryRow> createState() => _TvCategoryRowState();
}

class _TvCategoryRowState extends State<_TvCategoryRow> {
  final ScrollController _scrollController = ScrollController();

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row Header + Left/Right Couch Scroll Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 6.0),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    color: widget.isUnavailable ? Colors.white24 : const Color(0xFFE50914),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.categoryName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: widget.isUnavailable ? Colors.white38 : Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${widget.channels.length}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                ),
                const Spacer(),
                if (widget.channels.length > 4) ...[
                  IconButton(
                    tooltip: 'Scroll Left',
                    onPressed: () => _scrollBy(-760),
                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70, size: 28),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      minimumSize: const Size(38, 38),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Scroll Right',
                    onPressed: () => _scrollBy(760),
                    icon: const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 28),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      minimumSize: const Size(38, 38),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Horizontal Widescreen TV Cards
          SizedBox(
            height: 174,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 6.0),
              itemCount: widget.channels.length,
              itemBuilder: (context, index) {
                final channel = widget.channels[index];
                final isFav = widget.favoriteNames.contains(channel.name);

                return _TvChannelCard(
                  channel: channel,
                  isFavorite: isFav,
                  isUnavailable: widget.isUnavailable,
                  onTap: () => widget.onSelectChannel(channel),
                  onToggleFavorite: () => widget.onToggleFavorite(channel.name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TvChannelCard extends StatefulWidget {
  final Channel channel;
  final bool isFavorite;
  final bool isUnavailable;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  const _TvChannelCard({
    required this.channel,
    required this.isFavorite,
    required this.isUnavailable,
    required this.onTap,
    required this.onToggleFavorite,
  });

  @override
  State<_TvChannelCard> createState() => _TvChannelCardState();
}

class _TvChannelCardState extends State<_TvChannelCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  bool get _active => _isHovered || _isFocused;

  @override
  Widget build(BuildContext context) {
    final ch = widget.channel;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7.0),
      child: FocusableActionDetector(
        onShowFocusHighlight: (focused) => setState(() => _isFocused = focused),
        onShowHoverHighlight: (hovered) => setState(() => _isHovered = hovered),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _active ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            child: Opacity(
              opacity: widget.isUnavailable ? 0.5 : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 248,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1E2230),
                      Color(0xFF131620),
                    ],
                  ),
                  border: Border.all(
                    color: _active
                        ? const Color(0xFFE50914)
                        : Colors.white.withValues(alpha: 0.09),
                    width: _active ? 2.2 : 1.0,
                  ),
                  boxShadow: _active
                      ? [
                          BoxShadow(
                            color: const Color(0xFFE50914).withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Center Channel Logo (above bottom title bar)
                      Positioned(
                        top: 28,
                        bottom: 48,
                        left: 22,
                        right: 22,
                        child: ch.logoUrl.isNotEmpty
                            ? Image.network(
                                ch.logoUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => _buildFallbackMonogram(ch),
                              )
                            : _buildFallbackMonogram(ch),
                      ),

                      // Top-left Country Flag + Code Pill
                      Positioned(
                        top: 8,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(ch.countryFlag, style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                ch.countryCode,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Top-right Quality Badge + Favorite Button
                      Positioned(
                        top: 6,
                        right: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (ch.quality != null)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Text(
                                  ch.quality!,
                                  style: const TextStyle(
                                    color: Color(0xFF69F0AE),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            if (!widget.isUnavailable)
                              GestureDetector(
                                onTap: widget.onToggleFavorite,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    widget.isFavorite
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: widget.isFavorite
                                        ? const Color(0xFFE50914)
                                        : Colors.white70,
                                    size: 18,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Bottom Title & Category Bar (Large 17px TV-readable text)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.95),
                                Colors.black.withValues(alpha: 0.78),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ch.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (_active) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: Color(0xFFE50914),
                                  size: 20,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackMonogram(Channel ch) {
    final initials = ch.name.isNotEmpty
        ? ch.name.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase()
        : 'TV';
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.tv_rounded, color: Colors.white38, size: 32),
          const SizedBox(width: 8),
          Text(
            initials,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
