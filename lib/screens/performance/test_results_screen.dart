import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../utils/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';
import 'score_entry_screen.dart';

/// Screen showing test results with analytics and rankings
class TestResultsScreen extends ConsumerWidget {
  final String instituteId;
  final String testId;

  const TestResultsScreen({
    super.key,
    required this.instituteId,
    required this.testId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testAsync = ref.watch(testProvider((
      instituteId: instituteId,
      testId: testId,
    )));
    final analyticsAsync = ref.watch(testAnalyticsProvider((
      instituteId: instituteId,
      testId: testId,
    )));
    final resultsAsync = ref.watch(testResultsProvider((
      instituteId: instituteId,
      testId: testId,
    )));

    return Scaffold(
      appBar: AppBar(
        title: testAsync.when(
          data: (test) => Text(test?.name ?? 'Test Results'),
          loading: () => const Text('Loading...'),
          error: (e, s) => const Text('Error'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScoreEntryScreen(
                    instituteId: instituteId,
                    testId: testId,
                  ),
                ),
              );
            },
            tooltip: 'Edit Scores',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(testAnalyticsProvider((
            instituteId: instituteId,
            testId: testId,
          )));
          ref.invalidate(testResultsProvider((
            instituteId: instituteId,
            testId: testId,
          )));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Test info card
            testAsync.when(
              data: (test) {
                if (test == null) return const SizedBox.shrink();
                return _TestInfoCard(test: test);
              },
              loading: () => const ShimmerSummaryCard(),
              error: (e, s) => Text('Error: $e'),
            ),
            const SizedBox(height: 16),

            // Analytics summary
            analyticsAsync.when(
              data: (analytics) => _AnalyticsSummary(analytics: analytics),
              loading: () => const ShimmerSummaryCard(),
              error: (e, s) => Text('Error: $e'),
            ),
            const SizedBox(height: 16),

            // Grade distribution chart
            analyticsAsync.when(
              data: (analytics) {
                if (analytics.gradeDistribution.isEmpty) {
                  return const SizedBox.shrink();
                }
                return _GradeDistributionChart(analytics: analytics);
              },
              loading: () => const SizedBox.shrink(),
              error: (e, s) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),

            // Student results
            Text(
              'Student Results',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            resultsAsync.when(
              data: (results) {
                if (results.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.people,
                    title: 'No Students',
                    subtitle: 'No students found for this test',
                  );
                }

                // Sort by rank (null ranks at end)
                final sortedResults = results.toList()
                  ..sort((a, b) {
                    if (a.rank == null && b.rank == null) return 0;
                    if (a.rank == null) return 1;
                    if (b.rank == null) return -1;
                    return a.rank!.compareTo(b.rank!);
                  });

                return Column(
                  children: sortedResults.map((result) {
                    return _StudentResultCard(result: result);
                  }).toList(),
                );
              },
              loading: () => const ShimmerListLoading(
                type: ShimmerListType.simple,
                itemCount: 5,
              ),
              error: (e, s) => ErrorStateWidget(
                error: e,
                onRetry: () => ref.invalidate(testResultsProvider((
                  instituteId: instituteId,
                  testId: testId,
                ))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TestInfoCard extends StatelessWidget {
  final Test test;

  const _TestInfoCard({required this.test});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    test.type.displayName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('EEEE, MMM d, yyyy').format(test.testDate),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (test.description != null) ...[
              Text(
                test.description!,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                _InfoItem(
                  icon: Icons.star,
                  label: 'Maximum',
                  value: '${test.maxMarks.toStringAsFixed(0)} marks',
                ),
                if (test.passingMarks != null) ...[
                  const SizedBox(width: 24),
                  _InfoItem(
                    icon: Icons.check_circle,
                    label: 'Passing',
                    value: '${test.passingMarks!.toStringAsFixed(0)} marks',
                  ),
                ],
                if (test.durationMinutes != null) ...[
                  const SizedBox(width: 24),
                  _InfoItem(
                    icon: Icons.timer,
                    label: 'Duration',
                    value: test.formattedDuration,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AnalyticsSummary extends StatelessWidget {
  final TestAnalytics analytics;

  const _AnalyticsSummary({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatBox(
                    label: 'Graded',
                    value: '${analytics.gradedCount}',
                    subtitle: 'of ${analytics.totalStudents}',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatBox(
                    label: 'Absent',
                    value: '${analytics.absentCount}',
                    subtitle: 'students',
                    color: AppColors.absent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatBox(
                    label: 'Exempt',
                    value: '${analytics.exemptCount}',
                    subtitle: 'students',
                    color: AppColors.late,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatBox(
                    label: 'Highest',
                    value: analytics.highestMarks?.toStringAsFixed(1) ?? '-',
                    subtitle: 'marks',
                    color: AppColors.present,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatBox(
                    label: 'Average',
                    value: analytics.averageMarks?.toStringAsFixed(1) ?? '-',
                    subtitle: 'marks',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatBox(
                    label: 'Lowest',
                    value: analytics.lowestMarks?.toStringAsFixed(1) ?? '-',
                    subtitle: 'marks',
                    color: AppColors.absent,
                  ),
                ),
              ],
            ),
            if (analytics.passedCount > 0 || analytics.failedCount > 0) ...[
              const SizedBox(height: 16),
              _PassFailBar(
                passed: analytics.passedCount,
                failed: analytics.failedCount,
                total: analytics.gradedCount,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PassFailBar extends StatelessWidget {
  final int passed;
  final int failed;
  final int total;

  const _PassFailBar({
    required this.passed,
    required this.failed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final passPercentage = total > 0 ? (passed / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pass Rate',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '${(passPercentage * 100).toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: passPercentage,
            minHeight: 8,
            backgroundColor: AppColors.absent.withValues(alpha: 0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.present),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$passed passed',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.present,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$failed failed',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.absent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GradeDistributionChart extends StatelessWidget {
  final TestAnalytics analytics;

  const _GradeDistributionChart({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final grades = ['A+', 'A', 'B+', 'B', 'C', 'D', 'F'];
    final gradeColors = {
      'A+': AppColors.present,
      'A': AppColors.present.withValues(alpha: 0.8),
      'B+': Colors.blue,
      'B': Colors.blue.withValues(alpha: 0.8),
      'C': AppColors.late,
      'D': AppColors.late.withValues(alpha: 0.8),
      'F': AppColors.absent,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Grade Distribution',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: analytics.gradeDistribution.values.isEmpty
                      ? 10
                      : (analytics.gradeDistribution.values
                                  .reduce((a, b) => a > b ? a : b) +
                              2)
                          .toDouble(),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < grades.length) {
                            return Text(
                              grades[index],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 2,
                  ),
                  barGroups: grades.asMap().entries.map((entry) {
                    final count =
                        analytics.gradeDistribution[entry.value]?.toDouble() ??
                            0;
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: count,
                          color: gradeColors[entry.value],
                          width: 24,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentResultCard extends StatelessWidget {
  final StudentTestResult result;

  const _StudentResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final score = result.score;
    final isGraded = score != null &&
        !score.isAbsent &&
        !score.isExempt &&
        score.marksObtained != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Rank badge
            if (result.rank != null)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _getRankColor(result.rank!).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${result.rank}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getRankColor(result.rank!),
                    ),
                  ),
                ),
              )
            else
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '-',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            const SizedBox(width: 12),

            // Student name
            Expanded(
              child: Text(
                result.studentName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),

            // Score display
            if (score?.isAbsent ?? false)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.absent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Absent',
                  style: TextStyle(
                    color: AppColors.absent,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              )
            else if (score?.isExempt ?? false)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.late.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Exempt',
                  style: TextStyle(
                    color: AppColors.late,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              )
            else if (!isGraded)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Not Graded',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              )
            else
              Row(
                children: [
                  // Grade badge
                  if (result.letterGrade != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getGradeColor(result.letterGrade!)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        result.letterGrade!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getGradeColor(result.letterGrade!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  // Marks
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        result.displayScore,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (result.percentage != null)
                        Text(
                          '${result.percentage!.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return Colors.amber.shade700;
    if (rank == 2) return Colors.grey.shade500;
    if (rank == 3) return Colors.brown.shade400;
    return AppColors.primary;
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A+':
      case 'A':
        return AppColors.present;
      case 'B+':
      case 'B':
        return Colors.blue;
      case 'C':
        return AppColors.late;
      case 'D':
        return Colors.orange;
      case 'F':
        return AppColors.absent;
      default:
        return AppColors.textSecondary;
    }
  }
}
