import 'package:latlong2/latlong.dart';

/// Provider mapping item attached to a canonical Place.
class PlaceProviderMappingItem {
  final int? mappingId;
  final String provider;
  final String providerPlaceId;
  final String? providerType;
  final String? metadataJson;

  const PlaceProviderMappingItem({
    this.mappingId,
    required this.provider,
    required this.providerPlaceId,
    this.providerType,
    this.metadataJson,
  });

  factory PlaceProviderMappingItem.fromJson(Map<String, dynamic> json) {
    return PlaceProviderMappingItem(
      mappingId: (json['mappingId'] as num?)?.toInt(),
      provider: json['provider'] as String? ?? '',
      providerPlaceId: json['providerPlaceId'] as String? ?? '',
      providerType: json['providerType'] as String?,
      metadataJson: json['metadataJson'] as String?,
    );
  }
}

/// Canonical Place model representation on Flutter Web.
class PlaceModel {
  final int placeId;
  final String name;
  final String? normalizedName;
  final String address;
  final String? description;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  final String category; // ATTRACTION, RESTAURANT, CAFE, HOTEL, ENTERTAINMENT, SHOPPING, OTHER
  final String status; // ACTIVE, HIDDEN
  final List<PlaceProviderMappingItem> providerMappings;

  int get id => placeId;

  const PlaceModel({
    required this.placeId,
    required this.name,
    this.normalizedName,
    required this.address,
    this.description,
    this.imageUrl,
    this.latitude,
    this.longitude,
    required this.category,
    required this.status,
    this.providerMappings = const [],
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';
  bool get isHidden => status.toUpperCase() == 'HIDDEN';

  bool get hasCoordinates => latitude != null && longitude != null;

  LatLng? get coordinate =>
      hasCoordinates ? LatLng(latitude!, longitude!) : null;

  String get formattedCoordinates {
    if (!hasCoordinates) return 'Chưa có tọa độ';
    return '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}';
  }

  String get categoryDisplay {
    switch (category.toUpperCase()) {
      case 'ATTRACTION':
        return 'Điểm tham quan';
      case 'RESTAURANT':
        return 'Nhà hàng';
      case 'CAFE':
        return 'Quán cà phê';
      case 'HOTEL':
        return 'Khách sạn / Lưu trú';
      case 'ENTERTAINMENT':
        return 'Giải trí';
      case 'SHOPPING':
        return 'Mua sắm';
      case 'OTHER':
      default:
        return 'Khác';
    }
  }

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    List<PlaceProviderMappingItem> mappings = [];
    if (json['providerMappings'] is List) {
      mappings = (json['providerMappings'] as List)
          .map((m) => PlaceProviderMappingItem.fromJson(m as Map<String, dynamic>))
          .toList();
    }

    return PlaceModel(
      placeId: (json['placeId'] as num).toInt(),
      name: json['name'] as String? ?? '',
      normalizedName: json['normalizedName'] as String?,
      address: json['address'] as String? ?? '',
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      category: json['category'] as String? ?? 'ATTRACTION',
      status: json['status'] as String? ?? 'ACTIVE',
      providerMappings: mappings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'placeId': placeId,
      'name': name,
      if (normalizedName != null) 'normalizedName': normalizedName,
      'address': address,
      if (description != null) 'description': description,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'category': category,
      'status': status,
    };
  }

  PlaceModel copyWith({
    int? placeId,
    String? name,
    String? normalizedName,
    String? address,
    String? description,
    String? imageUrl,
    double? latitude,
    double? longitude,
    String? category,
    String? status,
    List<PlaceProviderMappingItem>? providerMappings,
  }) {
    return PlaceModel(
      placeId: placeId ?? this.placeId,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      address: address ?? this.address,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      status: status ?? this.status,
      providerMappings: providerMappings ?? this.providerMappings,
    );
  }
}

/// Request DTO for creating a new canonical Place.
class CreatePlaceRequest {
  final String name;
  final String address;
  final String? description;
  final String? imageUrl;
  final double latitude;
  final double longitude;
  final String category;

  const CreatePlaceRequest({
    required this.name,
    required this.address,
    this.description,
    this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.category,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'address': address.trim(),
      if (description != null && description!.trim().isNotEmpty)
        'description': description!.trim(),
      if (imageUrl != null && imageUrl!.trim().isNotEmpty)
        'imageUrl': imageUrl!.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
    };
  }
}

/// Request DTO for updating an existing canonical Place.
class UpdatePlaceRequest {
  final String name;
  final String address;
  final String? description;
  final String? imageUrl;
  final double latitude;
  final double longitude;
  final String category;
  final String status;

  const UpdatePlaceRequest({
    required this.name,
    required this.address,
    this.description,
    this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'address': address.trim(),
      if (description != null && description!.trim().isNotEmpty)
        'description': description!.trim(),
      if (imageUrl != null && imageUrl!.trim().isNotEmpty)
        'imageUrl': imageUrl!.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'status': status,
    };
  }
}

