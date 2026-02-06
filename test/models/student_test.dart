import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:classpulse/models/student.dart';

import '../helpers/test_data.dart';

void main() {
  group('Student', () {
    group('fromFirestore', () {
      test('parses all fields correctly', () async {
        final fakeFirestore = FakeFirebaseFirestore();
        final now = DateTime(2024, 6, 15);

        await fakeFirestore.collection('students').doc('s1').set({
          'batchId': 'batch-1',
          'name': 'Rahul Sharma',
          'parentPhone': '9876543210',
          'studentId': 'ROLL-001',
          'isActive': true,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });

        final doc = await fakeFirestore.collection('students').doc('s1').get();
        final student = Student.fromFirestore(doc);

        expect(student.id, 's1');
        expect(student.batchId, 'batch-1');
        expect(student.name, 'Rahul Sharma');
        expect(student.parentPhone, '9876543210');
        expect(student.studentId, 'ROLL-001');
        expect(student.isActive, true);
      });

      test('uses defaults for missing fields', () async {
        final fakeFirestore = FakeFirebaseFirestore();
        await fakeFirestore.collection('students').doc('s2').set({});

        final doc = await fakeFirestore.collection('students').doc('s2').get();
        final student = Student.fromFirestore(doc);

        expect(student.batchId, '');
        expect(student.name, '');
        expect(student.parentPhone, '');
        expect(student.studentId, isNull);
        expect(student.isActive, true);
      });
    });

    group('toFirestore', () {
      test('serializes all fields', () {
        final student = TestData.student(studentId: 'ROLL-001');
        final data = student.toFirestore();

        expect(data['batchId'], 'batch-1');
        expect(data['name'], 'Rahul Sharma');
        expect(data['parentPhone'], '9876543210');
        expect(data['studentId'], 'ROLL-001');
        expect(data['isActive'], true);
        expect(data['createdAt'], isA<Timestamp>());
      });
    });

    group('copyWith', () {
      test('copies with new values', () {
        final student = TestData.student();
        final updated = student.copyWith(
          name: 'Priya Singh',
          isActive: false,
        );

        expect(updated.name, 'Priya Singh');
        expect(updated.isActive, false);
        expect(updated.id, student.id);
        expect(updated.batchId, student.batchId);
      });
    });

    group('isValidIndianPhone', () {
      test('accepts valid 10-digit numbers starting with 6-9', () {
        expect(Student.isValidIndianPhone('9876543210'), true);
        expect(Student.isValidIndianPhone('8765432109'), true);
        expect(Student.isValidIndianPhone('7654321098'), true);
        expect(Student.isValidIndianPhone('6543210987'), true);
      });

      test('accepts valid numbers with +91 prefix', () {
        expect(Student.isValidIndianPhone('+919876543210'), true);
        expect(Student.isValidIndianPhone('919876543210'), true);
      });

      test('accepts numbers with spaces and dashes', () {
        expect(Student.isValidIndianPhone('98765 43210'), true);
        expect(Student.isValidIndianPhone('987-654-3210'), true);
        expect(Student.isValidIndianPhone('+91 98765 43210'), true);
      });

      test('rejects numbers starting with 0-5', () {
        expect(Student.isValidIndianPhone('0123456789'), false);
        expect(Student.isValidIndianPhone('1234567890'), false);
        expect(Student.isValidIndianPhone('5555555555'), false);
      });

      test('rejects wrong-length numbers', () {
        expect(Student.isValidIndianPhone('12345'), false);
        expect(Student.isValidIndianPhone('98765432101234'), false);
        expect(Student.isValidIndianPhone(''), false);
      });

      test('rejects non-numeric input', () {
        expect(Student.isValidIndianPhone('abcdefghij'), false);
        expect(Student.isValidIndianPhone('phone'), false);
      });
    });

    group('formattedPhone', () {
      test('adds +91 to 10-digit number', () {
        final student = TestData.student(parentPhone: '9876543210');
        expect(student.formattedPhone, '+919876543210');
      });

      test('adds + to 12-digit number with 91 prefix', () {
        final student = TestData.student(parentPhone: '919876543210');
        expect(student.formattedPhone, '+919876543210');
      });

      test('returns original for unexpected format', () {
        final student = TestData.student(parentPhone: '12345');
        expect(student.formattedPhone, '12345');
      });
    });
  });
}
