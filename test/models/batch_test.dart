import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:classpulse/models/batch.dart';

import '../helpers/test_data.dart';

void main() {
  group('Batch', () {
    group('fromFirestore', () {
      test('parses all fields correctly', () async {
        final fakeFirestore = FakeFirebaseFirestore();
        final now = DateTime(2024, 6, 15, 10, 30);

        await fakeFirestore.collection('batches').doc('b1').set({
          'instituteId': 'inst-1',
          'name': 'Morning Batch',
          'subject': 'Math',
          'scheduleDays': ['monday', 'wednesday'],
          'startTime': {'hour': 9, 'minute': 0},
          'endTime': {'hour': 10, 'minute': 30},
          'isActive': true,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });

        final doc = await fakeFirestore.collection('batches').doc('b1').get();
        final batch = Batch.fromFirestore(doc);

        expect(batch.id, 'b1');
        expect(batch.instituteId, 'inst-1');
        expect(batch.name, 'Morning Batch');
        expect(batch.subject, 'Math');
        expect(batch.scheduleDays, ['monday', 'wednesday']);
        expect(batch.startTime.hour, 9);
        expect(batch.startTime.minute, 0);
        expect(batch.endTime.hour, 10);
        expect(batch.endTime.minute, 30);
        expect(batch.isActive, true);
      });

      test('uses defaults for missing fields', () async {
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore.collection('batches').doc('b2').set({});

        final doc = await fakeFirestore.collection('batches').doc('b2').get();
        final batch = Batch.fromFirestore(doc);

        expect(batch.id, 'b2');
        expect(batch.instituteId, '');
        expect(batch.name, '');
        expect(batch.subject, isNull);
        expect(batch.scheduleDays, isEmpty);
        expect(batch.isActive, true);
        expect(batch.startTime.hour, 9);
        expect(batch.endTime.hour, 10);
      });
    });

    group('toFirestore', () {
      test('serializes all fields', () {
        final batch = TestData.batch();
        final data = batch.toFirestore();

        expect(data['instituteId'], 'inst-1');
        expect(data['name'], 'Morning Batch');
        expect(data['subject'], 'Mathematics');
        expect(data['scheduleDays'], ['monday', 'wednesday', 'friday']);
        expect(data['isActive'], true);
        expect(data['startTime'], {'hour': 9, 'minute': 0});
        expect(data['endTime'], {'hour': 10, 'minute': 30});
        expect(data['createdAt'], isA<Timestamp>());
      });
    });

    group('copyWith', () {
      test('copies with new values', () {
        final batch = TestData.batch();
        final updated = batch.copyWith(
          name: 'Evening Batch',
          isActive: false,
        );

        expect(updated.name, 'Evening Batch');
        expect(updated.isActive, false);
        expect(updated.id, batch.id); // unchanged
        expect(updated.instituteId, batch.instituteId);
      });

      test('preserves original when no changes', () {
        final batch = TestData.batch();
        final copy = batch.copyWith();

        expect(copy.name, batch.name);
        expect(copy.id, batch.id);
        expect(copy.scheduleDays, batch.scheduleDays);
      });
    });

    group('formattedSchedule', () {
      test('formats schedule days and times', () {
        final batch = TestData.batch(
          scheduleDays: ['monday', 'wednesday', 'friday'],
          startTime: const ScheduleTime(hour: 9, minute: 0),
          endTime: const ScheduleTime(hour: 10, minute: 30),
        );
        expect(batch.formattedSchedule, 'MON, WED, FRI 09:00 - 10:30');
      });

      test('returns fallback for empty schedule', () {
        final batch = TestData.batch(scheduleDays: []);
        expect(batch.formattedSchedule, 'No schedule set');
      });
    });
  });

  group('ScheduleTime', () {
    test('format24h pads single digits', () {
      const time = ScheduleTime(hour: 9, minute: 5);
      expect(time.format24h(), '09:05');
    });

    test('format12h shows correct AM/PM', () {
      const morning = ScheduleTime(hour: 9, minute: 30);
      expect(morning.format12h(), '09:30 AM');

      const afternoon = ScheduleTime(hour: 14, minute: 0);
      expect(afternoon.format12h(), '02:00 PM');

      const midnight = ScheduleTime(hour: 0, minute: 0);
      expect(midnight.format12h(), '12:00 AM');

      const noon = ScheduleTime(hour: 12, minute: 0);
      expect(noon.format12h(), '12:00 PM');
    });

    test('fromMap handles nulls', () {
      final time = ScheduleTime.fromMap({});
      expect(time.hour, 0);
      expect(time.minute, 0);
    });

    test('toMap round-trips correctly', () {
      const time = ScheduleTime(hour: 14, minute: 45);
      final map = time.toMap();
      final restored = ScheduleTime.fromMap(map);
      expect(restored.hour, 14);
      expect(restored.minute, 45);
    });
  });
}
