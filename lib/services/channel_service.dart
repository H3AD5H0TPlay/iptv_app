import 'package:http/http.dart' as http;
import 'package:iptv_app/models/channel_model.dart';

class ChannelService {
  // A public M3U URL from iptv-org (Japanese channels as an example)
  static const String m3uUrl = 'https://iptv-org.github.io/iptv/countries/jp.m3u';

  Future<List<Channel>> fetchChannels() async {
    try {
      final response = await http.get(Uri.parse(m3uUrl));

      if (response.statusCode == 200) {
        return _parseM3u(response.body);
      } else {
        throw Exception('Failed to load M3U file: Status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching channels: $e');
    }
  }

  List<Channel> _parseM3u(String body) {
    final List<Channel> channels = [];
    final List<String> lines = body.split('\n');

    if (lines.isEmpty || !lines[0].contains('#EXTM3U')) {
      return [];
    }

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();

      if (line.startsWith('#EXTINF')) {
        // Extract Logo URL
        final logoMatch = RegExp(r'tvg-logo="([^"]*)"').firstMatch(line);
        final String logoUrl = logoMatch?.group(1) ?? '';

        // Extract Category/Group
        final groupMatch = RegExp(r'group-title="([^"]*)"').firstMatch(line);
        final String category = groupMatch?.group(1) ?? 'General';

        // Extract Channel Name (after the last comma)
        final String name = line.split(',').last.trim();

        // The stream URL is usually on the next non-empty line
        String streamUrl = '';
        for (int j = i + 1; j < lines.length; j++) {
          final String nextLine = lines[j].trim();
          if (nextLine.isNotEmpty && !nextLine.startsWith('#')) {
            streamUrl = nextLine;
            break;
          }
        }

        if (streamUrl.isNotEmpty) {
          channels.add(Channel(
            id: 'id_${channels.length}', // Generate a unique ID
            name: name,
            category: category,
            logoUrl: logoUrl,
            streamUrl: streamUrl,
          ));
        }
      }
    }

    return channels;
  }
}
