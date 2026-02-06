import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../utils/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';
import 'tests_list_screen.dart';
import 'create_test_screen.dart';
import 'score_entry_screen.dart';

/// Main dashboard for performance/grades management
class PerformanceDashboardScreen extends ConsumerWidget {
  final String instituteId;

  const PerformanceDashboardScreen({super.key, required this.instituteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(performanceDashboardProvider(instituteId));
    final batchesAsync = ref.watch(batchesProvider(instituteId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateTestScreen(instituteId: instituteId),
                ),
              );
            },
            tooltip: 'Create Test',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(performanceDashboardProvider(instituteId));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Dashboard stats
            dashboardAsync.when(
              data: (data) => _DashboardStats(data: data),
              loading: () => const _StatsLoading(),
              error: (e, s) => ErrorStateWidget(
                error: e,
                onRetry: () => ref.invalidate(performanceDashboardProvider(instituteId)),
              ),
            ),
            const SizedBox(height: 24),

            // Quick actions
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _QuickActionsGrid(instituteId: instituteId),
            const SizedBox(height: 24),

            // Batches with tests
            Text(
              'Tests by Batch',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            batchesAsync.when(
              data: (batches) {
                if (batches.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.group,
                    title: 'No Batches',
                    subtitle: 'Create a batch first to manage tests',
                  );
                }
                return Column(
                  children: batches.map((batch) {
                    return _BatchTestsCard(
                      instituteId: instituteId,
                      batch: batch,
                    );
                  }).toList(),
                );
              },
              loading: () => const ShimmerListLoading(
                type: ShimmerListType.simple,
                itemCount: 3,
              ),
              error: (e, s) => Text('Error: $e'),
            ),
            const SizedBox(height: 24),

            // Recent tests needing grading
            dashboardAsync.when(
              data: (data) {
                final needsGrading = data.recentTests.where((t) => true).take(5).toList();
                if (needsGrading.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Tests',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ...needsGrading.map((test) => _RecentTestCard(
                          instituteId: instituteId,
                          test: test,
                        )),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, s) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateTestScreen(instituteId: instituteId),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Test'),
      ),
    );
  }
}

class _DashboardStats extends StatelessWidget {
  final PerformanceDashboardData data;

