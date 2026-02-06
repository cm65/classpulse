import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../providers/parent_providers.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import 'child_detail_screen.dart';
import 'leave_request_screen.dart';
import 'parent_announcements_screen.dart';
import 'parent_login_screen.dart';

/// Parent dashboard showing all linked children and their summaries
class ParentDashboardScreen extends ConsumerWidget {
  final Parent parent;

  const ParentDashboardScreen({super.key, required this.parent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(parentDashboardProvider(parent.phone));

    return Scaffold(
      appBar: AppBar(
        title: Text('Hello, ${parent.name.split(' ').first}!'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ParentAnnouncementsScreen(parent: parent),
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                ref.read(parentAuthProvider.notifier).logout();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ParentLoginScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: dashboardAsync.when(
        data: (dashboard) => _DashboardContent(dashboard: dashboard, parent: parent),
        loading: () => const ShimmerListLoading(type: ShimmerListType.batch),
        error: (error, stack) => ErrorStateWidget(
          error: error,
          onRetry: () => ref.invalidate(parentDashboardProvider(parent.phone)),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final ParentDashboardData dashboard;
  final Parent parent;

  const _DashboardContent({required this.dashboard, required this.parent});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        // RefreshIndicator needs async callback
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Announcements section (if any)
            if (dashboard.announcements.isNotEmpty) ...[
              _AnnouncementsBanner(
                announcements: dashboard.announcements,
                parent: parent,
              ),
              const SizedBox(height: 20),
            ],

            // Children section
            Text(
              'My Children',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            if (dashboard.children.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No children linked to your account yet.'),
                ),
              )
            else
              ...dashboard.children.map((child) => _ChildCard(
                    child: child,
                    parent: parent,
                  )),

            const SizedBox(height: 24),

            // Pending leave requests
            if (dashboard.pendingLeaveRequests.isNotEmpty) ...[
              Text(
                'Pending Leave Requests',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              ...dashboard.pendingLeaveRequests.map((request) => _LeaveRequestCard(
                    request: request,
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnnouncementsBanner extends StatelessWidget {
  final List<Announcement> announcements;
  final Parent parent;

  const _AnnouncementsBanner({required this.announcements, required this.parent});

  @override
  Widget build(BuildContext context) {
    final urgentAnnouncements = announcements.where((a) => a.isUrgent).toList();
    final hasUrgent = urgentAnnouncements.isNotEmpty;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ParentAnnouncementsScreen(parent: parent),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: hasUrgent
                ? [Colors.red.shade400, Colors.red.shade600]
                : [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasUrgent ? Icons.priority_high : Icons.campaign,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasUrgent
                        ? '${urgentAnnouncements.length} Urgent Announcement${urgentAnnouncements.length > 1 ? 's' : ''}'
                        : '${announcements.length} New Announcement${announcements.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    announcements.first.title,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  final ChildSummary child;
  final Parent parent;

  const _ChildCard({required this.child, required this.parent});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChildDetailScreen(
              child: child,
              parent: parent,
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Child info header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      child.studentName.isNotEmpty ? child.studentName[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          child.studentName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          child.batchName,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _AttendanceBadge(percentage: child.attendancePercentage),
                ],
              ),
              const Divider(height: 24),

              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    icon: Icons.check_circle,
                    label: 'Present',
                    value: '${child.presentDays}',
                    color: AppColors.present,
                  ),
                  _StatItem(
                    icon: Icons.cancel,
                    label: 'Absent',
                    value: '${child.absentDays}',
                    color: AppColors.absent,
                  ),
                  _StatItem(
                    icon: Icons.schedule,
                    label: 'Late',
                    value: '${child.lateDays}',
                    color: AppColors.late,
                  ),
                  if (child.classRank != null)
                    _StatItem(
                      icon: Icons.emoji_events,
                      label: 'Rank',
                      value: '#${child.classRank}',
                      color: Colors.amber.shade700,
                    ),
                ],
              ),

              // Fee indicator if pending
              if (child.pendingFees != null && child.pendingFees! > 0) ...[
                const Divider(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.payment, size: 18, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pending Fee: ₹${child.pendingFees!.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LeaveRequestScreen(
                          child: child,
                          parent: parent,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.event_busy, size: 18),
                    label: const Text('Request Leave'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChildDetailScreen(
                          child: child,
                          parent: parent,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Details'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceBadge extends StatelessWidget {
  final double percentage;

  const _AttendanceBadge({required this.percentage});

  Color get _color {
    if (percentage >= 85) return AppColors.present;
    if (percentage >= 75) return AppColors.late;
    return AppColors.absent;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            '${percentage.toStringAsFixed(0)}%',
            style: TextStyle(
              color: _color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            'Attendance',
            style: TextStyle(
              color: _color,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 16,
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

class _LeaveRequestCard extends StatelessWidget {
  final LeaveRequest request;

  const _LeaveRequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.pending_actions,
                color: Colors.orange.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.type.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    request.isSingleDay
                        ? DateFormat('MMM d, yyyy').format(request.startDate)
                        : '${DateFormat('MMM d').format(request.startDate)} - ${DateFormat('MMM d, yyyy').format(request.endDate)}',
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
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Pending',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
