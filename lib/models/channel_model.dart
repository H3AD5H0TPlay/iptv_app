class Channel {
  final String id;
  final String name;
  final String category;
  final String logoUrl;
  final String streamUrl;

  Channel({
    required this.id,
    required this.name,
    required this.category,
    required this.logoUrl,
    required this.streamUrl,
  });

  // Added a factory constructor for future JSON parsing from the internet
  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      logoUrl: json['logoUrl'] as String,
      streamUrl: json['streamUrl'] as String,
    );
  }
}
