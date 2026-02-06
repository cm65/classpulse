import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../providers/parent_providers.dart';
import '../../utils/theme.dart';
import 'leave_request_screen.dart';

/// Detailed view of a child's attendance and performance
class ChildDetailScreen extends ConsumerWidget {
  final ChildSummary child;
  final Parent parent;

  const ChildDetailScreen({
    super.key,
    required this.child,
    required this.parent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaveRequestsAsync = ref.watch(studentLeaveRequestsProvider(child.studentId));

    return Scaffold(
      appBar: AppBar(
        title: Text(child.studentName),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student info card
            _StudentInfoCard(child: child),
            const SizedBox(height: 20),

            // Attendance overview
            _AttendanceOverview(child: child),
            const SizedBox(height: 20),

            // Recent attendance
            Text(
              'Recent Attendance',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _RecentAttendanceList(recentAttendance: child.recentAttendance),
            const SizedBox(height: 20),

            // Leave requests
            Text(
              'Leave Requests',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            leaveRequestsAsync.when(
              data: (requests) => _LeaveRequestsList(requests: requests),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Text('Error loading leave requests'),
            ),
            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LeaveRequestScreen(
              child: child,
              parent: parent,
            ),
          ),
        ),
        icon: const Icon(Icons.event_busy),
        label: const Text('Request Leave'),
      ),
    );
  }
}

class _StudentInfoCard extends StatelessWidget {
  final ChildSummary child;

  const _StudentInfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                child.studentName.isNotEmpty ? child.studentName[0].toUpperCase() : '?',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.studentName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.class_, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        child.batchName,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  if (child.classRank != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.emoji_events, size: 16, color: Colors.amber.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Class Rank: #${child.classRank}',
                          style: TextStyle(
                            color: Colors.amber.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceOverview extends StatelessWidget {
  final ChildSummary child;

  const _AttendanceOverview({required this.child});

  @override
  Widget build(BuildContext context) {
    final percentage = child.attendancePercentage;
    Color percentColor;
    String status;

    if (percentage >= 85) {
      percentColor = AppColors.present;
      status = 'Excellent';
    } else if (percentage >= 75) {
      percentColor = AppColors.late;
      status = 'Good';
    } else if (percentage >= 60) {
      percentColor = Colors.orange;
      status = 'Needs Improvement';
    } else {
      percentColor = AppColors.absent;
      status = 'Critical';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Attendance Overview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: percentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: percentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Percentage circle
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: percentage / 100,
                      strokeWidth: 10,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(percentColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: percentColor,
                        ),
                      ),
                      Text(
                        'Attendance',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _AttendanceStat(
                  label: 'Total Classes',
                  value: '${child.totalClasses}',
                  color: AppColors.textSecondary,
                ),
                _AttendanceStat(
                  label: 'Present',
                  value: '${child.presentDays}',
                  color: AppColors.present,
                ),
                _AttendanceStat(
                  label: 'Absent',
                  value: '${child.absentDays}',
                  color: AppColors.absent,
                ),
                _AttendanceStat(
                  label: 'Late',
                  value: '${child.lateDays}',
                  color: AppColors.late,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AttendanceStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _RecentAttendanceList extends StatelessWidget {
  final List<RecentAttendance> recentAttendance;

  const _RecentAttendanceList({required this.recentAttendance});

  @override
  Widget build(BuildContext context) {
    if (recentAttendance.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No recent attendance records.'),
        ),
      );
    }

    return Card(
      child: Column(
        children: recentAttendance.take(7).map((record) {
          Color statusColor;
          IconData statusIcon;

          switch (record.status.toLowerCase()) {
            case 'present':
              statusColor = AppColors.present;
              statusIcon = Icons.check_circle;
              break;
            case 'absent':
              statusColor = AppColors.absent;
              statusIcon = Icons.cancel;
              break;
            case 'late':
              statusColor = AppColors.late;
              statusIcon = Icons.schedule;
              break;
            case 'excused':
              statusColor = Colors.blue;
              statusIcon = Icons.info;
              break;
            default:
              statusColor = AppColors.textSecondary;
              statusIcon = Icons.help;
          }

          return ListTile(
            leading: Icon(statusIcon, color: statusColor),
            title: Text(DateFormat('EEEE, MMM d').format(record.date)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                record.status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            subtitle: record.remarks != null
                ? Text(
                    record.remarks!,
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  )
                : null,
          );
        }).toList(),
      ),
    );
  }
}

class _LeaveRequestsList extends StatelessWidget {
  final List<LeaveRequest> requests;

  const _LeaveRequestsList({required this.requests});

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No leave requests yet.'),
        ),
      );
    }

    return Card(
      child: Column(
        children: requests.take(5).map((request) {
          Color statusColor;
          IconData statusIcon;

          switch (request.status) {
            case LeaveRequestStatus.pending:
              statusColor = Colors.orange;
              statusIcon = Icons.pending_actions;
              break;
            case LeaveRequestStatus.approved:
              statusColor = AppColors.present;
              statusIcon = Icons.check_circle;
              break;
            case LeaveRequestStatus.rejected:
              statusColor = AppColors.absent;
              statusIcon = Icons.cancel;
              break;
            case LeaveRequestStatus.cancelled:
              statusColor = AppColors.textSecondary;
              statusIcon = Icons.block;
              break;
          }

          return ListTile(
            leading: Icon(statusIcon, color: statusColor),
            title: Text(request.type.displayName),
            subtitle: Text(
              request.isSingleDay
                  ? DateFormat('MMM d, yyyy').format(request.startDate)
                  : '${DateFormat('MMM d').format(request.startDate)} - ${DateFormat('MMM d, yyyy').format(request.endDate)}',
              style: TextStyle(fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                request.status.displayName.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
