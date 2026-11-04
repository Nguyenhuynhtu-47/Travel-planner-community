class UpdateActivityRequest {
  final String name;
  final String? description;
  final int? destinationId;
  final String? startTime;
  final String? endTime;
  final double? cost;
  final String? customLocationName;
  final String? customAddress;
  final double? latitude;
  final double? longitude;
  final String? placeId;
  final String? locationProvider;

  const UpdateActivityRequest({
    required this.name,
    this.description,
    this.destinationId,
    this.startTime,
    this.endTime,
    this.cost,
    this.customLocationName,
    this.customAddress,
    this.latitude,
    this.longitude,
    this.placeId,
    this.locationProvider,
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
      'customLocationName':
          (customLocationName != null && customLocationName!.trim().isNotEmpty)
              ? customLocationName!.trim()
              : null,
      'customAddress':
          (customAddress != null && customAddress!.trim().isNotEmpty)
              ? customAddress!.trim()
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
    };
  }

  static String _ensureSeconds(String time) {
    if (RegExp(r'^\d{2}:\d{2}$').hasMatch(time)) {
      return '$time:00';
    }
    return time;
  }
}
