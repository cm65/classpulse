import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../utils/theme.dart';

/// Responsive layout that shows single-pane on phones (<600dp)
/// and two-pane side-by-side on tablets (>=600dp).
class ResponsiveLayout extends StatelessWidget {
  /// The primary content (list or main view). Always shown.
  final Widget primaryPane;

  /// The detail content. Shown side-by-side on tablet, or navigated to on phone.
  final Widget? detailPane;

  /// Breakpoint width for switching to two-pane layout.
  static const double tabletBreakpoint = 600;

  const ResponsiveLayout({
    super.key,
    required this.primaryPane,
    this.detailPane,
  });

  /// Returns true if the current width supports a two-pane layout.
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.shortestSide >= tabletBreakpoint;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= tabletBreakpoint && detailPane != null) {
          // Two-pane layout for tablets
          return Row(
            children: [
              SizedBox(
                width: constraints.maxWidth * 0.38,
                child: primaryPane,
              ),
              const VerticalDivider(width: 1),
              Expanded(child: detailPane!),
            ],
          );
        }
        // Single-pane for phones
        return primaryPane;
      },
    );
  }
}

/// Loading button with spinner
class LoadingButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final Widget child;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const LoadingButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.child,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
      ),
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : child,
    );
  }
}

/// Offline banner with optional last synced time
class OfflineBanner extends StatelessWidget {
  final DateTime? lastOnlineAt;

  const OfflineBanner({
    super.key,
    this.lastOnlineAt,
  });