  const _DashboardStats({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overview',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.quiz,
                    label: 'Total Tests',
                    value: '${data.totalTests}',
                    color: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.calendar_today,
                    label: 'This Month',
                    value: '${data.recentTestsCount}',
                    color: AppColors.late,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.pending_actions,
                    label: 'Need Grading',
                    value: '${data.upcomingGradingCount}',
                    color: AppColors.absent,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.trending_up,
                    label: 'Avg Score',
                    value: '${data.averageBatchPerformance.toStringAsFixed(0)}%',
                    color: AppColors.present,
                  ),
                ),
              ],
            ),
          ],
        ),
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
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatsLoading extends StatelessWidget {
  const _StatsLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: ShimmerSummaryCard()),
                SizedBox(width: 12),
                Expanded(child: ShimmerSummaryCard()),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: ShimmerSummaryCard()),
                SizedBox(width: 12),
                Expanded(child: ShimmerSummaryCard()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final String instituteId;

  const _QuickActionsGrid({required this.instituteId});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: [
        _QuickActionCard(
          icon: Icons.add_circle,
          label: 'Create Test',
          color: AppColors.primary,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateTestScreen(instituteId: instituteId),
              ),
            );
          },
        ),
        _QuickActionCard(
          icon: Icons.edit_note,
          label: 'Enter Scores',
          color: AppColors.late,
          onTap: () {
            _showSelectTestDialog(context, instituteId);
          },
        ),
        _QuickActionCard(
          icon: Icons.analytics,
          label: 'View Reports',
          color: AppColors.present,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Performance reports coming soon')),
            );
          },
        ),
        _QuickActionCard(
          icon: Icons.subject,
          label: 'Subjects',
          color: Colors.purple,
          onTap: () {
            _showSubjectsDialog(context, instituteId);
          },
        ),
      ],
    );
  }

  void _showSelectTestDialog(BuildContext context, String instituteId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SelectTestSheet(instituteId: instituteId),
    );
  }

  void _showSubjectsDialog(BuildContext context, String instituteId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SubjectsSheet(instituteId: instituteId),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatchTestsCard extends ConsumerWidget {
  final String instituteId;
  final Batch batch;

  const _BatchTestsCard({
    required this.instituteId,
    required this.batch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testsAsync = ref.watch(batchTestsProvider((
      instituteId: instituteId,
      batchId: batch.id,
    )));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TestsListScreen(
                instituteId: instituteId,
                batchId: batch.id,
                batchName: batch.name,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  batch.name[0].toUpperCase(),
                  style: const TextStyle(
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
                      batch.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    testsAsync.when(
                      data: (tests) => Text(
                        '${tests.length} test${tests.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      loading: () => Text(
                        'Loading...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      error: (e, s) => const Text('Error'),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTestCard extends ConsumerWidget {
  final String instituteId;
  final Test test;

  const _RecentTestCard({
    required this.instituteId,
    required this.test,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            test.type.shortName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        title: Text(test.name),
        subtitle: Text(DateFormat('MMM d, yyyy').format(test.testDate)),
        trailing: TextButton(
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
          child: const Text('Grade'),
        ),
      ),
    );
  }
}

class _SelectTestSheet extends ConsumerWidget {
  final String instituteId;

  const _SelectTestSheet({required this.instituteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentTestsAsync = ref.watch(recentTestsProvider(instituteId));

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Test to Grade',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: recentTestsAsync.when(
                data: (tests) {
                  if (tests.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.quiz,
                      title: 'No Tests',
                      subtitle: 'Create a test first',
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: tests.length,
                    itemBuilder: (context, index) {
                      final test = tests[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(test.type.shortName),
                        ),
                        title: Text(test.name),
                        subtitle: Text(
                          '${DateFormat('MMM d').format(test.testDate)} • ${test.maxMarks.toStringAsFixed(0)} marks',
                        ),
                        onTap: () {
                          Navigator.pop(context);
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
                      );
                    },
                  );
                },
                loading: () => const ShimmerListLoading(
                  type: ShimmerListType.simple,
                ),
                error: (e, s) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SubjectsSheet extends ConsumerStatefulWidget {
  final String instituteId;

  const _SubjectsSheet({required this.instituteId});

  @override
  ConsumerState<_SubjectsSheet> createState() => _SubjectsSheetState();
}

class _SubjectsSheetState extends ConsumerState<_SubjectsSheet> {
  final _controller = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(subjectsProvider(widget.instituteId));

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Subjects',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      setState(() => _isAdding = true);
                    },
                  ),
                ],
              ),
            ),
            if (_isAdding) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Subject name',
                          isDense: true,
                        ),
                        autofocus: true,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: _addSubject,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _isAdding = false;
                          _controller.clear();
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: subjectsAsync.when(
                data: (subjects) {
                  if (subjects.isEmpty && !_isAdding) {
                    return const EmptyStateWidget(
                      icon: Icons.subject,
                      title: 'No Subjects',
                      subtitle: 'Add subjects to categorize tests',
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: subjects.length,
                    itemBuilder: (context, index) {
                      final subject = subjects[index];
                      return ListTile(
                        title: Text(subject.name),
                        subtitle: subject.code != null ? Text(subject.code!) : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteSubject(subject),
                        ),
                      );
                    },
                  );
                },
                loading: () => const ShimmerListLoading(
                  type: ShimmerListType.simple,
                  itemCount: 3,
                ),
                error: (e, s) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addSubject() async {
    if (_controller.text.trim().isEmpty) return;

    try {
      final subject = Subject(
        id: '',
        name: _controller.text.trim(),
        createdAt: DateTime.now(),
      );
      await ref.read(firestoreServiceProvider).createSubject(
            widget.instituteId,
            subject,
          );

      setState(() {
        _isAdding = false;
        _controller.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteSubject(Subject subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subject?'),
        content: Text('Are you sure you want to delete "${subject.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(firestoreServiceProvider).deleteSubject(
              widget.instituteId,
              subject.id,
            );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}
