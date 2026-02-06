import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../utils/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../providers/analytics_providers.dart';
import '../../widgets/common_widgets.dart';

/// Analytics dashboard with charts and insights
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacher = ref.watch(currentTeacherProvider).value;
    if (teacher == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final analyticsAsync = ref.watch(dashboardAnalyticsProvider(teacher.instituteId));
    final selectedPeriod = ref.watch(analyticsPeriodProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          // Export button
          analyticsAsync.maybeWhen(
            data: (analytics) {
              if (analytics == null) return const SizedBox.shrink();
              return PopupMenuButton<String>(
                icon: const Icon(Icons.file_download_outlined),
                tooltip: 'Export Data',
                onSelected: (format) async {
                  final exportService = ExportService();
                  // Get institute name
                  final instituteData = await ref.read(firestoreServiceProvider)
                      .instituteStream(teacher.instituteId)
                      .first;
                  final instituteName = instituteData?.name ?? 'Unknown Institute';

                  if (format == 'excel') {
                    await exportService.exportAnalyticsToExcel(analytics, instituteName);
                  } else {
                    await exportService.exportAnalyticsToCsv(analytics, instituteName);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'excel',
                    child: Row(
                      children: [
                        Icon(Icons.table_chart, size: 20, color: AppColors.present),
                        SizedBox(width: 12),
                        Text('Export to Excel'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'csv',
                    child: Row(
                      children: [
                        Icon(Icons.description, size: 20, color: AppColors.info),
                        SizedBox(width: 12),
                        Text('Export to CSV'),
                      ],
                    ),
                  ),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          // Period selector
          PopupMenuButton<AnalyticsPeriod>(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Select Period',
            onSelected: (period) {
              ref.read(analyticsPeriodProvider.notifier).state = period;
            },
            itemBuilder: (context) => AnalyticsPeriod.values
                .map((p) => PopupMenuItem(
                      value: p,
                      child: Row(
                        children: [
                          if (p == selectedPeriod)
                            const Icon(Icons.check, size: 20)
                          else
                            const SizedBox(width: 20),
                          const SizedBox(width: 8),
                          Text(p.displayName),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
      body: analyticsAsync.when(
        data: (analytics) {
          if (analytics == null) {
            return const EmptyStateWidget(
              icon: Icons.analytics_outlined,
              title: 'No Data Yet',
              subtitle: 'Start marking attendance to see analytics',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardAnalyticsProvider(teacher.instituteId));
            },
            child: _AnalyticsContent(analytics: analytics),
          );
        },
        loading: () => const ShimmerListLoading(type: ShimmerListType.simple, itemCount: 6),
        error: (error, stack) => ErrorStateWidget(
          error: error,
          onRetry: () => ref.invalidate(dashboardAnalyticsProvider(teacher.instituteId)),
        ),
      ),
    );
  }
}

class _AnalyticsContent extends StatelessWidget {
  final DashboardAnalytics analytics;

  const _AnalyticsContent({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary cards
        _SummarySection(summary: analytics.summary),
        const SizedBox(height: 24),

        // Attendance trend chart
        if (analytics.trendData.isNotEmpty) ...[
          _SectionHeader(title: 'Attendance Trend', subtitle: analytics.period.displayName),
          const SizedBox(height: 12),
          _AttendanceTrendChart(data: analytics.trendData),
          const SizedBox(height: 24),
        ],

        // Batch comparison
        if (analytics.batchComparison.isNotEmpty) ...[
          _SectionHeader(title: 'Batch Comparison', subtitle: '${analytics.batchComparison.length} batches'),
          const SizedBox(height: 12),
          _BatchComparisonChart(data: analytics.batchComparison),
          const SizedBox(height: 24),
        ],

        // Attendance distribution
        _SectionHeader(title: 'Attendance Distribution', subtitle: 'Overall breakdown'),
        const SizedBox(height: 12),
        _AttendanceDistributionChart(distribution: analytics.distribution),
        const SizedBox(height: 24),

        // At-risk students
        if (analytics.atRiskStudents.isNotEmpty) ...[
          _SectionHeader(
            title: 'At-Risk Students',
            subtitle: '${analytics.atRiskStudents.length} students need attention',
          ),
          const SizedBox(height: 12),
          _AtRiskStudentsList(students: analytics.atRiskStudents),
        ],
      ],
    );
  }
}

class _SummarySection extends StatelessWidget {
  final AnalyticsSummary summary;

  const _SummarySection({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Main attendance percentage card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall Attendance',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${summary.overallAttendance.toStringAsFixed(1)}%',
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _getAttendanceColor(summary.overallAttendance),
                                ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: summary.isImproving
                                  ? AppColors.present.withValues(alpha: 0.1)
                                  : AppColors.absent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  summary.isImproving
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  size: 16,
                                  color: summary.isImproving
                                      ? AppColors.present
                                      : AppColors.absent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  summary.changeText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: summary.isImproving
                                        ? AppColors.present
                                        : AppColors.absent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getAttendanceColor(summary.overallAttendance).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.analytics,
                    size: 32,
                    color: _getAttendanceColor(summary.overallAttendance),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Stats row
        Row(
          children: [
            Expanded(
              child: _MiniStatCard(
                label: 'Students',
                value: summary.totalStudents.toString(),
                icon: Icons.people,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniStatCard(
                label: 'Batches',
                value: summary.totalBatches.toString(),
                icon: Icons.groups,
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniStatCard(
                label: 'At Risk',
                value: summary.atRiskCount.toString(),
                icon: Icons.warning_amber,
                color: summary.atRiskCount > 0 ? AppColors.absent : AppColors.present,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getAttendanceColor(double percentage) {
    if (percentage >= 90) return AppColors.present;
    if (percentage >= 75) return AppColors.late;
    return AppColors.absent;
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

class _AttendanceTrendChart extends StatelessWidget {
  final List<AttendanceTrendPoint> data;

  const _AttendanceTrendChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.attendancePercentage);
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: AppColors.border,
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: 25,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}%',
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: (data.length / 5).ceilToDouble().clamp(1, 10),
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.length) return const SizedBox();
                      final date = data[index].date;
                      return Text(
                        DateFormat('d/M').format(date),
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minY: 0,
              maxY: 100,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: data.length <= 15,
                    getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                      radius: 4,
                      color: AppColors.primary,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.primary.withValues(alpha: 0.1),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spot) => AppColors.surface,
                  getTooltipItems: (spots) {
                    return spots.map((spot) {
                      final index = spot.x.toInt();
                      if (index < 0 || index >= data.length) return null;
                      final point = data[index];
                      return LineTooltipItem(
                        '${DateFormat('MMM d').format(point.date)}\n${point.attendancePercentage.toStringAsFixed(1)}%',
                        const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BatchComparisonChart extends StatelessWidget {
  final List<BatchComparisonData> data;

  const _BatchComparisonChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 100,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => AppColors.surface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final batch = data[groupIndex];
                    return BarTooltipItem(
                      '${batch.batchName}\n${batch.attendancePercentage.toStringAsFixed(1)}%',
                      const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: 25,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}%',
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.length) return const SizedBox();
                      // Truncate long names
                      var name = data[index].batchName;
                      if (name.length > 8) name = '${name.substring(0, 7)}...';
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          name,
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: AppColors.border,
                  strokeWidth: 1,
                ),
              ),
              barGroups: data.asMap().entries.map((entry) {
                final index = entry.key;
                final batch = entry.value;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: batch.attendancePercentage,
                      color: _getBarColor(batch.attendancePercentage),
                      width: 24,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Color _getBarColor(double percentage) {
    if (percentage >= 90) return AppColors.present;
    if (percentage >= 75) return AppColors.late;
    return AppColors.absent;
  }
}

class _AttendanceDistributionChart extends StatelessWidget {
  final AttendanceDistribution distribution;

  const _AttendanceDistributionChart({required this.distribution});

  @override
  Widget build(BuildContext context) {
    if (distribution.totalClasses == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No attendance data yet')),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: distribution.presentCount.toDouble(),
                      title: '',
                      color: AppColors.present,
                      radius: 50,
                    ),
                    PieChartSectionData(
                      value: distribution.lateCount.toDouble(),
                      title: '',
                      color: AppColors.late,
                      radius: 50,
                    ),
                    PieChartSectionData(
                      value: distribution.absentCount.toDouble(),
                      title: '',
                      color: AppColors.absent,
                      radius: 50,
                    ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 20,
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LegendRow(
                    color: AppColors.present,
                    label: 'Present',
                    value: distribution.presentCount,
                    percentage: distribution.presentPercentage,
                  ),
                  const SizedBox(height: 8),
                  _LegendRow(
                    color: AppColors.late,
                    label: 'Late',
                    value: distribution.lateCount,
                    percentage: distribution.latePercentage,
                  ),
                  const SizedBox(height: 8),
                  _LegendRow(
                    color: AppColors.absent,
                    label: 'Absent',
                    value: distribution.absentCount,
                    percentage: distribution.absentPercentage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  final double percentage;

  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          '$value (${percentage.toStringAsFixed(1)}%)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

class _AtRiskStudentsList extends StatelessWidget {
  final List<AtRiskStudent> students;

  const _AtRiskStudentsList({required this.students});

  @override
  Widget build(BuildContext context) {
    // Show max 5 students, with a "View All" option
    final displayStudents = students.take(5).toList();

    return Card(
      child: Column(
        children: [
          ...displayStudents.map((student) => _AtRiskStudentTile(student: student)),
          if (students.length > 5)
            ListTile(
              leading: const Icon(Icons.more_horiz),
              title: Text('View all ${students.length} at-risk students'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Show all at-risk students in a bottom sheet
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => DraggableScrollableSheet(
                    initialChildSize: 0.7,
                    maxChildSize: 0.9,
                    minChildSize: 0.5,
                    expand: false,
                    builder: (context, scrollController) => Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'At-Risk Students (${students.length})',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            itemCount: students.length,
                            itemBuilder: (context, index) =>
                                _AtRiskStudentTile(student: students[index]),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _AtRiskStudentTile extends StatelessWidget {
  final AtRiskStudent student;

  const _AtRiskStudentTile({required this.student});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getRiskColor(student.riskLevel).withValues(alpha: 0.1),
        child: Text(
          student.studentName.isNotEmpty ? student.studentName[0].toUpperCase() : '?',
          style: TextStyle(
            color: _getRiskColor(student.riskLevel),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(student.studentName),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getRiskColor(student.riskLevel).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${student.attendancePercentage.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 11,
                color: _getRiskColor(student.riskLevel),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${student.batchName} • ${student.reason.shortName}',
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: Icon(
        Icons.warning_amber,
        color: _getRiskColor(student.riskLevel),
        size: 20,
      ),
    );
  }

  Color _getRiskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.high:
        return AppColors.absent;
      case RiskLevel.medium:
        return AppColors.late;
      case RiskLevel.low:
        return AppColors.textSecondary;
    }
  }
}
