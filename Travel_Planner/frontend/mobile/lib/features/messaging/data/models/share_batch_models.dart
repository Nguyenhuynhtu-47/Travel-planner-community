class ShareBatchRequest {
  final String targetType;
  final int targetId;
  final List<int> recipientUserIds;
  final String? note;
  final String? shareBatchId;

  const ShareBatchRequest({
    required this.targetType,
    required this.targetId,
    required this.recipientUserIds,
    this.note,
    this.shareBatchId,
  });

  Map<String, dynamic> toJson() => {
    'targetType': targetType.toUpperCase(),
    'targetId': targetId,
    'recipientUserIds': recipientUserIds,
    if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
    if (shareBatchId != null && shareBatchId!.trim().isNotEmpty)
      'shareBatchId': shareBatchId!.trim(),
  };
}

class ShareBatchItemResponse {
  final int recipientUserId;
  final String? recipientUsername;
  final String? recipientFullName;
  final bool success;
  final String? errorMessage;
  final int? conversationId;
  final int? messageId;
  final int? sequenceNumber;

  const ShareBatchItemResponse({
    required this.recipientUserId,
    this.recipientUsername,
    this.recipientFullName,
    required this.success,
    this.errorMessage,
    this.conversationId,
    this.messageId,
    this.sequenceNumber,
  });

  factory ShareBatchItemResponse.fromJson(Map<String, dynamic> json) =>
      ShareBatchItemResponse(
        recipientUserId: (json['recipientUserId'] as num?)?.toInt() ?? 0,
        recipientUsername: json['recipientUsername']?.toString(),
        recipientFullName: json['recipientFullName']?.toString(),
        success: json['success'] == true,
        errorMessage: json['errorMessage']?.toString(),
        conversationId: (json['conversationId'] as num?)?.toInt(),
        messageId: (json['messageId'] as num?)?.toInt(),
        sequenceNumber: (json['sequenceNumber'] as num?)?.toInt(),
      );
}

class ShareBatchResponse {
  final String targetType;
  final int targetId;
  final int totalRequested;
  final int successCount;
  final int failedCount;
  final List<ShareBatchItemResponse> results;

  const ShareBatchResponse({
    required this.targetType,
    required this.targetId,
    required this.totalRequested,
    required this.successCount,
    required this.failedCount,
    required this.results,
  });

  bool get isAllSuccess => failedCount == 0 && successCount > 0;
  bool get isPartialSuccess => successCount > 0 && failedCount > 0;
  bool get isAllFailed => successCount == 0;

  factory ShareBatchResponse.fromJson(Map<String, dynamic> json) =>
      ShareBatchResponse(
        targetType: json['targetType']?.toString().toUpperCase() ?? '',
        targetId: (json['targetId'] as num?)?.toInt() ?? 0,
        totalRequested: (json['totalRequested'] as num?)?.toInt() ?? 0,
        successCount: (json['successCount'] as num?)?.toInt() ?? 0,
        failedCount: (json['failedCount'] as num?)?.toInt() ?? 0,
        results: (json['results'] as List? ?? const [])
            .map(
              (item) => ShareBatchItemResponse.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
      );
}
