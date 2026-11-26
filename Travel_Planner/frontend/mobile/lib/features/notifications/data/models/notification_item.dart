class NotificationActor {
  final int? userId;
  final String? displayName;
  final String? handle;
  final String? avatar;

  const NotificationActor({
    this.userId,
    this.displayName,
    this.handle,
    this.avatar,
  });

  factory NotificationActor.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const NotificationActor();
    return NotificationActor(
      userId: (json['userId'] as num?)?.toInt(),
      displayName: json['displayName'] as String?,
      handle: json['handle'] as String?,
      avatar: json['avatar'] as String?,
    );
  }
}

class NotificationItem {
  final int id;
  final String type;
  final String? actionType;
  final String title;
  final String body;
  final String? targetType;
  final String? targetId;
  final NotificationActor actor;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isAnnouncement;

  const NotificationItem({
    required this.id,
    required this.type,
    this.actionType,
    required this.title,
    required this.body,
    required this.actor,
    required this.createdAt,
    this.targetType,
    this.targetId,
    this.readAt,
    this.isAnnouncement = false,
  });

  bool get isRead => readAt != null;
  String get stableKey =>
      '${isAnnouncement ? 'announcement' : 'notification'}:$id';

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse('${json['createdAt'] ?? ''}');
    if (createdAt == null) {
      throw const FormatException('Thiếu thời gian tạo thông báo');
    }
    final rawId = json['id'];
    if (rawId is! num) {
      throw const FormatException('Thiếu mã thông báo');
    }
    final rawActor = json['actor'];
    return NotificationItem(
      id: rawId.toInt(),
      type: json['type'] is String ? json['type'] as String : 'UNKNOWN',
      actionType: json['actionType'] as String?,
      title: json['title'] is String ? json['title'] as String : '',
      body: json['body'] is String ? json['body'] as String : '',
      targetType: json['targetType'] as String?,
      targetId: json['targetId'] as String?,
      actor: NotificationActor.fromJson(
        rawActor is Map ? Map<String, dynamic>.from(rawActor) : null,
      ),
      createdAt: createdAt,
      readAt: DateTime.tryParse('${json['readAt'] ?? ''}'),
      isAnnouncement: json['announcement'] == true,
    );
  }
}

class NotificationPage {
  final List<NotificationItem> items;
  final String? nextCursor;
  final bool hasMore;

  const NotificationPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['content'];
    return NotificationPage(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) => NotificationItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      nextCursor: json['nextCursor'] as String?,
      hasMore: json['hasMore'] == true,
    );
  }
}

class NotificationUnreadSummary {
  final int count;
  final int personalCount;
  final int announcementCount;

  const NotificationUnreadSummary({
    required this.count,
    required this.personalCount,
    required this.announcementCount,
  });

  factory NotificationUnreadSummary.fromJson(Map<String, dynamic> json) {
    int value(String key, {required int fallback}) => json[key] is num
        ? (json[key] as num).toInt().clamp(0, 1 << 31)
        : fallback;
    final personal = value(
      'personalCount',
      fallback: value('count', fallback: 0),
    );
    final announcements = value('announcementCount', fallback: 0);
    return NotificationUnreadSummary(
      count: value('count', fallback: personal + announcements),
      personalCount: personal,
      announcementCount: announcements,
    );
  }
}
