import 'admin_post_model.dart';

class AdminPostReportModel {
  final int reportId;
  final int postId;
  final AdminPostAuthorModel? reporter;
  final String reason;
  final String? details;
  final String status; // PENDING, RESOLVED, DISMISSED
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final AdminPostAuthorModel? resolvedBy;

  const AdminPostReportModel({
    required this.reportId,
    required this.postId,
    this.reporter,
    required this.reason,
    this.details,
    this.status = 'PENDING',
    required this.createdAt,
    this.resolvedAt,
    this.resolvedBy,
  });

  factory AdminPostReportModel.fromJson(Map<String, dynamic> json) {
    return AdminPostReportModel(
      reportId: json['reportId'] is int
          ? json['reportId'] as int
          : int.tryParse('${json['reportId']}') ?? 0,
      postId: json['postId'] is int
          ? json['postId'] as int
          : int.tryParse('${json['postId']}') ?? 0,
      reporter: json['reporter'] != null
          ? AdminPostAuthorModel.fromJson(
              Map<String, dynamic>.from(json['reporter'] as Map),
            )
          : null,
      reason: json['reason']?.toString() ?? '',
      details: json['details']?.toString(),
      status: json['status']?.toString() ?? 'PENDING',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'].toString())
          : null,
      resolvedBy: json['resolvedBy'] != null
          ? AdminPostAuthorModel.fromJson(
              Map<String, dynamic>.from(json['resolvedBy'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'reportId': reportId,
    'postId': postId,
    'reporter': reporter?.toJson(),
    'reason': reason,
    'details': details,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'resolvedAt': resolvedAt?.toIso8601String(),
    'resolvedBy': resolvedBy?.toJson(),
  };
}

