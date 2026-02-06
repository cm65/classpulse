import 'package:flutter_test/flutter_test.dart';
import 'package:classpulse/utils/validators.dart';

void main() {
  group('Validators', () {
    group('email', () {
      test('returns null for valid emails', () {
        expect(Validators.email('test@example.com'), isNull);
        expect(Validators.email('user.name@domain.co.in'), isNull);
        expect(Validators.email('admin@test.org'), isNull);
      });

      test('returns error for empty/null', () {
        expect(Validators.email(null), isNotNull);
        expect(Validators.email(''), isNotNull);
        expect(Validators.email('   '), isNotNull);
      });

      test('returns error for invalid emails', () {
        expect(Validators.email('notanemail'), isNotNull);
        expect(Validators.email('@domain.com'), isNotNull);
        expect(Validators.email('user@'), isNotNull);
        expect(Validators.email('user@.com'), isNotNull);
      });
    });

    group('indianPhone', () {
      test('returns null for valid 10-digit numbers', () {
        expect(Validators.indianPhone('9876543210'), isNull);
        expect(Validators.indianPhone('8765432109'), isNull);
        expect(Validators.indianPhone('7654321098'), isNull);
        expect(Validators.indianPhone('6543210987'), isNull);
      });

      test('returns error for empty/null', () {
        expect(Validators.indianPhone(null), isNotNull);
        expect(Validators.indianPhone(''), isNotNull);
      });

      test('returns error for wrong length', () {
        expect(Validators.indianPhone('12345'), isNotNull);
        expect(Validators.indianPhone('98765432101'), isNotNull);
      });

      test('returns error for numbers starting with 0-5', () {
        expect(Validators.indianPhone('0123456789'), isNotNull);
        expect(Validators.indianPhone('5555555555'), isNotNull);
      });

      test('strips non-numeric characters before validating', () {
        expect(Validators.indianPhone('987-654-3210'), isNull);
        expect(Validators.indianPhone('98765 43210'), isNull);
      });
    });

    group('required', () {
      test('returns null for non-empty string', () {
        expect(Validators.required('hello'), isNull);
        expect(Validators.required('a'), isNull);
      });

      test('returns error for empty/null', () {
        expect(Validators.required(null), isNotNull);
        expect(Validators.required(''), isNotNull);
        expect(Validators.required('   '), isNotNull);
      });

      test('uses custom field name in error', () {
        final error = Validators.required(null, fieldName: 'Email');
        expect(error, contains('Email'));
      });
    });

    group('minLength', () {
      test('returns null when meets minimum', () {
        expect(Validators.minLength('hello', 3), isNull);
        expect(Validators.minLength('abc', 3), isNull);
      });

      test('returns error when too short', () {
        expect(Validators.minLength('ab', 3), isNotNull);
        expect(Validators.minLength(null, 3), isNotNull);
      });
    });

    group('maxLength', () {
      test('returns null when within limit', () {
        expect(Validators.maxLength('hello', 10), isNull);
        expect(Validators.maxLength(null, 10), isNull);
      });

      test('returns error when too long', () {
        expect(Validators.maxLength('hello world', 5), isNotNull);
      });
    });

    group('otp', () {
      test('returns null for valid 6-digit OTP', () {
        expect(Validators.otp('123456'), isNull);
        expect(Validators.otp('000000'), isNull);
        expect(Validators.otp('999999'), isNull);
      });

      test('returns error for invalid OTPs', () {
        expect(Validators.otp(null), isNotNull);
        expect(Validators.otp(''), isNotNull);
        expect(Validators.otp('12345'), isNotNull);
        expect(Validators.otp('1234567'), isNotNull);
        expect(Validators.otp('abcdef'), isNotNull);
      });
    });

    group('name', () {
      test('returns null for valid names', () {
        expect(Validators.name('John Doe'), isNull);
        expect(Validators.name('Dr. Smith'), isNull);
        expect(Validators.name("O'Brien"), isNull);
        expect(Validators.name('Mary-Jane'), isNull);
      });

      test('returns error for empty/null', () {
        expect(Validators.name(null), isNotNull);
        expect(Validators.name(''), isNotNull);
      });

      test('returns error for too short names', () {
        expect(Validators.name('A'), isNotNull);
      });

      test('returns error for names with numbers', () {
        expect(Validators.name('John123'), isNotNull);
      });
    });

    group('batchName', () {
      test('returns null for valid batch names', () {
        expect(Validators.batchName('Morning Batch'), isNull);
        expect(Validators.batchName('Ab'), isNull);
      });

      test('returns error for empty/null', () {
        expect(Validators.batchName(null), isNotNull);
        expect(Validators.batchName(''), isNotNull);
      });

      test('returns error for too short', () {
        expect(Validators.batchName('A'), isNotNull);
      });

      test('returns error for too long', () {
        expect(Validators.batchName('A' * 51), isNotNull);
      });
    });

    group('instituteName', () {
      test('returns null for valid names', () {
        expect(Validators.instituteName('Test Academy'), isNull);
      });

      test('returns error for too short', () {
        expect(Validators.instituteName('Ab'), isNotNull);
      });

      test('returns error for too long', () {
        expect(Validators.instituteName('A' * 101), isNotNull);
      });
    });

    group('combine', () {
      test('returns first error found', () {
        final error = Validators.combine('', [
          (v) => Validators.required(v),
          (v) => Validators.minLength(v, 3),
        ]);
        expect(error, contains('required'));
      });

      test('returns null when all pass', () {
        final error = Validators.combine('hello world', [
          (v) => Validators.required(v),
          (v) => Validators.minLength(v, 3),
        ]);
        expect(error, isNull);
      });
    });
  });
}
