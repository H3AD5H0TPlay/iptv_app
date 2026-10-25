class Channel {
  final String id;
  final String name;
  final String category;
  final String logoUrl;
  final String streamUrl;
  final String country;
  final String? referrer;
  final String? userAgent;

  Channel({
    required this.id,
    required this.name,
    required this.category,
    required this.logoUrl,
    required this.streamUrl,
    this.country = 'Unknown',
    this.referrer,
    this.userAgent,
  });

  // Added a factory constructor for future JSON parsing from the internet
  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      logoUrl: json['logoUrl'] as String,
      streamUrl: json['streamUrl'] as String,
      country: (json['country'] as String?) ?? 'Unknown',
      referrer: json['referrer'] as String?,
      userAgent: json['userAgent'] as String?,
    );
  }
}
