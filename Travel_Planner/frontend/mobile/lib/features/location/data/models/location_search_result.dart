class LocationSearchResult {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double? latitude;
  final double? longitude;
  final String? category;
  final String? type;
  final double? importance;
  final List<double>? boundingBox;
  final String? provider;
  final bool isLocalityFallback;

  const LocationSearchResult({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    this.latitude,
    this.longitude,
    this.category,
    this.type,
    this.importance,
    this.boundingBox,
    this.provider,
    this.isLocalityFallback = false,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  bool get isCityOrAdministrative {
    if (isLocalityFallback) return true;
    final t = (type ?? '').toLowerCase();
    final c = (category ?? '').toLowerCase();
    return t == 'city' ||
        t == 'town' ||
        t == 'village' ||
        t == 'administrative' ||
        t == 'boundary' ||
        t == 'state' ||
        t == 'province' ||
        t == 'historic' ||
        t == 'locality' ||
        c == 'locality' ||
        c == 'place' ||
        c == 'boundary';
  }

  factory LocationSearchResult.fromJson(Map<String, dynamic> json) {
    List<double>? parsedBoundingBox;
    final rawBox = json['boundingBox'] ?? json['boundingbox'];
    if (rawBox is List && rawBox.length == 4) {
      parsedBoundingBox = rawBox
          .map((e) => double.tryParse(e.toString()) ?? 0.0)
          .toList();
    }

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
      type: json['type']?.toString(),
      importance: json['importance'] != null
          ? (json['importance'] as num).toDouble()
          : null,
      boundingBox: parsedBoundingBox,
      provider: json['provider']?.toString(),
      isLocalityFallback: json['isLocalityFallback'] == true ||
          (json['category'] == 'locality' && json['type'] == 'locality'),
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
      if (type != null) 'type': type,
      if (importance != null) 'importance': importance,
      if (boundingBox != null) 'boundingBox': boundingBox,
      if (provider != null) 'provider': provider,
      if (isLocalityFallback) 'isLocalityFallback': isLocalityFallback,
    };
  }

  LocationSearchResult copyWith({
    String? placeId,
    String? name,
    String? formattedAddress,
    double? latitude,
    double? longitude,
    String? category,
    String? type,
    double? importance,
    List<double>? boundingBox,
    String? provider,
    bool? isLocalityFallback,
  }) {
    return LocationSearchResult(
      placeId: placeId ?? this.placeId,
      name: name ?? this.name,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      type: type ?? this.type,
      importance: importance ?? this.importance,
      boundingBox: boundingBox ?? this.boundingBox,
      provider: provider ?? this.provider,
      isLocalityFallback: isLocalityFallback ?? this.isLocalityFallback,
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
          provider == other.provider &&
          isLocalityFallback == other.isLocalityFallback;

  @override
  int get hashCode => Object.hash(
        placeId,
        name,
        formattedAddress,
        latitude,
        longitude,
        category,
        provider,
        isLocalityFallback,
      );

  @override
  String toString() {
    return 'LocationSearchResult(placeId: $placeId, name: $name, formattedAddress: $formattedAddress, latitude: $latitude, longitude: $longitude, category: $category, provider: $provider, isLocalityFallback: $isLocalityFallback)';
  }
}

