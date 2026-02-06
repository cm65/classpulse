import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../providers/fee_providers.dart';
import '../../widgets/common_widgets.dart';
import 'fee_structures_screen.dart';
import 'pending_invoices_screen.dart';
import 'record_payment_screen.dart';
import 'fee_reports_screen.dart';

/// Main fees dashboard showing overview and quick actions
class FeesDashboardScreen extends ConsumerWidget {
  const FeesDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacher = ref.watch(currentTeacherProvider).value;
    if (teacher == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final dashboardAsync = ref.watch(feeDashboardProvider(teacher.instituteId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee Management'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(feeDashboardProvider(teacher.instituteId));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Dashboard stats
            dashboardAsync.when(
              data: (data) => _DashboardStats(data: data),
              loading: () => const _DashboardStatsLoading(),
              error: (error, stack) => ErrorStateWidget(
                error: error,
                onRetry: () => ref.invalidate(feeDashboardProvider(teacher.instituteId)),
                compact: true,
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
            _QuickActionGrid(instituteId: teacher.instituteId),
            const SizedBox(height: 24),

            // Recent activity section
            Text(
              'Pending Invoices',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _PendingInvoicesPreview(instituteId: teacher.instituteId),
          ],
        ),
      ),
    );
  }
}

class _DashboardStats extends StatelessWidget {
  final FeeDashboardData data;

  const _DashboardStats({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Main collection card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "This Month's Collection",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      data.formattedMonthlyCollection,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.present,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'of ${data.formattedMonthlyBilled}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: data.collectionRate / 100,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      data.collectionRate >= 80
                          ? AppColors.present
                          : data.collectionRate >= 50
                              ? AppColors.late
                              : AppColors.absent,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${data.collectionRate.toStringAsFixed(1)}% collected',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Pending and overdue row
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Pending',
                value: data.formattedTotalPending,
                count: '${data.pendingInvoiceCount} invoices',
                icon: Icons.pending_actions,
                color: AppColors.late,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Overdue',
                value: data.formattedTotalOverdue,
                count: '${data.overdueInvoiceCount} invoices',
                icon: Icons.warning_amber,
                color: AppColors.absent,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DashboardStatsLoading extends StatelessWidget {
  const _DashboardStatsLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ShimmerSummaryCard(),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(child: ShimmerSummaryCard()),
            SizedBox(width: 12),
            Expanded(child: ShimmerSummaryCard()),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String count;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.count,
    required this.icon,
    required this.color,
  });

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
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Text(
              count,
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

class _QuickActionGrid extends StatelessWidget {
  final String instituteId;

  const _QuickActionGrid({required this.instituteId});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _QuickActionCard(
          icon: Icons.receipt_long,
          label: 'Generate Invoices',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FeeStructuresScreen(instituteId: instituteId),
              ),
            );
          },
        ),
        _QuickActionCard(
          icon: Icons.payment,
          label: 'Record Payment',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecordPaymentScreen(instituteId: instituteId),
              ),
            );
          },
        ),
        _QuickActionCard(
          icon: Icons.pending,
          label: 'Pending Dues',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PendingInvoicesScreen(instituteId: instituteId),
              ),
            );
          },
        ),
        _QuickActionCard(
          icon: Icons.bar_chart,
          label: 'Fee Reports',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FeeReportsScreen(instituteId: instituteId),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
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
              Icon(icon, color: AppColors.primary, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingInvoicesPreview extends ConsumerWidget {
  final String instituteId;

  const _PendingInvoicesPreview({required this.instituteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(pendingInvoicesProvider(instituteId));

    return invoicesAsync.when(
      data: (invoices) {
        if (invoices.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 48,
                      color: AppColors.present,
                    ),
                    const SizedBox(height: 12),
                    const Text('All fees collected!'),
                  ],
                ),
              ),
            ),
          );
        }

        // Show first 5 pending invoices
        final displayInvoices = invoices.take(5).toList();

        return Card(
          child: Column(
            children: [
              ...displayInvoices.map((invoice) => _InvoiceListTile(
                    invoice: invoice,
                    instituteId: instituteId,
                  )),
              if (invoices.length > 5)
                ListTile(
                  leading: const Icon(Icons.more_horiz),
                  title: Text('View all ${invoices.length} pending invoices'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PendingInvoicesScreen(instituteId: instituteId),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
      loading: () => const ShimmerListLoading(type: ShimmerListType.simple, itemCount: 3),
      error: (error, stack) => ErrorStateWidget(
        error: error,
        onRetry: () => ref.invalidate(pendingInvoicesProvider(instituteId)),
        compact: true,
      ),
    );
  }
}

class _InvoiceListTile extends ConsumerWidget {
  final FeeInvoice invoice;
  final String instituteId;

  const _InvoiceListTile({
    required this.invoice,
    required this.instituteId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get student name from batch students
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: invoice.isOverdue
            ? AppColors.absent.withValues(alpha: 0.1)
            : AppColors.late.withValues(alpha: 0.1),
        child: Icon(
          invoice.isOverdue ? Icons.warning : Icons.receipt,
          color: invoice.isOverdue ? AppColors.absent : AppColors.late,
          size: 20,
        ),
      ),
      title: Text(invoice.formattedBalanceDue),
      subtitle: Text(
        invoice.isOverdue ? 'Overdue' : 'Due ${_formatDueDate(invoice.dueDate)}',
        style: TextStyle(
          color: invoice.isOverdue ? AppColors.absent : AppColors.textSecondary,
        ),
      ),
      trailing: TextButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecordPaymentScreen(
                instituteId: instituteId,
                preselectedInvoiceId: invoice.id,
              ),
            ),
          );
        },
        child: const Text('Pay'),
      ),
    );
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'tomorrow';
    if (diff < 7) return 'in $diff days';
    return '${date.day}/${date.month}';
  }
}
