import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:iptv_app/models/channel_model.dart';

class _ParseParams {
  final String body;
  final int startId;
  final String country;
  _ParseParams(this.body, this.startId, this.country);
}

class _PlaylistSource {
  final String url;
  final String country;
  const _PlaylistSource(this.url, this.country);
}

class ChannelService {
  static const List<_PlaylistSource> _playlistSources = [
    // Japan (country + Japanese language streams)
    _PlaylistSource('https://iptv-org.github.io/iptv/countries/jp.m3u', 'Japan'),
    _PlaylistSource('https://iptv-org.github.io/iptv/languages/jpn.m3u', 'Japan'),
    // South Korea
    _PlaylistSource('https://iptv-org.github.io/iptv/countries/kr.m3u', 'South Korea'),
    // China (Mainland + HK + TW)
    _PlaylistSource('https://iptv-org.github.io/iptv/countries/cn.m3u', 'China'),
    _PlaylistSource('https://iptv-org.github.io/iptv/countries/hk.m3u', 'China'),
    _PlaylistSource('https://iptv-org.github.io/iptv/countries/tw.m3u', 'China'),
  ];

  Future<List<Channel>> fetchChannels() async {
    final responses = await Future.wait(
      _playlistSources.map((source) async {
        try {
          return await http
              .get(Uri.parse(source.url))
              .timeout(const Duration(seconds: 10));
        } catch (e) {
          debugPrint('Failed to fetch playlist ${source.url}: $e');
          return null;
        }
      }),
    );

    final List<Channel> allChannels = [];
    final Set<String> seenStreamUrls = {};

    for (int i = 0; i < responses.length; i++) {
      final response = responses[i];
      final source = _playlistSources[i];

      if (response != null && response.statusCode == 200) {
        final String decodedBody = utf8.decode(response.bodyBytes, allowMalformed: true);

        final List<Channel> parsed = await compute(
          _parseM3uIsolate,
          _ParseParams(decodedBody, allChannels.length, source.country),
        );

        for (final channel in parsed) {
          if (seenStreamUrls.add(channel.streamUrl)) {
            allChannels.add(channel);
          }
        }
      }
    }

    if (allChannels.isEmpty) {
      throw Exception('Failed to load any M3U playlists. Check your network connection.');
    }

    // Sort so non-geoblocked channels with logos appear first inside each category
    allChannels.sort((a, b) {
      if (a.isGeoBlocked != b.isGeoBlocked) {
        return a.isGeoBlocked ? 1 : -1;
      }
      final aHasLogo = a.logoUrl.isNotEmpty;
      final bHasLogo = b.logoUrl.isNotEmpty;
      if (aHasLogo != bHasLogo) {
        return aHasLogo ? -1 : 1;
      }
      return a.name.compareTo(b.name);
    });

    return allChannels;
  }

  @visibleForTesting
  static List<Channel> parseM3uString(String body, {int startId = 0, String country = 'Unknown'}) {
    return _parseM3uIsolate(_ParseParams(body, startId, country));
  }

  static List<Channel> _parseM3uIsolate(_ParseParams params) {
    final List<Channel> channels = [];
    final List<String> lines = const LineSplitter().convert(params.body);

    String? lastInfLine;
    String? currentCategory;
    String? vlcReferrer;
    String? vlcUserAgent;

    final qualityRegex = RegExp(r'\((\d{3,4}p|4K|UHD|HD|SD)\)', caseSensitive: false);
    final bracketNoiseRegex = RegExp(r'\[[^\]]*\]');

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        lastInfLine = line;
        vlcReferrer = null;
        vlcUserAgent = null;
      } else if (line.startsWith('#EXTGRP:')) {
        currentCategory = line.substring(8).trim();
      } else if (line.startsWith('#EXTVLCOPT:')) {
        final opt = line.substring(11).trim();
        if (opt.toLowerCase().startsWith('http-referrer=')) {
          vlcReferrer = opt.substring(14).trim();
        } else if (opt.toLowerCase().startsWith('http-user-agent=')) {
          vlcUserAgent = opt.substring(16).trim();
        }
      } else if (line.startsWith('http') && lastInfLine != null) {
        final String streamUrl = line;

        final logoMatch = RegExp(r'tvg-logo="([^"]*)"', caseSensitive: false).firstMatch(lastInfLine);
        String logoUrl = logoMatch?.group(1) ?? '';

        if (logoUrl.toLowerCase().endsWith('.svg') || !logoUrl.startsWith('http')) {
          logoUrl = '';
        }

        final groupMatch = RegExp(r'group-title="([^"]*)"', caseSensitive: false).firstMatch(lastInfLine);
        String rawCategory = groupMatch?.group(1) ?? currentCategory ?? 'General';
        if (rawCategory.isEmpty || rawCategory.toLowerCase() == 'undefined') {
          rawCategory = 'General';
        }
        final String category = rawCategory.split(';').first.trim();

        final refMatch = RegExp(r'http-referrer="([^"]*)"', caseSensitive: false).firstMatch(lastInfLine);
        final String? referrer = vlcReferrer ?? refMatch?.group(1);

        final uaMatch = RegExp(r'http-user-agent="([^"]*)"', caseSensitive: false).firstMatch(lastInfLine);
        final String? userAgent = vlcUserAgent ?? uaMatch?.group(1);

        final String rawName = lastInfLine.split(',').last.trim();
        final bool isGeoBlocked = rawName.toLowerCase().contains('geo-blocked');

        final qualityMatch = qualityRegex.firstMatch(rawName);
        String? quality = qualityMatch?.group(1)?.toUpperCase();
        if (quality == null && rawName.contains(' HD')) {
          quality = 'HD';
        }

        String cleanName = rawName
            .replaceAll(qualityRegex, '')
            .replaceAll(bracketNoiseRegex, '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (cleanName.isEmpty) {
          cleanName = rawName;
        }

        channels.add(Channel(
          id: 'id_${params.startId + channels.length}',
          name: cleanName,
          category: category,
          logoUrl: logoUrl,
          streamUrl: streamUrl,
          country: params.country,
          quality: quality,
          isGeoBlocked: isGeoBlocked,
          referrer: referrer,
          userAgent: userAgent,
        ));

        lastInfLine = null;
        vlcReferrer = null;
        vlcUserAgent = null;
      }
    }
    return channels;
  }
}
