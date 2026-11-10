class UpdateActivityRequest {
  final String name;
  final String? description;
  final int? destinationId;
  final String? startTime;
  final String? endTime;
  final double? cost;
  final String? locationName;
  final String? locationAddress;
  final String? customLocationName;
  final String? customAddress;
  final double? latitude;
  final double? longitude;
  final String? placeId;
  final String? locationProvider;
  final String? imageUrl;
  final bool? clearLocation;

  const UpdateActivityRequest({
    required this.name,
    this.description,
    this.destinationId,
    this.startTime,
    this.endTime,
    this.cost,
    this.locationName,
    this.locationAddress,
    this.customLocationName,
    this.customAddress,
    this.latitude,
    this.longitude,
    this.placeId,
    this.locationProvider,
    this.imageUrl,
    this.clearLocation,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'description': (description != null && description!.trim().isNotEmpty)
          ? description!.trim()
          : null,
      'destinationId': destinationId,
      'startTime': (startTime != null && startTime!.trim().isNotEmpty)
          ? _ensureSeconds(startTime!.trim())
          : null,
      'endTime': (endTime != null && endTime!.trim().isNotEmpty)
          ? _ensureSeconds(endTime!.trim())
          : null,
      'cost': cost ?? 0.0,
      'locationName':
          (locationName != null && locationName!.trim().isNotEmpty)
              ? locationName!.trim()
              : (customLocationName != null && customLocationName!.trim().isNotEmpty)
                  ? customLocationName!.trim()
                  : null,
      'locationAddress':
          (locationAddress != null && locationAddress!.trim().isNotEmpty)
              ? locationAddress!.trim()
              : (customAddress != null && customAddress!.trim().isNotEmpty)
                  ? customAddress!.trim()
                  : null,
      'customLocationName':
          (customLocationName != null && customLocationName!.trim().isNotEmpty)
              ? customLocationName!.trim()
              : (locationName != null && locationName!.trim().isNotEmpty)
                  ? locationName!.trim()
                  : null,
      'customAddress':
          (customAddress != null && customAddress!.trim().isNotEmpty)
              ? customAddress!.trim()
              : (locationAddress != null && locationAddress!.trim().isNotEmpty)
                  ? locationAddress!.trim()
                  : null,
      'latitude': latitude,
      'longitude': longitude,
      'placeId': (placeId != null && placeId!.trim().isNotEmpty)
          ? placeId!.trim()
          : null,
      'locationProvider':
          (locationProvider != null && locationProvider!.trim().isNotEmpty)
          ? locationProvider!.trim()
          : null,
      'imageUrl': imageUrl?.trim(),
      if (clearLocation != null) 'clearLocation': clearLocation,
    };
  }

  static String _ensureSeconds(String time) {
    if (RegExp(r'^\d{2}:\d{2}$').hasMatch(time)) {
      return '$time:00';
    }
    return time;
  }
}
