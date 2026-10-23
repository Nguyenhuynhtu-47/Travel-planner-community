class DestinationSummary {
  final int destinationId;
  final String name;
  final String? address;
  final String? category;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;

  const DestinationSummary({
    required this.destinationId,
    required this.name,
    this.address,
    this.category,
    this.latitude,
    this.longitude,
    this.imageUrl,
  });

  factory DestinationSummary.fromJson(Map<String, dynamic> json) {
    return DestinationSummary(
      destinationId: json['destinationId'] is num
          ? (json['destinationId'] as num).toInt()
          : 0,
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString(),
      category: json['category']?.toString(),
      latitude: json['latitude'] is num
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] is num
          ? (json['longitude'] as num).toDouble()
          : null,
      imageUrl: json['imageUrl']?.toString(),
    );
  }
}