  String _getLastSyncedText() {
    if (lastOnlineAt == null) return '';

    final now = DateTime.now();
    final diff = now.difference(lastOnlineAt!);

    if (diff.inMinutes < 1) return 'Synced just now';
    if (diff.inMinutes < 60) return 'Synced ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Synced ${diff.inHours}h ago';
    return 'Synced ${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final lastSyncText = _getLastSyncedText();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: AppColors.warning,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, size: 16, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'You are offline. Changes will sync when connected.',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          if (lastSyncText.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              lastSyncText,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Empty state widget
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Attendance status chip
class AttendanceStatusChip extends StatelessWidget {
  final String status;
  final bool large;

  const AttendanceStatusChip({
    super.key,
    required this.status,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = status.attendanceColor;
    final bgColor = status.attendanceBackgroundColor;
    final icon = _getIcon();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 16 : 12,
        vertical: large ? 8 : 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(large ? 12 : 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: large ? 20 : 16, color: color),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: large ? 14 : 12,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon() {
    switch (status.toLowerCase()) {
      case 'present':
        return Icons.check_circle;
      case 'absent':
        return Icons.cancel;
      case 'late':
        return Icons.access_time;
      default:
        return Icons.help_outline;
    }
  }
}

/// Notification status indicator
class NotificationStatusIndicator extends StatelessWidget {
  final String status;
  final String channel;

  const NotificationStatusIndicator({
    super.key,
    required this.status,
    required this.channel,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final icon = _getIcon();
    final label = _getLabel();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Color _getColor() {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'read':
        return AppColors.delivered;
      case 'sent':
        return AppColors.sent;
      case 'failed':
        return AppColors.failed;
      default:
        return AppColors.pending;
    }
  }

  IconData _getIcon() {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'read':
        return Icons.done_all;
      case 'sent':
        return Icons.done;
      case 'failed':
        return Icons.error_outline;
      default:
        return Icons.schedule;
    }
  }

  String _getLabel() {
    final channelLabel = channel.isNotEmpty ? ' ($channel)' : '';
    switch (status.toLowerCase()) {
      case 'delivered':
        return 'Delivered$channelLabel';
      case 'read':
        return 'Read$channelLabel';
      case 'sent':
        return 'Sent$channelLabel';
      case 'failed':
        return 'Failed$channelLabel';
      default:
        return 'Pending';
    }
  }
}

/// Summary card
class SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textHint,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirmation dialog
Future<bool> showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
  bool isDangerous = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: isDangerous
              ? ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                )
              : null,
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Loading overlay
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      if (message != null) ...[
                        const SizedBox(height: 16),
                        Text(message!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ==================== SHIMMER LOADING WIDGETS ====================

/// Shimmer placeholder box for building custom skeletons
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Shimmer loading for list items (student/batch cards)
class ShimmerListItem extends StatelessWidget {
  final bool showSubtitle;
  final bool showTrailing;

  const ShimmerListItem({
    super.key,
    this.showSubtitle = true,
    this.showTrailing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar placeholder
              const ShimmerBox(width: 48, height: 48, borderRadius: 24),
              const SizedBox(width: 12),
              // Text placeholders
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ShimmerBox(width: 140, height: 16),
                    if (showSubtitle) ...[
                      const SizedBox(height: 8),
                      const ShimmerBox(width: 100, height: 12),
                    ],
                  ],
                ),
              ),
              if (showTrailing) ...[
                const SizedBox(width: 8),
                const ShimmerBox(width: 24, height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmer loading for batch cards
class ShimmerBatchCard extends StatelessWidget {
  const ShimmerBatchCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon placeholder
              const ShimmerBox(width: 56, height: 56, borderRadius: 12),
              const SizedBox(width: 16),
              // Text placeholders
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ShimmerBox(width: 160, height: 18),
                    const SizedBox(height: 8),
                    const ShimmerBox(width: 100, height: 12),
                    const SizedBox(height: 6),
                    const ShimmerBox(width: 140, height: 12),
                  ],
                ),
              ),
              const ShimmerBox(width: 24, height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmer loading for summary cards
class ShimmerSummaryCard extends StatelessWidget {
  const ShimmerSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const ShimmerBox(width: 40, height: 40, borderRadius: 8),
                  const Spacer(),
                  const ShimmerBox(width: 16, height: 16),
                ],
              ),
              const SizedBox(height: 12),
              const ShimmerBox(width: 60, height: 32),
              const SizedBox(height: 4),
              const ShimmerBox(width: 80, height: 14),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading state for lists - shows multiple shimmer items
class ShimmerListLoading extends StatelessWidget {
  final int itemCount;
  final ShimmerListType type;

  const ShimmerListLoading({
    super.key,
    this.itemCount = 5,
    this.type = ShimmerListType.student,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        switch (type) {
          case ShimmerListType.student:
            return const ShimmerListItem(showSubtitle: true, showTrailing: true);
          case ShimmerListType.batch:
            return const ShimmerBatchCard();
          case ShimmerListType.simple:
            return const ShimmerListItem(showSubtitle: false, showTrailing: false);
        }
      },
    );
  }
}

/// Types of shimmer list loading
enum ShimmerListType {
  student,
  batch,
  simple,
}

// ==================== ERROR STATE WIDGETS ====================

/// Categories of errors for appropriate messaging
enum ErrorCategory {
  network,
  authentication,
  permission,
  notFound,
  server,
  validation,
  unknown,
}

/// Helper to categorize errors based on error message/type
class ErrorCategorizer {
  static ErrorCategory categorize(Object error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('no internet') ||
        errorString.contains('failed host lookup')) {
      return ErrorCategory.network;
    }

    if (errorString.contains('permission') ||
        errorString.contains('denied') ||
        errorString.contains('unauthorized') ||
        errorString.contains('forbidden')) {
      return ErrorCategory.permission;
    }

    if (errorString.contains('unauthenticated') ||
        errorString.contains('sign in') ||
        errorString.contains('login') ||
        errorString.contains('session expired')) {
      return ErrorCategory.authentication;
    }

    if (errorString.contains('not found') ||
        errorString.contains('does not exist') ||
        errorString.contains('no document')) {
      return ErrorCategory.notFound;
    }

    if (errorString.contains('invalid') ||
        errorString.contains('validation') ||
        errorString.contains('required')) {
      return ErrorCategory.validation;
    }

    if (errorString.contains('server') ||
        errorString.contains('500') ||
        errorString.contains('internal error') ||
        errorString.contains('unavailable')) {
      return ErrorCategory.server;
    }

    return ErrorCategory.unknown;
  }

  /// Get user-friendly title for error category
  static String getTitle(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
        return 'Connection Problem';
      case ErrorCategory.authentication:
        return 'Sign In Required';
      case ErrorCategory.permission:
        return 'Access Denied';
      case ErrorCategory.notFound:
        return 'Not Found';
      case ErrorCategory.server:
        return 'Server Error';
      case ErrorCategory.validation:
        return 'Invalid Data';
      case ErrorCategory.unknown:
        return 'Something Went Wrong';
    }
  }

  /// Get user-friendly message for error category
  static String getMessage(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
        return 'Unable to connect. Please check your internet connection and try again.';
      case ErrorCategory.authentication:
        return 'Your session has expired. Please sign in again to continue.';
      case ErrorCategory.permission:
        return 'You don\'t have permission to access this. Contact your administrator if you think this is a mistake.';
      case ErrorCategory.notFound:
        return 'The requested data could not be found. It may have been deleted or moved.';
      case ErrorCategory.server:
        return 'Our servers are having trouble right now. Please try again in a few minutes.';
      case ErrorCategory.validation:
        return 'Some of the data is invalid. Please check your input and try again.';
      case ErrorCategory.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Get appropriate icon for error category
  static IconData getIcon(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
        return Icons.wifi_off_rounded;
      case ErrorCategory.authentication:
        return Icons.lock_outline_rounded;
      case ErrorCategory.permission:
        return Icons.block_rounded;
      case ErrorCategory.notFound:
        return Icons.search_off_rounded;
      case ErrorCategory.server:
        return Icons.cloud_off_rounded;
      case ErrorCategory.validation:
        return Icons.error_outline_rounded;
      case ErrorCategory.unknown:
        return Icons.warning_amber_rounded;
    }
  }

  /// Get recovery action label for error category
  static String getRecoveryLabel(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
        return 'Try Again';
      case ErrorCategory.authentication:
        return 'Sign In';
      case ErrorCategory.permission:
        return 'Go Back';
      case ErrorCategory.notFound:
        return 'Go Back';
      case ErrorCategory.server:
        return 'Try Again';
      case ErrorCategory.validation:
        return 'Fix & Retry';
      case ErrorCategory.unknown:
        return 'Try Again';
    }
  }
}

/// Beautiful error state widget with categorized messages and recovery actions
class ErrorStateWidget extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  final VoidCallback? onSignIn;
  final bool compact;

