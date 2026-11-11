class PlaceSummary {
  final int placeId;
  final String name;
  final String? address;
  final String? description;
  final String? category;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final String? status;

  const PlaceSummary({
    required this.placeId,
    required this.name,
    this.address,
    this.description,
    this.category,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.status,
  });

  factory PlaceSummary.fromJson(Map<String, dynamic> json) {
    return PlaceSummary(
      placeId: json['placeId'] is num
          ? (json['placeId'] as num).toInt()
          : (int.tryParse(json['placeId']?.toString() ?? '') ?? 0),
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString(),
      description: json['description']?.toString(),
      category: json['category']?.toString(),
      latitude: json['latitude'] is num
          ? (json['latitude'] as num).toDouble()
          : num.tryParse(json['latitude']?.toString() ?? '')?.toDouble(),
      longitude: json['longitude'] is num
          ? (json['longitude'] as num).toDouble()
          : num.tryParse(json['longitude']?.toString() ?? '')?.toDouble(),
      imageUrl: json['imageUrl']?.toString(),
      status: json['status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'placeId': placeId,
      'name': name,
      if (address != null) 'address': address,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (status != null) 'status': status,
    };
  }
}

