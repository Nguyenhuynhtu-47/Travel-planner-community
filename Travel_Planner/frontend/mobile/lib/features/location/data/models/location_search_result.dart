class LocationSearchResult {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double? latitude;
  final double? longitude;
  final String? category;
  final String? provider;

  const LocationSearchResult({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    this.latitude,
    this.longitude,
    this.category,
    this.provider,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  factory LocationSearchResult.fromJson(Map<String, dynamic> json) {
    return LocationSearchResult(
      placeId: (json['placeId'] ?? json['place_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      formattedAddress: (json['formattedAddress'] ??
              json['formatted_address'] ??
              json['display_name'] ??
              '')
          .toString(),
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : (json['lat'] != null
              ? double.tryParse(json['lat'].toString())
              : null),
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : (json['lon'] != null
              ? double.tryParse(json['lon'].toString())
              : (json['lng'] != null
                  ? double.tryParse(json['lng'].toString())
                  : null)),
      category: json['category']?.toString(),
      provider: json['provider']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'placeId': placeId,
      'name': name,
      'formattedAddress': formattedAddress,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (category != null) 'category': category,
      if (provider != null) 'provider': provider,
    };
  }

  LocationSearchResult copyWith({
    String? placeId,
    String? name,
    String? formattedAddress,
    double? latitude,
    double? longitude,
    String? category,
    String? provider,
  }) {
    return LocationSearchResult(
      placeId: placeId ?? this.placeId,
      name: name ?? this.name,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      provider: provider ?? this.provider,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationSearchResult &&
          runtimeType == other.runtimeType &&
          placeId == other.placeId &&
          name == other.name &&
          formattedAddress == other.formattedAddress &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          category == other.category &&
          provider == other.provider;

  @override
  int get hashCode => Object.hash(
        placeId,
        name,
        formattedAddress,
        latitude,
        longitude,
        category,
        provider,
      );

  @override
  String toString() {
    return 'LocationSearchResult(placeId: $placeId, name: $name, formattedAddress: $formattedAddress, latitude: $latitude, longitude: $longitude, category: $category, provider: $provider)';
  }
}

