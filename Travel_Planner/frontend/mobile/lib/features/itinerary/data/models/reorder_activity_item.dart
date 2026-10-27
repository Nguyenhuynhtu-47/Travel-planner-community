class ReorderActivityItem {
  final int activityId;
  final int displayOrder;

  const ReorderActivityItem({
    required this.activityId,
    required this.displayOrder,
  });

  Map<String, dynamic> toJson() {
    return {'activityId': activityId, 'displayOrder': displayOrder};
  }
}
