import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/messaging/data/messaging_date_time.dart';

void main() {
  test('formats zone-less backend LocalDateTime as Vietnam wall time', () {
    final value = MessagingDateTime.parseApi('2026-11-17T14:55:00');

    expect(value, isNotNull);
    expect(MessagingDateTime.format(value!), '14:55 17-11-2026');
  });

  test('normalizes explicit UTC and Vietnam offsets only once', () {
    final utc = MessagingDateTime.parseApi('2026-11-17T07:55:00Z');
    final vietnam = MessagingDateTime.parseApi('2026-11-17T14:55:00+07:00');

    expect(MessagingDateTime.format(utc!), '14:55 17-11-2026');
    expect(MessagingDateTime.format(vietnam!), '14:55 17-11-2026');
  });

  test('pads hour, day, and month', () {
    final value = MessagingDateTime.parseApi('2026-12-01T09:30:00');

    expect(MessagingDateTime.format(value!), '09:30 01-12-2026');
  });
}
