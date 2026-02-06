import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../utils/theme.dart';
import '../../models/models.dart';
import '../../providers/attendance_providers.dart';
import '../../widgets/common_widgets.dart';

/// Screen showing a student's attendance history with calendar view
class StudentHistoryScreen extends ConsumerStatefulWidget {
  final Student student;
  final String batchId;
  final String batchName;
  final String instituteId;

  const StudentHistoryScreen({
    super.key,
    required this.student,
    required this.batchId,
    required this.batchName,
    required this.instituteId,
  });

  @override
  ConsumerState<StudentHistoryScreen> createState() => _StudentHistoryScreenState();
}

class _StudentHistoryScreenState extends ConsumerState<StudentHistoryScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final nextMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    if (!nextMonth.isAfter(DateTime(now.year, now.month))) {
      setState(() {
        _selectedMonth = nextMonth;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pass selected month to provider for efficient month-scoped queries
    final historyAsync = ref.watch(studentHistoryWithDatesProvider((
      instituteId: widget.instituteId,
      batchId: widget.batchId,
      studentId: widget.student.id,
      year: _selectedMonth.year,
      month: _selectedMonth.month,
    )));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.student.name),
            Text(
              widget.batchName,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: historyAsync.when(
        data: (history) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(studentHistoryWithDatesProvider((
              instituteId: widget.instituteId,
              batchId: widget.batchId,
              studentId: widget.student.id,
              year: _selectedMonth.year,
              month: _selectedMonth.month,
            )));
          },
          child: _buildContent(context, history),
        ),
        loading: () => const ShimmerListLoading(type: ShimmerListType.simple, itemCount: 6),
        error: (error, stack) => ErrorStateWidget(
          error: error,
          onRetry: () => ref.invalidate(studentHistoryWithDatesProvider((
            instituteId: widget.instituteId,
            batchId: widget.batchId,
            studentId: widget.student.id,
            year: _selectedMonth.year,
            month: _selectedMonth.month,
          ))),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<StudentAttendanceHistoryEntry> history) {
    // Create a map of date -> status for quick lookup
    final attendanceMap = <String, AttendanceStatus>{};
    for (final entry in history) {
      attendanceMap[entry.dateKey] = entry.status;
    }

    // Calculate stats for the selected month
    final monthStats = _calculateMonthStats(history);

    return Column(
      children: [
        // Monthly stats card
        _buildStatsCard(context, monthStats),

        // Month selector
        _buildMonthSelector(context),

        // Calendar grid
        Expanded(
          child: _buildCalendarGrid(context, attendanceMap),
        ),

        // Recent attendance list
        if (history.isNotEmpty) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Recent Attendance',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 150,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: history.length > 10 ? 10 : history.length,
              itemBuilder: (context, index) {
                final entry = history[index];
                return _buildHistoryItem(context, entry);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatsCard(BuildContext context, _MonthStats stats) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '${stats.attendancePercentage.toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: _getPercentageColor(stats.attendancePercentage),
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Attendance Rate',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Present',
                  count: stats.presentCount,
                  color: AppColors.present,
                ),
                _StatItem(
                  label: 'Absent',
                  count: stats.absentCount,
                  color: AppColors.absent,
                ),
                _StatItem(
                  label: 'Late',
                  count: stats.lateCount,
                  color: AppColors.late,
                ),
                _StatItem(
                  label: 'Total',
                  count: stats.totalDays,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector(BuildContext context) {
    final now = DateTime.now();
    final canGoNext = !DateTime(_selectedMonth.year, _selectedMonth.month + 1)
        .isAfter(DateTime(now.year, now.month));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _previousMonth,
          ),
          Text(
            DateFormat('MMMM yyyy').format(_selectedMonth),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: canGoNext ? _nextMonth : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(BuildContext context, Map<String, AttendanceStatus> attendanceMap) {
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday; // 1 = Monday, 7 = Sunday

    // Adjust for Sunday as first day (0 = Sunday)
    final startPadding = firstWeekday % 7;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Day headers
          Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),

          // Calendar grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: startPadding + daysInMonth,
              itemBuilder: (context, index) {
                if (index < startPadding) {
                  return const SizedBox();
                }

                final day = index - startPadding + 1;
                final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
                final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                final status = attendanceMap[dateKey];
                final isToday = _isToday(date);
                final isFuture = date.isAfter(DateTime.now());

                return _buildCalendarDay(context, day, status, isToday, isFuture);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarDay(
    BuildContext context,
    int day,
    AttendanceStatus? status,
    bool isToday,
    bool isFuture,
  ) {
    Color? backgroundColor;
    Color textColor = AppColors.textPrimary;

    if (isFuture) {
      textColor = AppColors.textHint;
    } else if (status != null) {
      switch (status) {
        case AttendanceStatus.present:
          backgroundColor = AppColors.present.withValues(alpha: 0.3);
          break;
        case AttendanceStatus.absent:
          backgroundColor = AppColors.absent.withValues(alpha: 0.3);
          break;
        case AttendanceStatus.late:
          backgroundColor = AppColors.late.withValues(alpha: 0.3);
          break;
        case AttendanceStatus.unmarked:
          backgroundColor = AppColors.unmarked.withValues(alpha: 0.3);
          break;
      }
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: isToday
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              day.toString(),
              style: TextStyle(
                color: textColor,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (status != null && !isFuture)
              Icon(
                _getStatusIcon(status),
                size: 12,
                color: _getStatusColor(status),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, StudentAttendanceHistoryEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _getStatusColor(entry.status),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            DateFormat('EEE, MMM d').format(entry.date),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _getStatusColor(entry.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              entry.status.displayName,
              style: TextStyle(
                fontSize: 12,
                color: _getStatusColor(entry.status),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _MonthStats _calculateMonthStats(List<StudentAttendanceHistoryEntry> history) {
    final monthEntries = history.where((e) =>
        e.date.year == _selectedMonth.year &&
        e.date.month == _selectedMonth.month);

    int present = 0;
    int absent = 0;
    int late = 0;

    for (final entry in monthEntries) {
      switch (entry.status) {
        case AttendanceStatus.present:
          present++;
          break;
        case AttendanceStatus.absent:
          absent++;
          break;
        case AttendanceStatus.late:
          late++;
          break;
        case AttendanceStatus.unmarked:
          break;
      }
    }

    final total = present + absent + late;
    final percentage = total > 0 ? ((present + late) / total) * 100 : 0.0;

    return _MonthStats(
      presentCount: present,
      absentCount: absent,
      lateCount: late,
      totalDays: total,
      attendancePercentage: percentage,
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return AppColors.present;
      case AttendanceStatus.absent:
        return AppColors.absent;
      case AttendanceStatus.late:
        return AppColors.late;
      case AttendanceStatus.unmarked:
        return AppColors.unmarked;
    }
  }

  IconData _getStatusIcon(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return Icons.check;
      case AttendanceStatus.absent:
        return Icons.close;
      case AttendanceStatus.late:
        return Icons.access_time;
      case AttendanceStatus.unmarked:
        return Icons.remove;
    }
  }

  Color _getPercentageColor(double percentage) {
    if (percentage >= 90) return AppColors.present;
    if (percentage >= 75) return AppColors.late;
    return AppColors.absent;
  }
}

class _MonthStats {
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int totalDays;
  final double attendancePercentage;

  _MonthStats({
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.totalDays,
    required this.attendancePercentage,
  });
}

class _StatItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatItem({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
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
