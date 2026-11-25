class AdminUserModel {
  final int userId;
  final String username;
  final String handle;
  final String email;
  final String? fullName;
  final String? avatar;
  final String role;
  final String status;
  final bool emailVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AdminUserModel({
    required this.userId,
    required this.username,
    required this.handle,
    required this.email,
    this.fullName,
    this.avatar,
    required this.role,
    required this.status,
    required this.emailVerified,
    this.createdAt,
    this.updatedAt,
  });

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    return AdminUserModel(
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      username: json['username']?.toString() ?? '',
      handle: json['handle']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['fullName']?.toString(),
      avatar: json['avatar']?.toString(),
      role: (json['role']?.toString() ?? 'USER').toUpperCase(),
      status: (json['status']?.toString() ?? 'ACTIVE').toUpperCase(),
      emailVerified: json['emailVerified'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }
}

class AdminUserSessionModel {
  final String sessionId;
  final String deviceInfo;
  final String ipAddress;
  final String status;
  final DateTime? createdAt;
  final DateTime? lastActiveAt;
  final DateTime? expiresAt;

  const AdminUserSessionModel({
    required this.sessionId,
    required this.deviceInfo,
    required this.ipAddress,
    required this.status,
    this.createdAt,
    this.lastActiveAt,
    this.expiresAt,
  });

  factory AdminUserSessionModel.fromJson(Map<String, dynamic> json) {
    return AdminUserSessionModel(
      sessionId: json['sessionId']?.toString() ?? '',
      deviceInfo: json['deviceInfo']?.toString() ?? 'Thiết bị không xác định',
      ipAddress: json['ipAddress']?.toString() ?? '-',
      status: (json['status']?.toString() ?? 'ACTIVE').toUpperCase(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      lastActiveAt: json['lastActiveAt'] != null
          ? DateTime.tryParse(json['lastActiveAt'].toString())
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
    );
  }
}

class AdminUserDetailModel {
  final AdminUserModel user;
  final String? phone;
  final String? address;
  final String? bio;
  final int itineraryCount;
  final int postCount;
  final int activeSessionCount;
  final List<AdminUserSessionModel> sessions;

  const AdminUserDetailModel({
    required this.user,
    this.phone,
    this.address,
    this.bio,
    required this.itineraryCount,
    required this.postCount,
    required this.activeSessionCount,
    required this.sessions,
  });

  factory AdminUserDetailModel.fromJson(Map<String, dynamic> json) {
    final sessionsList = (json['sessions'] is List)
        ? (json['sessions'] as List)
            .map((e) => AdminUserSessionModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList()
        : <AdminUserSessionModel>[];

    return AdminUserDetailModel(
      user: AdminUserModel.fromJson(json),
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      bio: json['bio']?.toString(),
      itineraryCount: (json['itineraryCount'] as num?)?.toInt() ?? 0,
      postCount: (json['postCount'] as num?)?.toInt() ?? 0,
      activeSessionCount: (json['activeSessionCount'] as num?)?.toInt() ?? 0,
      sessions: sessionsList,
    );
  }
}
