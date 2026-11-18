/// Date/time conversion used by messaging UI and API models.
///
/// The backend currently serializes LocalDateTime without an offset. Such
/// values represent wall-clock time in Asia/Ho_Chi_Minh. Offset/Z timestamps
/// represent instants and are normalized to UTC exactly once.
abstract final class MessagingDateTime {
  static const Duration _vietnamOffset = Duration(hours: 7);
  static final RegExp _explicitZone = RegExp(r'(?:[zZ]|[+-]\d{2}:?\d{2})$');

  static DateTime? parseApi(Object? value) {
    if (value is DateTime) return value.toUtc();
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    if (_explicitZone.hasMatch(raw)) return parsed.toUtc();

    // Treat zone-less backend LocalDateTime fields as Vietnam wall time.
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    ).subtract(_vietnamOffset);
  }

  static DateTime toVietnamTime(DateTime instant) =>
      instant.toUtc().add(_vietnamOffset);

  static String format(DateTime instant) {
    final value = toVietnamTime(instant);
    String twoDigits(int part) => part.toString().padLeft(2, '0');
    return '${twoDigits(value.hour)}:${twoDigits(value.minute)} '
        '${twoDigits(value.day)}-${twoDigits(value.month)}-${value.year.toString().padLeft(4, '0')}';
  }
}
