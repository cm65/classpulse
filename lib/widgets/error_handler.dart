import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../utils/helpers.dart';

/// Global error handler that shows friendly error messages via SnackBar.
/// Wrap screens or scaffold bodies with this to catch and display errors.
class GlobalErrorHandler {
  GlobalErrorHandler._();

  /// Show a user-friendly error SnackBar and log to Crashlytics
  static void showError(
    BuildContext context,
    dynamic error, {
    String? action,
    String? screen,
  }) {
    final message = action != null
        ? ErrorHelpers.getActionError(action, error)
        : ErrorHelpers.getUserFriendlyMessage(error);

    // Log to Crashlytics with context
    FirebaseCrashlytics.instance.recordError(
      error,
      StackTrace.current,
      reason: 'UI error${screen != null ? ' on $screen' : ''}',
      fatal: false,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Dismiss',
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }
}
