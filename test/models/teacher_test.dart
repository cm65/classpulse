import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:classpulse/models/teacher.dart';

import '../helpers/test_data.dart';

void main() {
  group('TeacherRole', () {
    test('fromString parses admin', () {
      expect(TeacherRole.fromString('admin'), TeacherRole.admin);
    });

    test('fromString defaults to teacher', () {
      expect(TeacherRole.fromString('teacher'), TeacherRole.teacher);
      expect(TeacherRole.fromString('unknown'), TeacherRole.teacher);
      expect(TeacherRole.fromString(''), TeacherRole.teacher);
    });

    test('isAdmin returns correct value', () {
      expect(TeacherRole.admin.isAdmin, true);
      expect(TeacherRole.teacher.isAdmin, false);
    });

    test('displayName returns human-readable values', () {
      expect(TeacherRole.admin.displayName, 'Admin');
      expect(TeacherRole.teacher.displayName, 'Teacher');
    });
  });

  group('Teacher', () {
    group('fromFirestore', () {
      test('parses all fields', () async {
        final fakeFirestore = FakeFirebaseFirestore();
        final now = DateTime(2024, 6, 15);

        await fakeFirestore.collection('teachers').doc('t1').set({
          'instituteId': 'inst-1',
          'name': 'John Teacher',
          'phone': '9999999999',
          'role': 'admin',
          'isActive': true,
          'createdAt': Timestamp.fromDate(now),
          'lastLoginAt': Timestamp.fromDate(now),
        });

        final doc = await fakeFirestore.collection('teachers').doc('t1').get();
        final teacher = Teacher.fromFirestore(doc);

        expect(teacher.id, 't1');
        expect(teacher.instituteId, 'inst-1');
        expect(teacher.name, 'John Teacher');
        expect(teacher.phone, '9999999999');
        expect(teacher.role, TeacherRole.admin);
        expect(teacher.isActive, true);
        expect(teacher.lastLoginAt, isNotNull);
      });

      test('uses defaults for missing fields', () async {
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore.collection('teachers').doc('t2').set({});

        final doc = await fakeFirestore.collection('teachers').doc('t2').get();
        final teacher = Teacher.fromFirestore(doc);

        expect(teacher.instituteId, '');
        expect(teacher.name, '');
        expect(teacher.role, TeacherRole.teacher);
        expect(teacher.isActive, true);
        expect(teacher.lastLoginAt, isNull);
      });
    });

    group('toFirestore', () {
      test('serializes all fields', () {
        final teacher = TestData.admin();
        final data = teacher.toFirestore();

        expect(data['instituteId'], 'inst-1');
        expect(data['name'], 'Test Admin');
        expect(data['role'], 'admin');
        expect(data['isActive'], true);
        expect(data['createdAt'], isA<Timestamp>());
        expect(data['lastLoginAt'], isNull);
      });
    });

    group('permission checks', () {
      test('admin has all permissions', () {
        final admin = TestData.admin();
        expect(admin.canManageInstitute, true);
        expect(admin.canManageTeachers, true);
        expect(admin.canViewAuditLogs, true);
        expect(admin.canConfigureSettings, true);
      });

      test('teacher has no admin permissions', () {
        final teacher = TestData.teacher();
        expect(teacher.canManageInstitute, false);
        expect(teacher.canManageTeachers, false);
        expect(teacher.canViewAuditLogs, false);
        expect(teacher.canConfigureSettings, false);
      });
    });

    test('copyWith works correctly', () {
      final teacher = TestData.teacher();
      final updated = teacher.copyWith(role: TeacherRole.admin, name: 'Promoted');

      expect(updated.role, TeacherRole.admin);
      expect(updated.name, 'Promoted');
      expect(updated.id, teacher.id);
    });
  });

  group('TeacherInvitation', () {
    test('isExpired returns true for past dates', () {
      final invitation = TeacherInvitation(
        id: 'inv-1',
        instituteId: 'inst-1',
        instituteName: 'Test Academy',
        phone: '9876543210',
        invitedBy: 'admin-1',
        invitedAt: DateTime.now().subtract(const Duration(days: 10)),
        expiresAt: DateTime.now().subtract(const Duration(days: 3)),
      );
      expect(invitation.isExpired, true);
      expect(invitation.isValid, false);
    });

    test('isValid returns true for non-expired, non-accepted', () {
      final invitation = TeacherInvitation(
        id: 'inv-1',
        instituteId: 'inst-1',
        instituteName: 'Test Academy',
        phone: '9876543210',
        invitedBy: 'admin-1',
        invitedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );
      expect(invitation.isExpired, false);
      expect(invitation.isValid, true);
    });

    test('isValid returns false when accepted', () {
      final invitation = TeacherInvitation(
        id: 'inv-1',
        instituteId: 'inst-1',
        instituteName: 'Test Academy',
        phone: '9876543210',
        invitedBy: 'admin-1',
        invitedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
        isAccepted: true,
      );
      expect(invitation.isValid, false);
    });
  });
}
