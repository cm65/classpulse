import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../utils/theme.dart';
import '../../utils/design_tokens.dart';
import '../../utils/helpers.dart';
import '../../services/services.dart';
import '../../models/models.dart';
import '../../widgets/common_widgets.dart';
import '../../providers/report_providers.dart';
import '../attendance/attendance_screen.dart';
import '../batches/batch_list_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../analytics/analytics_screen.dart';
import '../fees/fees_dashboard_screen.dart';
import '../performance/performance_dashboard_screen.dart';

/// Provider for current institute
final currentInstituteProvider = StreamProvider<Institute?>((ref) {
  final teacher = ref.watch(currentTeacherProvider).value;
  if (teacher == null) return Stream.value(null);
  return ref.watch(firestoreServiceProvider).instituteStream(teacher.instituteId);
});

/// Provider for batches
final dashboardBatchesProvider = StreamProvider<List<Batch>>((ref) {
  final teacher = ref.watch(currentTeacherProvider).value;
  if (teacher == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).batchesStream(teacher.instituteId);
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final connectivity = ref.watch(connectivityProvider);
    final isOffline = connectivity.value?.isOffline ?? false;
    final lastOnlineAt = ref.read(connectivityServiceProvider).lastOnlineAt;

    return Scaffold(
      body: Column(
        children: [
          // Offline banner
          if (isOffline) OfflineBanner(lastOnlineAt: lastOnlineAt),

          // Main content
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: const [
                _HomeTab(),
                BatchListScreen(),
                ReportsScreen(),
                SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            activeIcon: Icon(Icons.groups),
            label: 'Batches',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacher = ref.watch(currentTeacherProvider);
    final institute = ref.watch(currentInstituteProvider);
    final batches = ref.watch(dashboardBatchesProvider);

    return teacher.when(
      data: (teacherData) {
        if (teacherData == null) {
          return const Center(child: Text('No teacher data'));
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardBatchesProvider);
            ref.invalidate(todaysSummaryProvider(teacherData.instituteId));
          },
          child: CustomScrollView(
            slivers: [
            // App bar
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  institute.value?.name ?? 'Dashboard',
                  style: const TextStyle(fontSize: 16),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary,
                        AppColors.primaryDark,
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notifications coming soon!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),

            // Welcome message
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${teacherData.name}!',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

            // Quick actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),

            // Batch list for quick attendance
            batches.when(
              data: (batchList) {
                if (batchList.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Card(
                      margin: const EdgeInsets.all(16),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.add_circle_outline,
                              size: 48,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No batches yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Create your first batch to start marking attendance',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  PageTransitions.slideRight(
                                    const BatchListScreen(
                                      showCreateDialog: true,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Create Batch'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final batch = batchList[index];
                      return _BatchCard(
                        batch: batch,
                        instituteId: teacherData.instituteId,
                      );
                    },
                    childCount: batchList.length,
                  ),
                );
              },
              loading: () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const ShimmerBatchCard(),
                  childCount: 3,
                ),
              ),
              error: (error, stack) => SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('Error: $error'),
                  ),
                ),
              ),
            ),

            // Today's summary section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Summary",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _TodaySummaryCards(instituteId: teacherData.instituteId),
                  ],
                ),
              ),
            ),

            // Analytics section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _AnalyticsCard(instituteId: teacherData.instituteId),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Fee Management section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _FeeManagementCard(),
              ),
            ),

            // Performance/Grades section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _PerformanceCard(),
              ),
            ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 16),
            ),
          ],
          ),
        );
      },
      loading: () => const ShimmerListLoading(type: ShimmerListType.batch, itemCount: 3),
      error: (error, stack) => ErrorStateWidget(
        error: error,
        onRetry: () => ref.invalidate(dashboardBatchesProvider),
        compact: true,
      ),
    );
  }
}

class _BatchCard extends StatelessWidget {
  final Batch batch;
  final String instituteId;

  const _BatchCard({
    required this.batch,
    required this.instituteId,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${batch.name} batch. ${batch.formattedSchedule}. Tap to mark attendance.',
      button: true,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              PageTransitions.slideRight(
                AttendanceScreen(
                  batch: batch,
                  instituteId: instituteId,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.groups,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
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
                    if (batch.subject != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        batch.subject!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      batch.formattedSchedule,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, size: 16, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Mark',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _TodaySummaryCards extends ConsumerWidget {
  final String instituteId;

  const _TodaySummaryCards({required this.instituteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(todaysSummaryProvider(instituteId));

    return summaryAsync.when(
      data: (data) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SummaryCard(
                  title: 'Present',
                  value: data.totalPresent.toString(),
                  icon: Icons.check_circle,
                  color: AppColors.present,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SummaryCard(
                  title: 'Absent',
                  value: data.totalAbsent.toString(),
                  icon: Icons.cancel,
                  color: AppColors.absent,
                  onTap: data.totalAbsent > 0
                      ? () {
                          // Navigate to absent list in reports
                          final dashboardState = context.findAncestorStateOfType<_DashboardScreenState>();
                          if (dashboardState != null) {
                            dashboardState.setState(() {
                              dashboardState._currentIndex = 2; // Reports tab
                            });
                          }
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SummaryCard(
                  title: 'Late',
                  value: data.totalLate.toString(),
                  icon: Icons.access_time,
                  color: AppColors.late,
                ),
              ),
            ],
          ),
          if (data.batchesMarked > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${data.batchesMarked} batch${data.batchesMarked == 1 ? '' : 'es'} marked',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  Text(
                    '${data.overallAttendanceRate.toStringAsFixed(1)}% attendance',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      loading: () => const Row(
        children: [
          Expanded(child: ShimmerSummaryCard()),
          SizedBox(width: 12),
          Expanded(child: ShimmerSummaryCard()),
          SizedBox(width: 12),
          Expanded(child: ShimmerSummaryCard()),
        ],
      ),
      error: (error, stack) => Center(
        child: Text(
          'Error loading summary',
          style: TextStyle(color: AppColors.error),
        ),
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String instituteId;

  const _AnalyticsCard({required this.instituteId});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            PageTransitions.slideRight(const AnalyticsScreen()),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primaryDark,
              ],
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.insights,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Analytics Dashboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'View attendance trends, at-risk students & more',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeeManagementCard extends StatelessWidget {
  const _FeeManagementCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            PageTransitions.slideRight(const FeesDashboardScreen()),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.teal.shade600,
                Colors.teal.shade800,
              ],
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fee Management',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track payments, generate invoices & reports',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PerformanceCard extends ConsumerWidget {
  const _PerformanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacher = ref.watch(currentTeacherProvider).value;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (teacher != null) {
            Navigator.push(
              context,
              PageTransitions.slideRight(
                PerformanceDashboardScreen(
                  instituteId: teacher.instituteId,
                ),
              ),
            );
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.purple.shade600,
                Colors.purple.shade800,
              ],
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.school,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Performance & Grades',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create tests, enter scores & track progress',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
