import 'package:flutter_test/flutter_test.dart';
import 'package:classpulse/utils/helpers.dart';

void main() {
  group('DateHelpers', () {
    group('isToday', () {
      test('returns true for today', () {
        expect(DateHelpers.isToday(DateTime.now()), true);
      });

      test('returns false for yesterday', () {
        expect(DateHelpers.isToday(DateTime.now().subtract(const Duration(days: 1))), false);
      });

      test('returns false for tomorrow', () {
        expect(DateHelpers.isToday(DateTime.now().add(const Duration(days: 1))), false);
      });
    });

    group('isYesterday', () {
      test('returns true for yesterday', () {
        expect(DateHelpers.isYesterday(DateTime.now().subtract(const Duration(days: 1))), true);
      });

      test('returns false for today', () {
        expect(DateHelpers.isYesterday(DateTime.now()), false);
      });
    });

    group('daysInMonth', () {
      test('returns correct days for regular months', () {
        expect(DateHelpers.daysInMonth(2024, 1), 31); // January
        expect(DateHelpers.daysInMonth(2024, 4), 30); // April
        expect(DateHelpers.daysInMonth(2024, 6), 30); // June
        expect(DateHelpers.daysInMonth(2024, 12), 31); // December
      });

      test('returns 29 for February in leap year', () {
        expect(DateHelpers.daysInMonth(2024, 2), 29);
        expect(DateHelpers.daysInMonth(2000, 2), 29);
      });

      test('returns 28 for February in non-leap year', () {
        expect(DateHelpers.daysInMonth(2023, 2), 28);
        expect(DateHelpers.daysInMonth(2100, 2), 28);
      });
    });

    group('startOfDay', () {
      test('returns midnight of the same day', () {
        final date = DateTime(2024, 6, 15, 14, 30, 45);
        final start = DateHelpers.startOfDay(date);

        expect(start.year, 2024);
        expect(start.month, 6);
        expect(start.day, 15);
        expect(start.hour, 0);
        expect(start.minute, 0);
        expect(start.second, 0);
      });
    });

    group('endOfDay', () {
      test('returns 23:59:59.999 of the same day', () {
        final date = DateTime(2024, 6, 15, 14, 30, 45);
        final end = DateHelpers.endOfDay(date);

        expect(end.year, 2024);
        expect(end.month, 6);
        expect(end.day, 15);
        expect(end.hour, 23);
        expect(end.minute, 59);
        expect(end.second, 59);
        expect(end.millisecond, 999);
      });
    });

    group('relativeTime', () {
      test('returns "Just now" for recent times', () {
        final recent = DateTime.now().subtract(const Duration(seconds: 30));
        expect(DateHelpers.relativeTime(recent), 'Just now');
      });

      test('returns minutes for < 1 hour', () {
        final minutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
        expect(DateHelpers.relativeTime(minutesAgo), '5 minutes ago');
      });

      test('returns singular "minute" for 1 minute', () {
        final oneMin = DateTime.now().subtract(const Duration(minutes: 1));
        expect(DateHelpers.relativeTime(oneMin), '1 minute ago');
      });

      test('returns hours for < 24 hours', () {
        final hoursAgo = DateTime.now().subtract(const Duration(hours: 3));
        expect(DateHelpers.relativeTime(hoursAgo), '3 hours ago');
      });

      test('returns "Yesterday" for yesterday', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        expect(DateHelpers.relativeTime(yesterday), 'Yesterday');
      });

      test('returns days for < 7 days', () {
        final daysAgo = DateTime.now().subtract(const Duration(days: 5));
        expect(DateHelpers.relativeTime(daysAgo), '5 days ago');
      });
    });
  });

  group('PhoneHelpers', () {
    group('formatForDisplay', () {
      test('formats 10-digit number', () {
        expect(PhoneHelpers.formatForDisplay('9876543210'), '+91 98765 43210');
      });

      test('formats 12-digit number with 91 prefix', () {
        expect(PhoneHelpers.formatForDisplay('919876543210'), '+91 98765 43210');
      });

      test('returns original for unexpected format', () {
        expect(PhoneHelpers.formatForDisplay('12345'), '12345');
      });

      test('strips non-numeric characters', () {
        expect(PhoneHelpers.formatForDisplay('+91 98765 43210'), '+91 98765 43210');
      });
    });

    group('formatForWhatsApp', () {
      test('formats 10-digit number', () {
        expect(PhoneHelpers.formatForWhatsApp('9876543210'), '919876543210');
      });

      test('preserves 12-digit number with 91', () {
        expect(PhoneHelpers.formatForWhatsApp('919876543210'), '919876543210');
      });

      test('handles already formatted number', () {
        expect(PhoneHelpers.formatForWhatsApp('+919876543210'), '919876543210');
      });
    });

    group('formatWithCountryCode', () {
      test('adds +91 to 10-digit number', () {
        expect(PhoneHelpers.formatWithCountryCode('9876543210'), '+919876543210');
      });

      test('adds + to 12-digit with 91', () {
        expect(PhoneHelpers.formatWithCountryCode('919876543210'), '+919876543210');
      });

      test('returns original for unexpected format', () {
        expect(PhoneHelpers.formatWithCountryCode('12345'), '12345');
      });
    });
  });

  group('StringHelpers', () {
    group('capitalizeWords', () {
      test('capitalizes first letter of each word', () {
        expect(StringHelpers.capitalizeWords('hello world'), 'Hello World');
        expect(StringHelpers.capitalizeWords('JOHN DOE'), 'John Doe');
      });

      test('handles empty string', () {
        expect(StringHelpers.capitalizeWords(''), '');
      });

      test('handles single word', () {
        expect(StringHelpers.capitalizeWords('hello'), 'Hello');
      });
    });

    group('getInitials', () {
      test('returns initials from name', () {
        expect(StringHelpers.getInitials('John Doe'), 'JD');
        expect(StringHelpers.getInitials('Rahul Kumar Sharma'), 'RK');
      });

      test('handles single name', () {
        expect(StringHelpers.getInitials('Rahul'), 'R');
      });

      test('handles empty string', () {
        expect(StringHelpers.getInitials(''), '');
      });

      test('respects maxLength', () {
        expect(StringHelpers.getInitials('A B C D', maxLength: 3), 'ABC');
      });
    });

    group('truncate', () {
      test('truncates long text', () {
        expect(StringHelpers.truncate('Hello World', 8), 'Hello...');
      });

      test('does not truncate short text', () {
        expect(StringHelpers.truncate('Hello', 10), 'Hello');
      });
    });

    group('toKebabCase', () {
      test('converts to kebab case', () {
        expect(StringHelpers.toKebabCase('Hello World'), 'hello-world');
      });

      test('handles special characters', () {
        expect(StringHelpers.toKebabCase('Hello, World!'), 'hello-world');
      });
    });

    group('pluralize', () {
      test('returns singular for count 1', () {
        expect(StringHelpers.pluralize(1, 'student'), 'student');
      });

      test('returns plural for other counts', () {
        expect(StringHelpers.pluralize(0, 'student'), 'students');
        expect(StringHelpers.pluralize(5, 'student'), 'students');
      });

      test('uses custom plural form', () {
        expect(StringHelpers.pluralize(5, 'child', plural: 'children'), 'children');
      });
    });
  });

  group('NumberHelpers', () {
    group('formatWithCommas', () {
      test('adds commas to large numbers', () {
        expect(NumberHelpers.formatWithCommas(1234567), '1,234,567');
      });

      test('handles small numbers', () {
        expect(NumberHelpers.formatWithCommas(100), '100');
      });
    });

    group('formatPercent', () {
      test('formats fraction as percentage', () {
        expect(NumberHelpers.formatPercent(0.85), '85%');
      });

      test('respects decimal places', () {
        expect(NumberHelpers.formatPercent(0.856, decimals: 1), '85.6%');
      });
    });

    group('formatCurrency', () {
      test('formats as INR', () {
        final result = NumberHelpers.formatCurrency(5000);
        expect(result, contains('5,000'));
      });
    });
  });

  group('ErrorHelpers', () {
    test('network errors', () {
      final msg = ErrorHelpers.getUserFriendlyMessage('SocketException: connection failed');
      expect(msg, contains('internet'));
    });

    test('permission errors', () {
      final msg = ErrorHelpers.getUserFriendlyMessage('permission-denied');
      expect(msg, contains('permission'));
    });

    test('not found errors', () {
      final msg = ErrorHelpers.getUserFriendlyMessage('not-found');
      expect(msg, contains('not be found'));
    });

    test('timeout errors', () {
      final msg = ErrorHelpers.getUserFriendlyMessage('request timed out');
      expect(msg, contains('timed out'));
    });

    test('firebase unavailable', () {
      final msg = ErrorHelpers.getUserFriendlyMessage('firebase: unavailable');
      expect(msg, contains('temporarily unavailable'));
    });

    test('generic fallback', () {
      final msg = ErrorHelpers.getUserFriendlyMessage('some unknown error');
      expect(msg, contains('Something went wrong'));
    });

    test('getActionError includes action name', () {
      final msg = ErrorHelpers.getActionError('save student', 'network error');
      expect(msg, contains('save student'));
    });
  });
}
