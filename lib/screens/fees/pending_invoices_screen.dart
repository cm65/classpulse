import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../utils/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../providers/fee_providers.dart';
import '../../widgets/common_widgets.dart';
import 'record_payment_screen.dart';

/// Screen showing all pending and overdue invoices
class PendingInvoicesScreen extends ConsumerStatefulWidget {
  final String instituteId;

  const PendingInvoicesScreen({super.key, required this.instituteId});

  @override
  ConsumerState<PendingInvoicesScreen> createState() => _PendingInvoicesScreenState();
}

class _PendingInvoicesScreenState extends ConsumerState<PendingInvoicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(pendingInvoicesProvider(widget.instituteId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Dues'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overdue'),
            Tab(text: 'Pending'),
          ],
        ),
      ),
      body: invoicesAsync.when(
        data: (invoices) {
          final overdueInvoices = invoices.where((i) => i.isOverdue).toList();
          final pendingInvoices = invoices.where((i) => !i.isOverdue).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _InvoiceList(
                invoices: overdueInvoices,
                instituteId: widget.instituteId,
                emptyMessage: 'No overdue invoices',
                emptyIcon: Icons.check_circle,
              ),
              _InvoiceList(
                invoices: pendingInvoices,
                instituteId: widget.instituteId,
                emptyMessage: 'No pending invoices',
                emptyIcon: Icons.check_circle,
              ),
            ],
          );
        },
        loading: () => const ShimmerListLoading(type: ShimmerListType.simple, itemCount: 5),
        error: (error, stack) => ErrorStateWidget(
          error: error,
          onRetry: () => ref.invalidate(pendingInvoicesProvider(widget.instituteId)),
        ),
      ),
    );
  }
}

class _InvoiceList extends StatelessWidget {
  final List<FeeInvoice> invoices;
  final String instituteId;
  final String emptyMessage;
  final IconData emptyIcon;

  const _InvoiceList({
    required this.invoices,
    required this.instituteId,
    required this.emptyMessage,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) {
      return EmptyStateWidget(
        icon: emptyIcon,
        title: emptyMessage,
        subtitle: 'All caught up!',
      );
    }

    // Calculate total
    final total = invoices.fold<double>(0, (sum, inv) => sum + inv.balanceDue);

    return Column(
      children: [
        // Total header
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${invoices.length} invoice${invoices.length == 1 ? '' : 's'}',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              Text(
                'Total: \u20B9${total.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: invoices.length,
            itemBuilder: (context, index) {
              return _InvoiceCard(
                invoice: invoices[index],
                instituteId: instituteId,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InvoiceCard extends ConsumerWidget {
  final FeeInvoice invoice;
  final String instituteId;

  const _InvoiceCard({
    required this.invoice,
    required this.instituteId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get student and batch names
    return FutureBuilder<_InvoiceDetails>(
      future: _getDetails(ref),
      builder: (context, snapshot) {
        final details = snapshot.data;
        final studentName = details?.studentName ?? 'Loading...';
        final batchName = details?.batchName ?? '';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InkWell(
            onTap: () => _showInvoiceDetails(context),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: invoice.isOverdue
                            ? AppColors.absent.withValues(alpha: 0.1)
                            : AppColors.late.withValues(alpha: 0.1),
                        child: Text(
                          studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: invoice.isOverdue ? AppColors.absent : AppColors.late,
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
                              studentName,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Text(
                              batchName,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            invoice.formattedBalanceDue,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: invoice.isOverdue ? AppColors.absent : AppColors.textPrimary,
                                ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: invoice.isOverdue
                                  ? AppColors.absent.withValues(alpha: 0.1)
                                  : AppColors.late.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              invoice.status.displayName,
                              style: TextStyle(
                                fontSize: 11,
                                color: invoice.isOverdue ? AppColors.absent : AppColors.late,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: invoice.isOverdue ? AppColors.absent : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              invoice.isOverdue
                                  ? 'Overdue by ${DateTime.now().difference(invoice.dueDate).inDays} days'
                                  : 'Due: ${DateFormat('MMM d, yyyy').format(invoice.dueDate)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: invoice.isOverdue ? AppColors.absent : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
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
                        child: const Text('Record Payment'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<_InvoiceDetails> _getDetails(WidgetRef ref) async {
    final firestoreService = ref.read(firestoreServiceProvider);

    // Get batch first
    final batch = await firestoreService.getBatch(instituteId, invoice.batchId);

    // Get student from batch
    Student? student;
    if (batch != null) {
      final students = await firestoreService.getStudentsForBatch(instituteId, batch.id);
      student = students.firstWhere(
        (s) => s.id == invoice.studentId,
        orElse: () => Student(
          id: '',
          batchId: '',
          name: 'Unknown',
          parentPhone: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }

    return _InvoiceDetails(
      studentName: student?.name ?? 'Unknown',
      batchName: batch?.name ?? 'Unknown Batch',
    );
  }

  void _showInvoiceDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _InvoiceDetailsSheet(
        invoice: invoice,
        instituteId: instituteId,
      ),
    );
  }
}

class _InvoiceDetails {
  final String studentName;
  final String batchName;

  _InvoiceDetails({required this.studentName, required this.batchName});
}

class _InvoiceDetailsSheet extends StatelessWidget {
  final FeeInvoice invoice;
  final String instituteId;

  const _InvoiceDetailsSheet({
    required this.invoice,
    required this.instituteId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invoice Details',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),

          _DetailRow(
            label: 'Period',
            value: '${DateFormat('MMM d').format(invoice.periodStart)} - ${DateFormat('MMM d, yyyy').format(invoice.periodEnd)}',
          ),
          _DetailRow(
            label: 'Base Amount',
            value: invoice.formattedBaseAmount,
          ),
          if (invoice.discountAmount > 0)
            _DetailRow(
              label: 'Discount',
              value: '-\u20B9${invoice.discountAmount.toStringAsFixed(0)}',
              valueColor: AppColors.present,
            ),
          _DetailRow(
            label: 'Final Amount',
            value: invoice.formattedFinalAmount,
          ),
          _DetailRow(
            label: 'Paid',
            value: invoice.formattedPaidAmount,
            valueColor: AppColors.present,
          ),
          const Divider(height: 24),
          _DetailRow(
            label: 'Balance Due',
            value: invoice.formattedBalanceDue,
            valueColor: invoice.isOverdue ? AppColors.absent : AppColors.textPrimary,
            isBold: true,
          ),
          _DetailRow(
            label: 'Due Date',
            value: DateFormat('MMM d, yyyy').format(invoice.dueDate),
            valueColor: invoice.isOverdue ? AppColors.absent : null,
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
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
              child: const Text('Record Payment'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: valueColor,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                ),
          ),
        ],
      ),
    );
  }
}
