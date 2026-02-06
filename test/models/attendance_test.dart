import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:classpulse/models/attendance.dart';

import '../helpers/test_data.dart';

void main() {
  group('AttendanceStatus', () {
    test('fromString parses all values', () {
      expect(AttendanceStatus.fromString('present'), AttendanceStatus.present);
      expect(AttendanceStatus.fromString('absent'), AttendanceStatus.absent);
      expect(AttendanceStatus.fromString('late'), AttendanceStatus.late);
      expect(AttendanceStatus.fromString('unmarked'), AttendanceStatus.unmarked);
    });

    test('fromString is case insensitive', () {
      expect(AttendanceStatus.fromString('PRESENT'), AttendanceStatus.present);
      expect(AttendanceStatus.fromString('Absent'), AttendanceStatus.absent);
    });

    test('fromString defaults to unmarked for unknown values', () {
      expect(AttendanceStatus.fromString('unknown'), AttendanceStatus.unmarked);
      expect(AttendanceStatus.fromString(''), AttendanceStatus.unmarked);
    });

    test('next() cycles correctly', () {
      expect(AttendanceStatus.unmarked.next(), AttendanceStatus.present);
      expect(AttendanceStatus.present.next(), AttendanceStatus.absent);
      expect(AttendanceStatus.absent.next(), AttendanceStatus.late);
      expect(AttendanceStatus.late.next(), AttendanceStatus.unmarked);
    });

    test('displayName returns human-readable values', () {
      expect(AttendanceStatus.present.displayName, 'Present');
      expect(AttendanceStatus.absent.displayName, 'Absent');
      expect(AttendanceStatus.late.displayName, 'Late');
      expect(AttendanceStatus.unmarked.displayName, 'Unmarked');
    });
  });

  group('NotificationStatus', () {
    test('fromString parses all values', () {
      expect(NotificationStatus.fromString('sent'), NotificationStatus.sent);
      expect(NotificationStatus.fromString('delivered'), NotificationStatus.delivered);
      expect(NotificationStatus.fromString('read'), NotificationStatus.read);
      expect(NotificationStatus.fromString('failed'), NotificationStatus.failed);
      expect(NotificationStatus.fromString('pending'), NotificationStatus.pending);
    });

    test('fromString defaults to pending', () {
      expect(NotificationStatus.fromString('unknown'), NotificationStatus.pending);
    });
  });

  group('NotificationChannel', () {
    test('fromString parses all values', () {
      expect(NotificationChannel.fromString('whatsapp'), NotificationChannel.whatsapp);
      expect(NotificationChannel.fromString('sms'), NotificationChannel.sms);
      expect(NotificationChannel.fromString('none'), NotificationChannel.none);
    });

    test('fromString defaults to none', () {
      expect(NotificationChannel.fromString('email'), NotificationChannel.none);
    });
  });

  group('AttendanceRecord', () {
    group('fromFirestore', () {
      test('parses all fields', () async {
        final fakeFirestore = FakeFirebaseFirestore();
        final now = DateTime(2024, 6, 15, 10, 0);

        await fakeFirestore.collection('attendance').doc('a1').set({
          'instituteId': 'inst-1',
          'batchId': 'batch-1',
          'date': Timestamp.fromDate(now),
          'submittedBy': 'teacher-1',
          'submittedAt': Timestamp.fromDate(now),
          'lastEditedAt': Timestamp.fromDate(now),
          'lastEditedBy': 'teacher-2',
          'isSynced': false,
        });

        final doc = await fakeFirestore.collection('attendance').doc('a1').get();
        final record = AttendanceRecord.fromFirestore(doc);

        expect(record.id, 'a1');
        expect(record.instituteId, 'inst-1');
        expect(record.batchId, 'batch-1');
        expect(record.submittedBy, 'teacher-1');
        expect(record.lastEditedBy, 'teacher-2');
        expect(record.isSynced, false);
      });

      test('uses defaults for missing fields', () async {
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore.collection('attendance').doc('a2').set({});

        final doc = await fakeFirestore.collection('attendance').doc('a2').get();
        final record = AttendanceRecord.fromFirestore(doc);

        expect(record.instituteId, '');
        expect(record.batchId, '');
        expect(record.submittedBy, '');
        expect(record.lastEditedAt, isNull);
        expect(record.lastEditedBy, isNull);
        expect(record.isSynced, true);
      });
    });

    group('toFirestore', () {
      test('serializes all fields', () {
        final record = TestData.attendanceRecord();
        final data = record.toFirestore();

        expect(data['instituteId'], 'inst-1');
        expect(data['batchId'], 'batch-1');
        expect(data['submittedBy'], 'teacher-1');
        expect(data['date'], isA<Timestamp>());
        expect(data['isSynced'], true);
      });
    });

    group('canEdit', () {
      test('returns true within edit window', () {
        final record = TestData.attendanceRecord(
          submittedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        );
        expect(record.canEdit(const Duration(hours: 2)), true);
      });

      test('returns false after edit window', () {
        final record = TestData.attendanceRecord(
          submittedAt: DateTime.now().subtract(const Duration(hours: 3)),
        );
        expect(record.canEdit(const Duration(hours: 2)), false);
      });
    });

    group('remainingEditTime', () {
      test('returns remaining duration', () {
        final record = TestData.attendanceRecord(
          submittedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        );
        final remaining = record.remainingEditTime(const Duration(hours: 2));
        expect(remaining.inMinutes, closeTo(90, 1));
      });

      test('returns zero after window expires', () {
        final record = TestData.attendanceRecord(
          submittedAt: DateTime.now().subtract(const Duration(hours: 3)),
        );
        expect(record.remainingEditTime(const Duration(hours: 2)), Duration.zero);
      });
    });
  });

  group('StudentAttendance', () {
    group('fromFirestore', () {
      test('parses all fields', () async {
        final fakeFirestore = FakeFirebaseFirestore();
        final now = DateTime(2024, 6, 15);

        await fakeFirestore.collection('records').doc('r1').set({
          'studentId': 'student-1',
          'studentName': 'Rahul',
          'parentPhone': '9876543210',
          'status': 'present',
          'markedAt': Timestamp.fromDate(now),
          'notificationStatus': 'sent',
          'notificationChannel': 'whatsapp',
          'notificationError': null,
        });

        final doc = await fakeFirestore.collection('records').doc('r1').get();
        final sa = StudentAttendance.fromFirestore(doc);

        expect(sa.studentId, 'student-1');
        expect(sa.status, AttendanceStatus.present);
        expect(sa.notificationStatus, NotificationStatus.sent);
        expect(sa.notificationChannel, NotificationChannel.whatsapp);
      });
    });

    test('copyWith creates new instance', () {
      final sa = TestData.studentAttendance();
      final updated = sa.copyWith(status: AttendanceStatus.absent);

      expect(updated.status, AttendanceStatus.absent);
      expect(updated.studentId, sa.studentId);
    });
  });

  group('AttendanceSummary', () {
    test('fromEntries calculates counts correctly', () {
      final entries = [
        TestData.studentAttendance(id: 'sa-1', status: AttendanceStatus.present),
        TestData.studentAttendance(id: 'sa-2', status: AttendanceStatus.present),
        TestData.studentAttendance(id: 'sa-3', status: AttendanceStatus.absent),
        TestData.studentAttendance(id: 'sa-4', status: AttendanceStatus.late),
        TestData.studentAttendance(id: 'sa-5', status: AttendanceStatus.unmarked),
      ];

      final summary = AttendanceSummary.fromEntries(entries);

      expect(summary.totalStudents, 5);
      expect(summary.presentCount, 2);
      expect(summary.absentCount, 1);
      expect(summary.lateCount, 1);
      expect(summary.unmarkedCount, 1);
    });

    test('attendancePercentage counts present + late', () {
      final entries = [
        TestData.studentAttendance(id: 'sa-1', status: AttendanceStatus.present),
        TestData.studentAttendance(id: 'sa-2', status: AttendanceStatus.late),
        TestData.studentAttendance(id: 'sa-3', status: AttendanceStatus.absent),
        TestData.studentAttendance(id: 'sa-4', status: AttendanceStatus.absent),
      ];

      final summary = AttendanceSummary.fromEntries(entries);
      expect(summary.attendancePercentage, 50.0); // 2/4 * 100
    });

    test('attendancePercentage handles empty list', () {
      final summary = AttendanceSummary.fromEntries([]);
      expect(summary.attendancePercentage, 0);
    });

    test('isComplete when no unmarked', () {
      final entries = [
        TestData.studentAttendance(id: 'sa-1', status: AttendanceStatus.present),
        TestData.studentAttendance(id: 'sa-2', status: AttendanceStatus.absent),
      ];

      final summary = AttendanceSummary.fromEntries(entries);
      expect(summary.isComplete, true);
    });

    test('isComplete false when unmarked exist', () {
      final entries = [
        TestData.studentAttendance(id: 'sa-1', status: AttendanceStatus.present),
        TestData.studentAttendance(id: 'sa-2', status: AttendanceStatus.unmarked),
      ];

      final summary = AttendanceSummary.fromEntries(entries);
      expect(summary.isComplete, false);
    });
  });

  group('StudentMonthlyAttendance', () {
    test('attendancePercentage calculation', () {
      final monthly = StudentMonthlyAttendance(
        studentId: 's1',
        studentName: 'Test',
        presentCount: 15,
        absentCount: 3,
        lateCount: 2,
        totalDays: 20,
      );

      // (15 + 2) / 20 * 100 = 85%
      expect(monthly.attendancePercentage, 85.0);
    });

    test('handles zero total days', () {
      final monthly = StudentMonthlyAttendance(
        studentId: 's1',
        studentName: 'Test',
        presentCount: 0,
        absentCount: 0,
        lateCount: 0,
        totalDays: 0,
      );

      expect(monthly.attendancePercentage, 0);
    });
  });
}
