import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Date and time formatting helpers
class DateHelpers {
  /// Format date as "Mon, 15 Jan 2024"
  static String formatDate(DateTime date) {
    return DateFormat('EEE, d MMM yyyy').format(date);
  }

  /// Format date as "15 Jan 2024"
  static String formatShortDate(DateTime date) {
    return DateFormat('d MMM yyyy').format(date);
  }

  /// Format date as "January 15, 2024"
  static String formatLongDate(DateTime date) {
    return DateFormat('MMMM d, yyyy').format(date);
  }

  /// Format time as "09:30 AM"
  static String formatTime(DateTime time) {
    return DateFormat('hh:mm a').format(time);
  }

  /// Format TimeOfDay as "09:30 AM"
  static String formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('hh:mm a').format(dt);
  }

  /// Format datetime as "15 Jan 2024, 09:30 AM"
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('d MMM yyyy, hh:mm a').format(dateTime);
  }

  /// Get relative time string (e.g., "2 hours ago", "Yesterday")
  static String relativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else {
      return formatShortDate(dateTime);
    }
  }

  /// Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Check if date is yesterday
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  /// Get start of day (midnight)
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Get end of day (23:59:59.999)
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  /// Get days in month
  static int daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }
}

/// Phone number formatting helpers
class PhoneHelpers {
  /// Format phone number for display (e.g., "+91 98765 43210")
  static String formatForDisplay(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length == 10) {
      return '+91 ${cleaned.substring(0, 5)} ${cleaned.substring(5)}';
    }
    if (cleaned.length == 12 && cleaned.startsWith('91')) {
      return '+${cleaned.substring(0, 2)} ${cleaned.substring(2, 7)} ${cleaned.substring(7)}';
    }
    return phone;
  }

  /// Format phone number for WhatsApp API (e.g., "919876543210")
  static String formatForWhatsApp(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length == 10) {
      return '91$cleaned';
    }
    if (cleaned.length == 12 && cleaned.startsWith('91')) {
      return cleaned;
    }
    return cleaned;
  }

  /// Format phone number with +91 prefix
  static String formatWithCountryCode(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length == 10) {
      return '+91$cleaned';
    }
    if (cleaned.length == 12 && cleaned.startsWith('91')) {
      return '+$cleaned';
    }
    return phone;
  }
}

/// String manipulation helpers
class StringHelpers {
  /// Capitalize first letter of each word
  static String capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Get initials from name (e.g., "John Doe" -> "JD")
  static String getInitials(String name, {int maxLength = 2}) {
    if (name.isEmpty) return '';
    final words = name.trim().split(' ');
    final initials = words
        .where((word) => word.isNotEmpty)
        .take(maxLength)
        .map((word) => word[0].toUpperCase())
        .join('');
    return initials;
  }

  /// Truncate text with ellipsis
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  /// Convert to kebab-case (e.g., "Hello World" -> "hello-world")
  static String toKebabCase(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
  }

  /// Pluralize word based on count
  static String pluralize(int count, String singular, {String? plural}) {
    if (count == 1) return singular;
    return plural ?? '${singular}s';
  }
}

/// Number formatting helpers
class NumberHelpers {
  /// Format number with commas (e.g., 1234567 -> "1,234,567")
  static String formatWithCommas(num number) {
    return NumberFormat('#,##0').format(number);
  }

  /// Format percentage (e.g., 0.85 -> "85%")
  static String formatPercent(double value, {int decimals = 0}) {
    return '${(value * 100).toStringAsFixed(decimals)}%';
  }

  /// Format as currency (INR)
  static String formatCurrency(num amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(amount);
  }

  /// Format as compact number (e.g., 1500 -> "1.5K")
  static String formatCompact(num number) {
    return NumberFormat.compact().format(number);
  }
}

/// User-friendly error message helpers
class ErrorHelpers {
  /// Convert technical errors to user-friendly messages
  static String getUserFriendlyMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Network errors
    if (errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('connection')) {
      return 'No internet connection. Please check your network and try again.';
    }

    // Permission errors
    if (errorString.contains('permission') || errorString.contains('denied')) {
      return 'You don\'t have permission to perform this action.';
    }

    // Not found errors
    if (errorString.contains('not found') || errorString.contains('not-found')) {
      return 'The requested item could not be found.';
    }

    // Timeout errors
    if (errorString.contains('timeout') || errorString.contains('timed out')) {
      return 'The request timed out. Please try again.';
    }

    // Firebase errors
    if (errorString.contains('firebase')) {
      if (errorString.contains('unavailable')) {
        return 'Service temporarily unavailable. Please try again later.';
      }
      if (errorString.contains('cancelled')) {
        return 'Operation was cancelled.';
      }
    }

    // Generic fallback
    return 'Something went wrong. Please try again.';
  }

  /// Get action-specific error message
  static String getActionError(String action, dynamic error) {
    final userMessage = getUserFriendlyMessage(error);
    return 'Unable to $action. $userMessage';
  }
}

/// Custom page transitions for smoother navigation
class PageTransitions {
  /// Slide-right transition (default for detail screens)
  static Route<T> slideRight<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 250),
    );
  }

  /// Fade-scale transition (for dialogs and modals)
  static Route<T> fadeScale<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeOut;
        final fadeAnimation = CurvedAnimation(parent: animation, curve: curve);
        final scaleAnimation = Tween(begin: 0.9, end: 1.0).animate(fadeAnimation);
        return FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(scale: scaleAnimation, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 200),
    );
  }

  /// Slide-up transition (for bottom sheets and iOS-style pushes)
  static Route<T> slideUp<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
