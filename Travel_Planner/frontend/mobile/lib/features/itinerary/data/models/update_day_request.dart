class UpdateDayRequest {
  final String? title;
  final DateTime? date;

  const UpdateDayRequest({
    this.title,
    this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': (title != null && title!.trim().isNotEmpty) ? title!.trim() : null,
      'date': date != null
          ? '${date!.year.toString().padLeft(4, '0')}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}'
          : null,
    };
  }
}
