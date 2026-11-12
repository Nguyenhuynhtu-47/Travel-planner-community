class AdminMediaAssetModel {
  final int mediaAssetId;
  final int uploadedByUserId;
  final String uploadedByUsername;
  final String cloudinaryPublicId;
  final String secureUrl;
  final String? mediaType;
  final String status; // UNATTACHED, ATTACHED, DELETING, DELETED
  final String? claimToken;
  final DateTime? lockedAt;
  final String? lockedBy;
  final int retryCount;
  final DateTime? nextRetryAt;
  final DateTime? deadLetteredAt;
  final String? lastError;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const AdminMediaAssetModel({
    required this.mediaAssetId,
    required this.uploadedByUserId,
    required this.uploadedByUsername,
    required this.cloudinaryPublicId,
    required this.secureUrl,
    this.mediaType,
    required this.status,
    this.claimToken,
    this.lockedAt,
    this.lockedBy,
    this.retryCount = 0,
    this.nextRetryAt,
    this.deadLetteredAt,
    this.lastError,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isDeadLettered => deadLetteredAt != null;

  factory AdminMediaAssetModel.fromJson(Map<String, dynamic> json) {
    return AdminMediaAssetModel(
      mediaAssetId: json['mediaAssetId'] is int
          ? json['mediaAssetId'] as int
          : int.tryParse('${json['mediaAssetId']}') ?? 0,
      uploadedByUserId: json['uploadedByUserId'] is int
          ? json['uploadedByUserId'] as int
          : int.tryParse('${json['uploadedByUserId']}') ?? 0,
      uploadedByUsername: json['uploadedByUsername']?.toString() ?? '',
      cloudinaryPublicId: json['cloudinaryPublicId']?.toString() ?? '',
      secureUrl: json['secureUrl']?.toString() ?? '',
      mediaType: json['mediaType']?.toString(),
      status: json['status']?.toString() ?? 'UNATTACHED',
      claimToken: json['claimToken']?.toString(),
      lockedAt: json['lockedAt'] != null
          ? DateTime.tryParse(json['lockedAt'].toString())
          : null,
      lockedBy: json['lockedBy']?.toString(),
      retryCount: json['retryCount'] is int
          ? json['retryCount'] as int
          : int.tryParse('${json['retryCount']}') ?? 0,
      nextRetryAt: json['nextRetryAt'] != null
          ? DateTime.tryParse(json['nextRetryAt'].toString())
          : null,
      deadLetteredAt: json['deadLetteredAt'] != null
          ? DateTime.tryParse(json['deadLetteredAt'].toString())
          : null,
      lastError: json['lastError']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'mediaAssetId': mediaAssetId,
    'uploadedByUserId': uploadedByUserId,
    'uploadedByUsername': uploadedByUsername,
    'cloudinaryPublicId': cloudinaryPublicId,
    'secureUrl': secureUrl,
    'mediaType': mediaType,
    'status': status,
    'claimToken': claimToken,
    'lockedAt': lockedAt?.toIso8601String(),
    'lockedBy': lockedBy,
    'retryCount': retryCount,
    'nextRetryAt': nextRetryAt?.toIso8601String(),
    'deadLetteredAt': deadLetteredAt?.toIso8601String(),
    'lastError': lastError,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };
}

