class UpdateActivityRequest {
  final String name;
  final String? description;
  final int? destinationId;
  final String? startTime;
  final String? endTime;
  final double? cost;

  const UpdateActivityRequest({
    required this.name,
    this.description,
    this.destinationId,
    this.startTime,
    this.endTime,
    this.cost,
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
    };
  }

  static String _ensureSeconds(String time) {
    if (RegExp(r'^\d{2}:\d{2}$').hasMatch(time)) {
      return '$time:00';
    }
    return time;
  }
}
