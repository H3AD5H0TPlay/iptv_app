import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_app/models/channel_model.dart';
import 'package:iptv_app/services/channel_service.dart';

void main() {
  test('M3U parser extracts channel metadata, country, and VLC options', () {
    const sampleM3u = '''
#EXTM3U
#EXTINF:-1 tvg-id="NHK.jp" tvg-logo="https://example.com/logo.png" group-title="Culture;News",NHK World
#EXTVLCOPT:http-referrer=https://nhk.jp/
#EXTVLCOPT:http-user-agent=CustomAgent/1.0
https://example.com/live/nhk.m3u8
''';

    final channels = ChannelService.parseM3uString(
      sampleM3u,
      startId: 0,
      country: 'Japan',
    );

    expect(channels.length, 1);
    final Channel ch = channels.first;
    expect(ch.name, 'NHK World');
    expect(ch.category, 'Culture');
    expect(ch.country, 'Japan');
    expect(ch.logoUrl, 'https://example.com/logo.png');
    expect(ch.streamUrl, 'https://example.com/live/nhk.m3u8');
    expect(ch.referrer, 'https://nhk.jp/');
    expect(ch.userAgent, 'CustomAgent/1.0');
  });
}
