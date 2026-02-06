import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../providers/parent_providers.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';

/// Screen for teachers to review and manage leave requests
class LeaveRequestsScreen extends ConsumerWidget {
  final String instituteId;
  final String teacherId;
  final String? batchId; // Optional - filter by batch

  const LeaveRequestsScreen({
    super.key,
    required this.instituteId,
    required this.teacherId,
    this.batchId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = batchId != null
        ? ref.watch(batchLeaveRequestsProvider(batchId!))
        : ref.watch(pendingLeaveRequestsProvider(instituteId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Requests'),
      ),
      body: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.event_busy,
              title: 'No Leave Requests',
              subtitle: 'There are no pending leave requests to review',
            );
          }

          // Group by status
          final pending = requests.where((r) => r.isPending).toList();
          final reviewed = requests.where((r) => !r.isPending).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (pending.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Pending Review',
                  count: pending.length,
                  color: Colors.orange,
                ),
                const SizedBox(height: 8),
                ...pending.map((r) => _LeaveRequestCard(
                      request: r,
                      teacherId: teacherId,
                      instituteId: instituteId,
                    )),
                const SizedBox(height: 24),
              ],
              if (reviewed.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Reviewed',
                  count: reviewed.length,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 8),
                ...reviewed.take(10).map((r) => _LeaveRequestCard(
                      request: r,
                      teacherId: teacherId,
                      instituteId: instituteId,
                      isReviewed: true,
                    )),
              ],
            ],
          );
        },
        loading: () => const ShimmerListLoading(type: ShimmerListType.batch),
        error: (error, stack) => ErrorStateWidget(
          error: error,
          onRetry: () {
            if (batchId != null) {
              ref.invalidate(batchLeaveRequestsProvider(batchId!));
            } else {
              ref.invalidate(pendingLeaveRequestsProvider(instituteId));
            }
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaveRequestCard extends ConsumerStatefulWidget {
  final LeaveRequest request;
  final String teacherId;
  final String instituteId;
  final bool isReviewed;

  const _LeaveRequestCard({
    required this.request,
    required this.teacherId,
    required this.instituteId,
    this.isReviewed = false,
  });

  @override
  ConsumerState<_LeaveRequestCard> createState() => _LeaveRequestCardState();
}

class _LeaveRequestCardState extends ConsumerState<_LeaveRequestCard> {
  bool _isExpanded = false;

  Color get _statusColor {
    switch (widget.request.status) {
      case LeaveRequestStatus.pending:
        return Colors.orange;
      case LeaveRequestStatus.approved:
        return AppColors.present;
      case LeaveRequestStatus.rejected:
        return AppColors.absent;
      case LeaveRequestStatus.cancelled:
        return AppColors.textSecondary;
    }
  }

  IconData get _statusIcon {
    switch (widget.request.status) {
      case LeaveRequestStatus.pending:
        return Icons.pending_actions;
      case LeaveRequestStatus.approved:
        return Icons.check_circle;
      case LeaveRequestStatus.rejected:
        return Icons.cancel;
      case LeaveRequestStatus.cancelled:
        return Icons.block;
    }
  }

  Future<void> _showReviewDialog(bool approve) async {
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Approve Leave' : 'Reject Leave'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              approve
                  ? 'Approve this leave request?'
                  : 'Are you sure you want to reject this request?',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Add any notes for the parent...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? AppColors.present : AppColors.absent,
            ),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      bool success;
      if (approve) {
        success = await ref.read(leaveReviewNotifierProvider.notifier).approveLeaveRequest(
              requestId: widget.request.id,
              reviewerId: widget.teacherId,
              notes: notesController.text.isNotEmpty ? notesController.text : null,
            );
      } else {
        success = await ref.read(leaveReviewNotifierProvider.notifier).rejectLeaveRequest(
              requestId: widget.request.id,
              reviewerId: widget.teacherId,
              notes: notesController.text.isNotEmpty ? notesController.text : null,
            );
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Leave request approved' : 'Leave request rejected'),
            backgroundColor: approve ? Colors.green : Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_statusIcon, color: _statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.request.type.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${widget.request.durationDays} day${widget.request.durationDays > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.request.status.displayName,
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Date range
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.date_range, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      widget.request.isSingleDay
                          ? DateFormat('EEEE, MMM d, yyyy').format(widget.request.startDate)
                          : '${DateFormat('MMM d').format(widget.request.startDate)} - ${DateFormat('MMM d, yyyy').format(widget.request.endDate)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              // Expanded details
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                Text(
                  'Reason:',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(widget.request.reason),
                if (widget.request.reviewNotes != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Review Notes:',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.request.reviewNotes!,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],

              // Action buttons for pending
              if (widget.request.isPending) ...[
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showReviewDialog(false),
                      icon: Icon(Icons.close, color: AppColors.absent, size: 18),
                      label: Text('Reject', style: TextStyle(color: AppColors.absent)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.absent),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showReviewDialog(true),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.present,
                      ),
                    ),
                  ],
                ),
              ],

              // Expand indicator
              if (!widget.request.isPending) ...[
                const SizedBox(height: 8),
                Center(
                  child: Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
