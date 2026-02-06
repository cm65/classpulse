import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../utils/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';
import 'create_test_screen.dart';
import 'score_entry_screen.dart';
import 'test_results_screen.dart';

/// Screen showing all tests for a batch
class TestsListScreen extends ConsumerWidget {
  final String instituteId;
  final String batchId;
  final String batchName;

  const TestsListScreen({
    super.key,
    required this.instituteId,
    required this.batchId,
    required this.batchName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testsAsync = ref.watch(batchTestsProvider((
      instituteId: instituteId,
      batchId: batchId,
    )));

    return Scaffold(
      appBar: AppBar(
        title: Text('$batchName - Tests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateTestScreen(
                    instituteId: instituteId,
                    batchId: batchId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: testsAsync.when(
        data: (tests) {
          if (tests.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.quiz,
              title: 'No Tests Yet',
              subtitle: 'Create your first test for this batch',
              action: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateTestScreen(
                        instituteId: instituteId,
                        batchId: batchId,
                      ),
                    ),
                  );
                },
                child: const Text('Create Test'),
              ),
            );
          }

          // Group tests by month
          final groupedTests = <String, List<Test>>{};
          for (final test in tests) {
            final monthKey = DateFormat('MMMM yyyy').format(test.testDate);
            groupedTests.putIfAbsent(monthKey, () => []).add(test);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupedTests.length,
            itemBuilder: (context, index) {
              final monthKey = groupedTests.keys.elementAt(index);
              final monthTests = groupedTests[monthKey]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      monthKey,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                  ...monthTests.map((test) => _TestCard(
                        instituteId: instituteId,
                        test: test,
                      )),
                  const SizedBox(height: 16),
                ],
              );
            },
          );
        },
        loading: () => const ShimmerListLoading(type: ShimmerListType.batch),
        error: (error, stack) => ErrorStateWidget(
          error: error,
          onRetry: () => ref.invalidate(batchTestsProvider((
            instituteId: instituteId,
            batchId: batchId,
          ))),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateTestScreen(
                instituteId: instituteId,
                batchId: batchId,
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TestCard extends ConsumerWidget {
  final String instituteId;
  final Test test;

  const _TestCard({
    required this.instituteId,
    required this.test,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(testAnalyticsProvider((
      instituteId: instituteId,
      testId: test.id,
    )));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TestResultsScreen(
                instituteId: instituteId,
                testId: test.id,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getTypeColor(test.type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      test.type.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getTypeColor(test.type),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('MMM d').format(test.testDate),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Test name
              Text(
                test.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (test.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  test.description!,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),

              // Marks info
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.star,
                    label: 'Max: ${test.maxMarks.toStringAsFixed(0)}',
                  ),
                  if (test.passingMarks != null) ...[
                    const SizedBox(width: 12),
                    _InfoChip(
                      icon: Icons.check,
                      label: 'Pass: ${test.passingMarks!.toStringAsFixed(0)}',
                    ),
                  ],
                  if (test.durationMinutes != null) ...[
                    const SizedBox(width: 12),
                    _InfoChip(
                      icon: Icons.timer,
                      label: test.formattedDuration,
                    ),
                  ],
                ],
              ),
              const Divider(height: 24),

              // Analytics row
              analyticsAsync.when(
                data: (analytics) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _AnalyticItem(
                      label: 'Graded',
                      value: '${analytics.gradedCount}/${analytics.totalStudents}',
                      color: AppColors.present,
                    ),
                    _AnalyticItem(
                      label: 'Average',
                      value: analytics.formattedAverage,
                      color: AppColors.primary,
                    ),
                    _AnalyticItem(
                      label: 'Pass Rate',
                      value: '${analytics.passPercentage.toStringAsFixed(0)}%',
                      color: analytics.passPercentage >= 70
                          ? AppColors.present
                          : analytics.passPercentage >= 50
                              ? AppColors.late
                              : AppColors.absent,
                    ),
                  ],
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => Text(
                  'Unable to load analytics',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ScoreEntryScreen(
                            instituteId: instituteId,
                            testId: test.id,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Enter Scores'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TestResultsScreen(
                            instituteId: instituteId,
                            testId: test.id,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.leaderboard, size: 18),
                    label: const Text('Results'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(TestType type) {
    switch (type) {
      case TestType.quiz:
        return Colors.purple;
      case TestType.unitTest:
        return AppColors.primary;
      case TestType.midterm:
        return Colors.orange;
      case TestType.final_:
        return AppColors.absent;
      case TestType.practice:
        return AppColors.present;
      case TestType.assignment:
        return AppColors.late;
      case TestType.other:
        return AppColors.textSecondary;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _AnalyticItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AnalyticItem({
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
