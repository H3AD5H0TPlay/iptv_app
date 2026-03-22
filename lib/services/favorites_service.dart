import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const String _key = 'favorite_channel_names';

  // We use the channel name as a unique identifier because the generated IDs 
  // from the service might change if the M3U list order changes.
  // In a real app, a more stable unique ID (like a URL or a specific station ID) would be better.
  
  Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  Future<void> toggleFavorite(String channelName) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favorites = prefs.getStringList(_key) ?? [];

    if (favorites.contains(channelName)) {
      favorites.remove(channelName);
    } else {
      favorites.add(channelName);
    }

    await prefs.setStringList(_key, favorites);
  }

  Future<bool> isFavorite(String channelName) async {
    final favorites = await getFavorites();
    return favorites.contains(channelName);
  }
}
