class Channel {
  final String id;
  final String name;
  final String category;
  final String logoUrl;
  final String streamUrl;
  final String country;
  final String? quality;
  final bool isGeoBlocked;
  final String? referrer;
  final String? userAgent;

  Channel({
    required this.id,
    required this.name,
    required this.category,
    required this.logoUrl,
    required this.streamUrl,
    this.country = 'Unknown',
    this.quality,
    this.isGeoBlocked = false,
    this.referrer,
    this.userAgent,
  });

  String get countryFlag {
    switch (country) {
      case 'Japan':
        return '🇯🇵';
      case 'South Korea':
        return '🇰🇷';
      case 'China':
        return '🇨🇳';
      default:
        return '🌏';
    }
  }

  String get countryCode {
    switch (country) {
      case 'Japan':
        return 'JP';
      case 'South Korea':
        return 'KR';
      case 'China':
        return 'CN';
      default:
        return 'TV';
    }
  }

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      logoUrl: json['logoUrl'] as String,
      streamUrl: json['streamUrl'] as String,
      country: (json['country'] as String?) ?? 'Unknown',
      quality: json['quality'] as String?,
      isGeoBlocked: (json['isGeoBlocked'] as bool?) ?? false,
      referrer: json['referrer'] as String?,
      userAgent: json['userAgent'] as String?,
    );
  }
}
