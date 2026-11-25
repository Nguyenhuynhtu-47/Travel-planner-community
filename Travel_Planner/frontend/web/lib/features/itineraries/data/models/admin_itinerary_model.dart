class AdminItineraryCreator {
  final int userId;
  final String username;
  final String handle;
  final String? fullName;
  final String? avatar;

  const AdminItineraryCreator({
    required this.userId,
    required this.username,
    required this.handle,
    this.fullName,
    this.avatar,
  });

  String get displayName =>
      (fullName != null && fullName!.trim().isNotEmpty) ? fullName! : username;

  factory AdminItineraryCreator.fromJson(Map<String, dynamic> json) {
    return AdminItineraryCreator(
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      username: json['username']?.toString() ?? '',
      handle: json['handle']?.toString() ?? '',
      fullName: json['fullName']?.toString(),
      avatar: json['avatar']?.toString(),
    );
  }
}

class AdminItineraryModel {
  final int itineraryId;
  final String title;
  final String? description;
  final String location;
  final String? coverImage;
  final int totalDays;
  final double budget;
  final String? theme;
  final String visibility;
  final String status;
  final int viewCount;
  final int favoriteCount;
  final int ratingCount;
  final int commentCount;
  final int reuseCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final AdminItineraryCreator? creator;

  const AdminItineraryModel({
    required this.itineraryId,
    required this.title,
    this.description,
    required this.location,
    this.coverImage,
    required this.totalDays,
    required this.budget,
    this.theme,
    required this.visibility,
    required this.status,
    required this.viewCount,
    required this.favoriteCount,
    required this.ratingCount,
    required this.commentCount,
    required this.reuseCount,
    this.createdAt,
    this.updatedAt,
    this.creator,
  });

  factory AdminItineraryModel.fromJson(Map<String, dynamic> json) {
    return AdminItineraryModel(
      itineraryId: (json['itineraryId'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      location: json['location']?.toString() ?? '',
      coverImage: json['coverImage']?.toString(),
      totalDays: (json['totalDays'] as num?)?.toInt() ?? 0,
      budget: (json['budget'] as num?)?.toDouble() ?? 0.0,
      theme: json['theme']?.toString(),
      visibility: (json['visibility']?.toString() ?? 'PUBLIC').toUpperCase(),
      status: (json['status']?.toString() ?? 'ACTIVE').toUpperCase(),
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      favoriteCount: (json['favoriteCount'] as num?)?.toInt() ?? 0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      reuseCount: (json['reuseCount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      creator: json['creator'] is Map
          ? AdminItineraryCreator.fromJson(
              Map<String, dynamic>.from(json['creator'] as Map))
          : null,
    );
  }
}

class AdminItineraryActivityModel {
  final int activityId;
  final String name;
  final String? description;
  final String? startTime;
  final String? endTime;
  final double? cost;
  final int displayOrder;
  final String? locationName;
  final String? locationAddress;

  const AdminItineraryActivityModel({
    required this.activityId,
    required this.name,
    this.description,
    this.startTime,
    this.endTime,
    this.cost,
    required this.displayOrder,
    this.locationName,
    this.locationAddress,
  });

  factory AdminItineraryActivityModel.fromJson(Map<String, dynamic> json) {
    return AdminItineraryActivityModel(
      activityId: (json['activityId'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      startTime: json['startTime']?.toString(),
      endTime: json['endTime']?.toString(),
      cost: (json['cost'] as num?)?.toDouble(),
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      locationName: json['locationName']?.toString() ??
          json['customLocationName']?.toString(),
      locationAddress: json['locationAddress']?.toString() ??
          json['customAddress']?.toString(),
    );
  }
}

class AdminItineraryDayModel {
  final int dayId;
  final int dayNumber;
  final String? title;
  final String? date;
  final List<AdminItineraryActivityModel> activities;

  const AdminItineraryDayModel({
    required this.dayId,
    required this.dayNumber,
    this.title,
    this.date,
    required this.activities,
  });

  factory AdminItineraryDayModel.fromJson(Map<String, dynamic> json) {
    final rawActivities = (json['activities'] is List)
        ? (json['activities'] as List)
            .map((e) => AdminItineraryActivityModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList()
        : <AdminItineraryActivityModel>[];

    return AdminItineraryDayModel(
      dayId: (json['dayId'] as num?)?.toInt() ?? 0,
      dayNumber: (json['dayNumber'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString(),
      date: json['date']?.toString(),
      activities: rawActivities,
    );
  }
}

class AdminItineraryDetailModel {
  final AdminItineraryModel itinerary;
  final List<AdminItineraryDayModel> days;
  final bool privateInspection;
  final int? inspectedReportId;

  const AdminItineraryDetailModel({
    required this.itinerary,
    required this.days,
    this.privateInspection = false,
    this.inspectedReportId,
  });

  factory AdminItineraryDetailModel.fromJson(Map<String, dynamic> json) {
    final rawDays = (json['days'] is List)
        ? (json['days'] as List)
            .map((e) => AdminItineraryDayModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList()
        : <AdminItineraryDayModel>[];

    return AdminItineraryDetailModel(
      itinerary: AdminItineraryModel.fromJson(json),
      days: rawDays,
      privateInspection: json['privateInspection'] == true,
      inspectedReportId: (json['inspectedReportId'] as num?)?.toInt(),
    );
  }
}
