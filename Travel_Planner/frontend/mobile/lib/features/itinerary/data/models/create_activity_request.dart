class CreateActivityRequest {
  final String name;
  final String? description;
  final int? destinationId;
  final String? startTime;
  final String? endTime;
  final double? cost;

  const CreateActivityRequest({
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
      if (description != null && description!.trim().isNotEmpty)
        'description': description!.trim(),
      if (destinationId != null) 'destinationId': destinationId,
      if (startTime != null && startTime!.trim().isNotEmpty)
        'startTime': _ensureSeconds(startTime!.trim()),
      if (endTime != null && endTime!.trim().isNotEmpty)
        'endTime': _ensureSeconds(endTime!.trim()),
      if (cost != null) 'cost': cost,
    };
  }

  static String _ensureSeconds(String time) {
    if (RegExp(r'^\d{2}:\d{2}$').hasMatch(time)) {
      return '$time:00';
    }
    return time;
  }
}
