import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:classpulse/models/audit_log.dart';

import '../helpers/test_data.dart';

void main() {
  group('AuditAction', () {
    test('fromString parses all values', () {
      expect(AuditAction.fromString('attendanceMark'), AuditAction.attendanceMark);
      expect(AuditAction.fromString('attendanceSubmit'), AuditAction.attendanceSubmit);
      expect(AuditAction.fromString('studentAdd'), AuditAction.studentAdd);
      expect(AuditAction.fromString('batchCreate'), AuditAction.batchCreate);
      expect(AuditAction.fromString('login'), AuditAction.login);
      expect(AuditAction.fromString('logout'), AuditAction.logout);
    });

    test('fromString defaults to attendanceMark for unknown', () {
      expect(AuditAction.fromString('unknown'), AuditAction.attendanceMark);
    });

    test('displayName returns human-readable values', () {
      expect(AuditAction.attendanceSubmit.displayName, 'Submitted Attendance');
      expect(AuditAction.studentAdd.displayName, 'Added Student');
      expect(AuditAction.batchCreate.displayName, 'Created Batch');
    });
  });

  group('AuditLog', () {
    group('fromFirestore', () {
      test('parses all fields', () async {
        final fakeFirestore = FakeFirebaseFirestore();
        final now = DateTime(2024, 6, 15);

        await fakeFirestore.collection('auditLog').doc('l1').set({
          'instituteId': 'inst-1',
          'userId': 'teacher-1',
          'userName': 'Test Teacher',
          'action': 'attendanceSubmit',
          'timestamp': Timestamp.fromDate(now),
          'oldValue': {'status': 'unmarked'},
          'newValue': {'status': 'present'},
          'metadata': {'batchId': 'b1'},
        });

        final doc = await fakeFirestore.collection('auditLog').doc('l1').get();
        final log = AuditLog.fromFirestore(doc);

        expect(log.id, 'l1');
        expect(log.action, AuditAction.attendanceSubmit);
        expect(log.oldValue, isNotNull);
        expect(log.newValue, isNotNull);
        expect(log.metadata, isNotNull);
      });
    });

    group('toFirestore', () {
      test('serializes correctly', () {
        final log = TestData.auditLog();
        final data = log.toFirestore();

        expect(data['instituteId'], 'inst-1');
        expect(data['userId'], 'teacher-1');
        expect(data['action'], 'attendanceSubmit');
        expect(data['timestamp'], isA<Timestamp>());
      });
    });

    group('create factory', () {
      test('creates log with correct fields', () {
        final log = AuditLog.create(
          instituteId: 'inst-1',
          userId: 'teacher-1',
          userName: 'Test',
          action: AuditAction.studentAdd,
          newValue: {'name': 'New Student'},
        );

        expect(log.id, '');
        expect(log.action, AuditAction.studentAdd);
        expect(log.newValue, {'name': 'New Student'});
      });
    });

    group('changeDescription', () {
      test('returns action name when no values', () {
        final log = TestData.auditLog();
        expect(log.changeDescription, 'Submitted Attendance');
      });

      test('describes changes between old and new values', () {
        final log = AuditLog(
          id: 'l1',
          instituteId: 'inst-1',
          userId: 'teacher-1',
          userName: 'Test',
          action: AuditAction.studentEdit,
          timestamp: DateTime.now(),
          oldValue: {'name': 'Old Name'},
          newValue: {'name': 'New Name'},
        );
        expect(log.changeDescription, contains('name'));
        expect(log.changeDescription, contains('New Name'));
      });
    });
  });
}
