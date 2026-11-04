import 'package:latlong2/latlong.dart';

/// Catalog destination model representation on Flutter Web.
class Destination {
  final int destinationId;
  final String name;
  final String address;
  final String? description;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  final String status;

  int get id => destinationId;

  const Destination({
    required this.destinationId,
    required this.name,
    required this.address,
    this.description,
    this.imageUrl,
    this.latitude,
    this.longitude,
    required this.status,
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

  factory Destination.fromJson(Map<String, dynamic> json) {
    return Destination(
      destinationId: (json['destinationId'] as num).toInt(),
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'ACTIVE',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'destinationId': destinationId,
      'name': name,
      'address': address,
      if (description != null) 'description': description,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'status': status,
    };
  }

  Destination copyWith({
    int? destinationId,
    String? name,
    String? address,
    String? description,
    String? imageUrl,
    double? latitude,
    double? longitude,
    String? status,
  }) {
    return Destination(
      destinationId: destinationId ?? this.destinationId,
      name: name ?? this.name,
      address: address ?? this.address,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
    );
  }
}

/// Request DTO for creating a new destination.
class CreateDestinationRequest {
  final String name;
  final String address;
  final String? description;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  final String? status;

  const CreateDestinationRequest({
    required this.name,
    required this.address,
    this.description,
    this.imageUrl,
    this.latitude,
    this.longitude,
    this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'address': address.trim(),
      if (description != null && description!.trim().isNotEmpty)
        'description': description!.trim()
      else
        'description': null,
      if (imageUrl != null && imageUrl!.trim().isNotEmpty)
        'imageUrl': imageUrl!.trim()
      else
        'imageUrl': null,
      'latitude': latitude,
      'longitude': longitude,
      if (status != null) 'status': status,
    };
  }
}

/// Request DTO for updating an existing destination.
class UpdateDestinationRequest {
  final String name;
  final String address;
  final String? description;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  final String? status;

  const UpdateDestinationRequest({
    required this.name,
    required this.address,
    this.description,
    this.imageUrl,
    this.latitude,
    this.longitude,
    this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'address': address.trim(),
      if (description != null && description!.trim().isNotEmpty)
        'description': description!.trim()
      else
        'description': null,
      if (imageUrl != null && imageUrl!.trim().isNotEmpty)
        'imageUrl': imageUrl!.trim()
      else
        'imageUrl': null,
      'latitude': latitude,
      'longitude': longitude,
      if (status != null) 'status': status,
    };
  }
}
