class CreateActivityRequest {
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

  const CreateActivityRequest({
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
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      if (description != null && description!.trim().isNotEmpty)
        'description': description!.trim(),
      if (destinationId != null) 'destinationId': destinationId,
      if (startTime != null && startTime!.trim().isNotEmpty)
        'startTime': _ensureSeconds(startTime!.trim()),
      if (endTime != null && endTime!.trim().isNotEmpty)
        'endTime': _ensureSeconds(endTime!.trim()),
      if (cost != null) 'cost': cost,
      if ((locationName ?? customLocationName) != null &&
          (locationName ?? customLocationName)!.trim().isNotEmpty) ...{
        'locationName': (locationName ?? customLocationName)!.trim(),
        'customLocationName': (locationName ?? customLocationName)!.trim(),
      },
      if ((locationAddress ?? customAddress) != null &&
          (locationAddress ?? customAddress)!.trim().isNotEmpty) ...{
        'locationAddress': (locationAddress ?? customAddress)!.trim(),
        'customAddress': (locationAddress ?? customAddress)!.trim(),
      },
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (placeId != null && placeId!.trim().isNotEmpty)
        'placeId': placeId!.trim(),
      if (locationProvider != null && locationProvider!.trim().isNotEmpty)
        'locationProvider': locationProvider!.trim(),
      if (imageUrl != null && imageUrl!.trim().isNotEmpty)
        'imageUrl': imageUrl!.trim(),
    };
  }

  static String _ensureSeconds(String time) {
    if (RegExp(r'^\d{2}:\d{2}$').hasMatch(time)) {
      return '$time:00';
    }
    return time;
  }
}
