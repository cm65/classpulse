import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../utils/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../providers/fee_providers.dart';
import '../../widgets/common_widgets.dart';

/// Fee collection reports and analytics
class FeeReportsScreen extends ConsumerStatefulWidget {
  final String instituteId;

  const FeeReportsScreen({super.key, required this.instituteId});

  @override
  ConsumerState<FeeReportsScreen> createState() => _FeeReportsScreenState();
}

class _FeeReportsScreenState extends ConsumerState<FeeReportsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(feeCollectionSummaryProvider((
      instituteId: widget.instituteId,
      startDate: _startDate,
      endDate: _endDate,
    )));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Period',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(feeCollectionSummaryProvider((
            instituteId: widget.instituteId,
            startDate: _startDate,
            endDate: _endDate,
          )));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Date range indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Text(
                    '${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _selectDateRange,
                    child: const Text('Change'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Summary
            summaryAsync.when(
              data: (summary) => _ReportContent(summary: summary),
              loading: () => const _ReportLoading(),
              error: (error, stack) => ErrorStateWidget(
                error: error,
                onRetry: () => ref.invalidate(feeCollectionSummaryProvider((
                  instituteId: widget.instituteId,
                  startDate: _startDate,
                  endDate: _endDate,
                ))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }
}

class _ReportLoading extends StatelessWidget {
  const _ReportLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ShimmerSummaryCard(),
        const SizedBox(height: 16),
        const ShimmerSummaryCard(),
        const SizedBox(height: 16),
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

class _ReportContent extends StatelessWidget {
  final FeeCollectionSummary summary;

  const _ReportContent({required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary.invoiceCount == 0) {
      return const EmptyStateWidget(
        icon: Icons.receipt_long,
        title: 'No Fee Data',
        subtitle: 'No invoices found for the selected period. Try changing the date range.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main collection card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Collection Summary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      summary.formattedTotalCollected,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.present,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'collected',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: summary.collectionRate / 100,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      summary.collectionRate >= 80
                          ? AppColors.present
                          : summary.collectionRate >= 50
                              ? AppColors.late
                              : AppColors.absent,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${summary.collectionRate.toStringAsFixed(1)}% of ${summary.formattedTotalBilled}',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    Text(
                      'Pending: ${summary.formattedTotalPending}',
                      style: TextStyle(color: AppColors.late, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Stats row
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Total Billed',
                value: summary.formattedTotalBilled,
                icon: Icons.receipt_long,
                color: AppColors.primary,
                subtitle: '${summary.invoiceCount} invoices',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Overdue',
                value: summary.formattedTotalOverdue,
                icon: Icons.warning_amber,
                color: AppColors.absent,
                subtitle: '${summary.overdueInvoiceCount} invoices',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Invoice breakdown
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                              value: summary.paidInvoiceCount.toDouble(),
                              color: AppColors.present,
                              title: '',
                              radius: 40,
                            ),
                            PieChartSectionData(
                              value: summary.partialInvoiceCount.toDouble(),
                              color: AppColors.late,
                              title: '',
                              radius: 40,
                            ),
                            PieChartSectionData(
                              value: summary.overdueInvoiceCount.toDouble(),
                              color: AppColors.absent,
                              title: '',
                              radius: 40,
                            ),
                            PieChartSectionData(
                              value: (summary.invoiceCount -
                                      summary.paidInvoiceCount -
                                      summary.partialInvoiceCount -
                                      summary.overdueInvoiceCount)
                                  .toDouble(),
                              color: AppColors.border,
                              title: '',
                              radius: 40,
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
                          _LegendItem(
                            color: AppColors.present,
                            label: 'Paid',
                            value: '${summary.paidInvoiceCount}',
                          ),
                          const SizedBox(height: 8),
                          _LegendItem(
                            color: AppColors.late,
                            label: 'Partial',
                            value: '${summary.partialInvoiceCount}',
                          ),
                          const SizedBox(height: 8),
                          _LegendItem(
                            color: AppColors.absent,
                            label: 'Overdue',
                            value: '${summary.overdueInvoiceCount}',
                          ),
                          const SizedBox(height: 8),
                          _LegendItem(
                            color: AppColors.border,
                            label: 'Pending',
                            value: '${summary.invoiceCount - summary.paidInvoiceCount - summary.partialInvoiceCount - summary.overdueInvoiceCount}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Collection by method
        if (summary.collectionByMethod.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Collection by Method',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  ...summary.collectionByMethod.entries.map((entry) {
                    final percentage = summary.totalCollected > 0
                        ? (entry.value / summary.totalCollected) * 100
                        : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _getMethodIcon(entry.key),
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(entry.key.displayName),
                                ],
                              ),
                              Text(
                                '\u20B9${entry.value.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: percentage / 100,
                              minHeight: 4,
                              backgroundColor: AppColors.border,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getMethodColor(entry.key),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  IconData _getMethodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return Icons.money;
      case PaymentMethod.upi:
        return Icons.qr_code;
      case PaymentMethod.bankTransfer:
        return Icons.account_balance;
      case PaymentMethod.cheque:
        return Icons.description;
      case PaymentMethod.card:
        return Icons.credit_card;
      case PaymentMethod.other:
        return Icons.payment;
    }
  }

  Color _getMethodColor(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return AppColors.present;
      case PaymentMethod.upi:
        return Colors.deepPurple;
      case PaymentMethod.bankTransfer:
        return Colors.blue;
      case PaymentMethod.cheque:
        return Colors.orange;
      case PaymentMethod.card:
        return Colors.indigo;
      case PaymentMethod.other:
        return AppColors.textSecondary;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
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
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              subtitle,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
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
        Expanded(child: Text(label)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
