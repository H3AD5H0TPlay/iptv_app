import 'package:iptv_app/models/channel_model.dart';

final List<Channel> mockChannels = [
  // News Category
  Channel(
    id: 'news_01',
    name: 'Test Stream (Tears of Steel)',
    category: 'News',
    logoUrl: 'https://picsum.photos/seed/news1/200/200',
    streamUrl: 'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
  ),
  Channel(
    id: 'news_02',
    name: 'Tech Daily',
    category: 'News',
    logoUrl: 'https://picsum.photos/seed/news2/200/200',
    streamUrl: 'https://example.com/streams/news2.m3u8',
  ),
  Channel(
    id: 'news_03',
    name: 'Finance Today',
    category: 'News',
    logoUrl: 'https://picsum.photos/seed/news3/200/200',
    streamUrl: 'https://example.com/streams/news3.m3u8',
  ),
  
  // K-Pop Category
  Channel(
    id: 'kpop_01',
    name: 'K-Pop Central',
    category: 'K-Pop',
    logoUrl: 'https://picsum.photos/seed/kpop1/200/200',
    streamUrl: 'https://example.com/streams/kpop1.m3u8',
  ),
  Channel(
    id: 'kpop_02',
    name: 'Idol TV',
    category: 'K-Pop',
    logoUrl: 'https://picsum.photos/seed/kpop2/200/200',
    streamUrl: 'https://example.com/streams/kpop2.m3u8',
  ),
  Channel(
    id: 'kpop_03',
    name: 'Seoul Beats',
    category: 'K-Pop',
    logoUrl: 'https://picsum.photos/seed/kpop3/200/200',
    streamUrl: 'https://example.com/streams/kpop3.m3u8',
  ),

  // Movies Category
  Channel(
    id: 'movies_01',
    name: 'Cinema Classic',
    category: 'Movies',
    logoUrl: 'https://picsum.photos/seed/movies1/200/200',
    streamUrl: 'https://example.com/streams/movies1.m3u8',
  ),
  Channel(
    id: 'movies_02',
    name: 'Action Max',
    category: 'Movies',
    logoUrl: 'https://picsum.photos/seed/movies2/200/200',
    streamUrl: 'https://example.com/streams/movies2.m3u8',
  ),
  Channel(
    id: 'movies_03',
    name: 'Indie Film Hub',
    category: 'Movies',
    logoUrl: 'https://picsum.photos/seed/movies3/200/200',
    streamUrl: 'https://example.com/streams/movies3.m3u8',
  ),

  // Sports Category
  Channel(
    id: 'sports_01',
    name: 'Sports One',
    category: 'Sports',
    logoUrl: 'https://picsum.photos/seed/sports1/200/200',
    streamUrl: 'https://example.com/streams/sports1.m3u8',
  ),
  Channel(
    id: 'sports_02',
    name: 'Football Live',
    category: 'Sports',
    logoUrl: 'https://picsum.photos/seed/sports2/200/200',
    streamUrl: 'https://example.com/streams/sports2.m3u8',
  ),
  Channel(
    id: 'sports_03',
    name: 'Racing TV',
    category: 'Sports',
    logoUrl: 'https://picsum.photos/seed/sports3/200/200',
    streamUrl: 'https://example.com/streams/sports3.m3u8',
  ),
  
  // Extra mix
  Channel(
    id: 'doc_01',
    name: 'Planet Earth',
    category: 'Documentary',
    logoUrl: 'https://picsum.photos/seed/doc1/200/200',
    streamUrl: 'https://example.com/streams/doc1.m3u8',
  ),
];
