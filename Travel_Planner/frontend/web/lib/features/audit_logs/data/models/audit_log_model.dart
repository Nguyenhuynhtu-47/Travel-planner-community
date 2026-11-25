import 'dart:convert';

/// Allowlist model for Audit Log list rows (read-only).
class AuditLogModel {
  final int logId;
  final int actorId;
  final String actorUsername;
  final String actionType;
  final String targetType;
  final String targetId;
  final String? reason;
  final String resultStatus;
  final String? ipAddress;
  final String? correlationId;
  final DateTime? createdAt;

  const AuditLogModel({
    required this.logId,
    required this.actorId,
    required this.actorUsername,
    required this.actionType,
    required this.targetType,
    required this.targetId,
    this.reason,
    required this.resultStatus,
    this.ipAddress,
    this.correlationId,
    this.createdAt,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    return AuditLogModel(
      logId: (json['logId'] as num?)?.toInt() ?? 0,
      actorId: (json['actorId'] as num?)?.toInt() ?? 0,
      actorUsername: json['actorUsername']?.toString() ?? '',
      actionType: json['actionType']?.toString() ?? '',
      targetType: json['targetType']?.toString() ?? '',
      targetId: json['targetId']?.toString() ?? '',
      reason: json['reason']?.toString(),
      resultStatus: json['resultStatus']?.toString() ?? 'SUCCESS',
      ipAddress: json['ipAddress']?.toString(),
      correlationId: json['correlationId']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}

/// Allowlist detail model for Audit Log inspection (read-only, masked snapshots).
class AuditLogDetailModel extends AuditLogModel {
  final String? userAgent;
  final String? beforeDataJson;
  final String? afterDataJson;

  const AuditLogDetailModel({
    required super.logId,
    required super.actorId,
    required super.actorUsername,
    required super.actionType,
    required super.targetType,
    required super.targetId,
    super.reason,
    required super.resultStatus,
    super.ipAddress,
    super.correlationId,
    super.createdAt,
    this.userAgent,
    this.beforeDataJson,
    this.afterDataJson,
  });

  static String formatJsonPretty(String? rawJson) {
    if (rawJson == null || rawJson.trim().isEmpty) {
      return 'Không có dữ liệu snapshot';
    }
    try {
      final decoded = jsonDecode(rawJson);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    } catch (_) {
      return rawJson;
    }
  }

  factory AuditLogDetailModel.fromJson(Map<String, dynamic> json) {
    return AuditLogDetailModel(
      logId: (json['logId'] as num?)?.toInt() ?? 0,
      actorId: (json['actorId'] as num?)?.toInt() ?? 0,
      actorUsername: json['actorUsername']?.toString() ?? '',
      actionType: json['actionType']?.toString() ?? '',
      targetType: json['targetType']?.toString() ?? '',
      targetId: json['targetId']?.toString() ?? '',
      reason: json['reason']?.toString(),
      resultStatus: json['resultStatus']?.toString() ?? 'SUCCESS',
      ipAddress: json['ipAddress']?.toString(),
      correlationId: json['correlationId']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      userAgent: json['userAgent']?.toString(),
      beforeDataJson: json['beforeDataJson']?.toString(),
      afterDataJson: json['afterDataJson']?.toString(),
    );
  }
}
