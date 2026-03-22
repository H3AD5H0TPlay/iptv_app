import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:iptv_app/models/channel_model.dart';

class _ParseParams {
  final String body;
  final int startId;
  _ParseParams(this.body, this.startId);
}

class ChannelService {
  static const List<String> m3uUrls = [
    'https://iptv-org.github.io/iptv/countries/jp.m3u',
    'https://iptv-org.github.io/iptv/countries/kr.m3u',
  ];

  Future<List<Channel>> fetchChannels() async {
    try {
      final responses = await Future.wait(
        m3uUrls.map((url) => http.get(Uri.parse(url))),
      );

      final List<Channel> allChannels = [];
      
      for (var response in responses) {
        if (response.statusCode == 200) {
          // FIX: Use utf8.decode on bodyBytes to handle Japanese/Korean characters correctly
          final String decodedBody = utf8.decode(response.bodyBytes, allowMalformed: true);
          
          final List<Channel> parsed = await compute(
            _parseM3uIsolate, 
            _ParseParams(decodedBody, allChannels.length)
          );
          allChannels.addAll(parsed);
        }
      }

      if (allChannels.isEmpty && responses.any((r) => r.statusCode != 200)) {
         throw Exception('Failed to load M3U files');
      }

      return allChannels;
    } catch (e) {
      throw Exception('Error fetching channels: $e');
    }
  }

  static List<Channel> _parseM3uIsolate(_ParseParams params) {
    final List<Channel> channels = [];
    final List<String> lines = const LineSplitter().convert(params.body);

    String? lastInfLine;
    String? currentCategory;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        lastInfLine = line;
      } else if (line.startsWith('#EXTGRP:')) {
        currentCategory = line.substring(8).trim();
      } else if (line.startsWith('http') && lastInfLine != null) {
        // We found a URL and we have a preceding INF line
        final String streamUrl = line;
        
        // Extract Logo
        final logoMatch = RegExp(r'tvg-logo="([^"]*)"', caseSensitive: false).firstMatch(lastInfLine);
        String logoUrl = logoMatch?.group(1) ?? '';
        
        // Defensive check: Native Android decoder fails on SVG or empty/malformed URLs
        if (logoUrl.toLowerCase().endsWith('.svg') || !logoUrl.startsWith('http')) {
          logoUrl = '';
        }

        // Extract Category
        final groupMatch = RegExp(r'group-title="([^"]*)"', caseSensitive: false).firstMatch(lastInfLine);
        String category = groupMatch?.group(1) ?? currentCategory ?? 'General';
        if (category.isEmpty) category = 'General';

        // Extract Name
        final String name = lastInfLine.split(',').last.trim();

        channels.add(Channel(
          id: 'id_${params.startId + channels.length}',
          name: name,
          category: category,
          logoUrl: logoUrl,
          streamUrl: streamUrl,
        ));

        // Reset for next entry
        lastInfLine = null;
        // Note: currentCategory stays until updated by another #EXTGRP
      }
    }
    return channels;
  }
}