  const ErrorStateWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.onSignIn,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final category = ErrorCategorizer.categorize(error);
    final title = ErrorCategorizer.getTitle(category);
    final message = ErrorCategorizer.getMessage(category);
    final icon = ErrorCategorizer.getIcon(category);
    final recoveryLabel = ErrorCategorizer.getRecoveryLabel(category);

    if (compact) {
      return _buildCompact(context, category, title, message, icon, recoveryLabel);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildRecoveryButton(context, category, recoveryLabel),
            if (category != ErrorCategory.unknown) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _showErrorDetails(context),
                icon: const Icon(Icons.info_outline, size: 16),
                label: const Text('View Details'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textHint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompact(
    BuildContext context,
    ErrorCategory category,
    String title,
    String message,
    IconData icon,
    String recoveryLabel,
  ) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: AppColors.error.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.error, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _getRecoveryAction(category),
              child: Text(recoveryLabel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryButton(
    BuildContext context,
    ErrorCategory category,
    String label,
  ) {
    final action = _getRecoveryAction(category);

    if (action == null) {
      return const SizedBox.shrink();
    }

    if (category == ErrorCategory.authentication && onSignIn != null) {
      return ElevatedButton.icon(
        onPressed: onSignIn,
        icon: const Icon(Icons.login),
        label: Text(label),
      );
    }

    return ElevatedButton.icon(
      onPressed: action,
      icon: Icon(
        category == ErrorCategory.permission || category == ErrorCategory.notFound
            ? Icons.arrow_back
            : Icons.refresh,
      ),
      label: Text(label),
    );
  }

  VoidCallback? _getRecoveryAction(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.authentication:
        return onSignIn;
      case ErrorCategory.permission:
      case ErrorCategory.notFound:
        return onRetry;
      default:
        return onRetry;
    }
  }

  void _showErrorDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error Details'),
        content: SingleChildScrollView(
          child: SelectableText(
            error.toString(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
