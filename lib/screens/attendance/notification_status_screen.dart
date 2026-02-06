import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../utils/theme.dart';
import '../../models/models.dart';
import '../../providers/report_providers.dart';
import '../../widgets/common_widgets.dart';

/// Screen showing notification delivery status for an attendance record
class NotificationStatusScreen extends ConsumerWidget {
  final String instituteId;
  final String attendanceId;
  final String batchName;
  final DateTime date;

  const NotificationStatusScreen({
    super.key,
    required this.instituteId,
    required this.attendanceId,
    required this.batchName,
    required this.date,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(notificationStatusProvider((
      instituteId: instituteId,
      attendanceId: attendanceId,
    )));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notification Status'),
            Text(
              '$batchName - ${DateFormat('MMM d').format(date)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(notificationStatusProvider((
              instituteId: instituteId,
              attendanceId: attendanceId,
            ))),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: statusAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.notifications_off,
              title: 'No Notifications',
              subtitle: 'No students marked absent or late',
            );
          }

          // Calculate summary
          final pending = entries.where((e) => e.isPending).length;
          final sent = entries.where((e) => e.status == NotificationStatus.sent).length;
          final delivered = entries.where((e) => e.isDelivered).length;
          final failed = entries.where((e) => e.isFailed).length;

          return Column(
            children: [
              // Summary bar
              _buildSummaryBar(context, pending, sent, delivered, failed),

              // Status list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _NotificationStatusCard(
                      entry: entry,
                      instituteId: instituteId,
                      attendanceId: attendanceId,
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const ShimmerListLoading(type: ShimmerListType.simple, itemCount: 5),
        error: (error, stack) => ErrorStateWidget(
          error: error,
          onRetry: () => ref.invalidate(notificationStatusProvider((
            instituteId: instituteId,
            attendanceId: attendanceId,
          ))),
        ),
      ),
    );
  }

  Widget _buildSummaryBar(
    BuildContext context,
    int pending,
    int sent,
    int delivered,
    int failed,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(
            icon: Icons.schedule,
            label: 'Pending',
            count: pending,
            color: AppColors.pending,
          ),
          _SummaryItem(
            icon: Icons.send,
            label: 'Sent',
            count: sent,
            color: AppColors.sent,
          ),
          _SummaryItem(
            icon: Icons.done_all,
            label: 'Delivered',
            count: delivered,
            color: AppColors.delivered,
          ),
          _SummaryItem(
            icon: Icons.error_outline,
            label: 'Failed',
            count: failed,
            color: AppColors.failed,
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _NotificationStatusCard extends ConsumerStatefulWidget {
  final NotificationStatusEntry entry;
  final String instituteId;
  final String attendanceId;

  const _NotificationStatusCard({
    required this.entry,
    required this.instituteId,
    required this.attendanceId,
  });

  @override
  ConsumerState<_NotificationStatusCard> createState() => _NotificationStatusCardState();
}

class _NotificationStatusCardState extends ConsumerState<_NotificationStatusCard> {
  bool _isRetrying = false;

  Future<void> _retryNotification() async {
    setState(() => _isRetrying = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('retryNotification');

      await callable.call({
        'instituteId': widget.instituteId,
        'attendanceId': widget.attendanceId,
        'studentId': widget.entry.studentId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Retry initiated'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retry failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRetrying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final statusColor = _getStatusColor(entry.status);
    final statusIcon = _getStatusIcon(entry.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),

            // Student info and status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.studentName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _StatusChip(
                        status: entry.status,
                        channel: entry.channel,
                      ),
                      if (entry.sentAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('h:mm a').format(entry.sentAt!),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ],
                  ),
                  if (entry.error != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.error!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.error,
                            fontSize: 11,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Retry button for failed notifications
            if (entry.isFailed)
              _isRetrying
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.refresh),
                      color: AppColors.primary,
                      onPressed: _retryNotification,
                      tooltip: 'Retry',
                    ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(NotificationStatus status) {
    switch (status) {
      case NotificationStatus.pending:
        return AppColors.pending;
      case NotificationStatus.sent:
        return AppColors.sent;
      case NotificationStatus.delivered:
      case NotificationStatus.read:
        return AppColors.delivered;
      case NotificationStatus.failed:
        return AppColors.failed;
    }
  }

  IconData _getStatusIcon(NotificationStatus status) {
    switch (status) {
      case NotificationStatus.pending:
        return Icons.schedule;
      case NotificationStatus.sent:
        return Icons.done;
      case NotificationStatus.delivered:
      case NotificationStatus.read:
        return Icons.done_all;
      case NotificationStatus.failed:
        return Icons.error_outline;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final NotificationStatus status;
  final NotificationChannel channel;

  const _StatusChip({
    required this.status,
    required this.channel,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final label = _getLabel();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (channel != NotificationChannel.none) ...[
            Icon(
              channel == NotificationChannel.whatsapp
                  ? Icons.chat
                  : Icons.sms,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor() {
    switch (status) {
      case NotificationStatus.pending:
        return AppColors.pending;
      case NotificationStatus.sent:
        return AppColors.sent;
      case NotificationStatus.delivered:
      case NotificationStatus.read:
        return AppColors.delivered;
      case NotificationStatus.failed:
        return AppColors.failed;
    }
  }

  String _getLabel() {
    switch (status) {
      case NotificationStatus.pending:
        return 'Pending';
      case NotificationStatus.sent:
        return 'Sent';
      case NotificationStatus.delivered:
        return 'Delivered';
      case NotificationStatus.read:
        return 'Read';
      case NotificationStatus.failed:
        return 'Failed';
    }
  }
}
