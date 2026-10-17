import 'package:bouncr/domain/event_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 17, 12);

  test('title is required and limited to 3–80 characters', () {
    expect(EventValidator.validateTitle('  '), 'Title is required');
    expect(EventValidator.validateTitle('AI'), 'Title is too short');
    expect(EventValidator.validateTitle('A' * 81), 'Title must be at most 80 characters');
    expect(EventValidator.validateTitle('AI Club Workshop'), isNull);
  });

  test('description is optional but limited', () {
    expect(EventValidator.validateDescription(''), isNull);
    expect(EventValidator.validateDescription('x' * 1001), isNotNull);
  });

  test('location is required', () {
    expect(EventValidator.validateLocation(''), 'Location is required');
    expect(EventValidator.validateLocation('Room 204'), isNull);
  });

  group('startsAt', () {
    test('must be chosen and in the future for a new event', () {
      expect(EventValidator.validateStartsAt(null, now: now), 'Pick a date and time');
      expect(EventValidator.validateStartsAt(now, now: now),
          'The event must start in the future');
      expect(EventValidator.validateStartsAt(now.add(const Duration(hours: 1)), now: now),
          isNull);
    });

    test('an unchanged date of an existing event is accepted', () {
      final original = now.subtract(const Duration(hours: 1));
      expect(EventValidator.validateStartsAt(original, now: now, original: original), isNull);
    });
  });

  group('capacity', () {
    test('must be a whole number between 1 and 5000', () {
      expect(EventValidator.validateCapacity(''), 'Capacity is required');
      expect(EventValidator.validateCapacity('ten'), 'Enter a whole number');
      expect(EventValidator.validateCapacity('2.5'), 'Enter a whole number');
      expect(EventValidator.validateCapacity('0'), 'Capacity must be at least 1');
      expect(EventValidator.validateCapacity('5001'), 'Capacity must be at most 5000');
      expect(EventValidator.validateCapacity('40'), isNull);
    });

    test('cannot drop below tickets already issued', () {
      expect(EventValidator.validateCapacity('10', ticketsIssued: 12),
          '12 tickets are already issued – capacity cannot be lower');
      expect(EventValidator.validateCapacity('12', ticketsIssued: 12), isNull);
    });
  });
}
