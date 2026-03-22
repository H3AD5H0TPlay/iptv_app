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

  // New: Lightweight check to see if a stream is reachable
  Future<bool> isStreamReachable(String url) async {
    try {
      final response = await http.head(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 3));
      
      // 200 (OK), 302 (Redirect), 206 (Partial) are usually healthy
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (_) {
      return false;
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
        final String streamUrl = line;
        
        final logoMatch = RegExp(r'tvg-logo="([^"]*)"', caseSensitive: false).firstMatch(lastInfLine);
        String logoUrl = logoMatch?.group(1) ?? '';
        
        if (logoUrl.toLowerCase().endsWith('.svg') || !logoUrl.startsWith('http')) {
          logoUrl = '';
        }

        final groupMatch = RegExp(r'group-title="([^"]*)"', caseSensitive: false).firstMatch(lastInfLine);
        String category = groupMatch?.group(1) ?? currentCategory ?? 'General';
        if (category.isEmpty) category = 'General';

        final String name = lastInfLine.split(',').last.trim();

        channels.add(Channel(
          id: 'id_${params.startId + channels.length}',
          name: name,
          category: category,
          logoUrl: logoUrl,
          streamUrl: streamUrl,
        ));

        lastInfLine = null;
      }
    }
    return channels;
  }
}
