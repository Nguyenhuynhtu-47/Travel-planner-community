class CreateDayRequest {
  final String? title;
  final DateTime? date;

  const CreateDayRequest({this.title, this.date});

  Map<String, dynamic> toJson() {
    return {
      if (title != null && title!.trim().isNotEmpty) 'title': title!.trim(),
      if (date != null)
        'date':
            '${date!.year.toString().padLeft(4, '0')}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}',
    };
  }
}
