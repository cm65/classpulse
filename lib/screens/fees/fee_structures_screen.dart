import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../utils/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../providers/fee_providers.dart';
import '../../widgets/common_widgets.dart';

/// Screen to manage fee structures for batches
class FeeStructuresScreen extends ConsumerStatefulWidget {
  final String instituteId;

  const FeeStructuresScreen({super.key, required this.instituteId});

  @override
  ConsumerState<FeeStructuresScreen> createState() => _FeeStructuresScreenState();
}

class _FeeStructuresScreenState extends ConsumerState<FeeStructuresScreen> {
  @override
  Widget build(BuildContext context) {
    final feeStructuresAsync = ref.watch(allFeeStructuresProvider(widget.instituteId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee Structures'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateFeeDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Fee'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allFeeStructuresProvider(widget.instituteId));
        },
        child: feeStructuresAsync.when(
          data: (feeStructures) {
            if (feeStructures.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.receipt_long_outlined,
                title: 'No Fee Structures',
                subtitle: 'Add fee structures for your batches to start billing',
              );
            }

            // Group by batch
            final groupedFees = <String, List<FeeStructure>>{};
            for (final fee in feeStructures) {
              groupedFees.putIfAbsent(fee.batchId, () => []).add(fee);
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groupedFees.length,
              itemBuilder: (context, index) {
                final batchId = groupedFees.keys.elementAt(index);
                final batchFees = groupedFees[batchId]!;
                return _BatchFeeCard(
                  instituteId: widget.instituteId,
                  batchId: batchId,
                  feeStructures: batchFees,
                  onGenerateInvoices: () => _showGenerateInvoicesDialog(context, batchFees.first),
                );
              },
            );
          },
          loading: () => const ShimmerListLoading(type: ShimmerListType.batch, itemCount: 3),
          error: (error, stack) => ErrorStateWidget(
            error: error,
            onRetry: () => ref.invalidate(allFeeStructuresProvider(widget.instituteId)),
          ),
        ),
      ),
    );
  }

  void _showCreateFeeDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CreateFeeStructureSheet(instituteId: widget.instituteId),
    );
  }

  void _showGenerateInvoicesDialog(BuildContext context, FeeStructure fee) {
    showDialog(
      context: context,
      builder: (context) => _GenerateInvoicesDialog(
        instituteId: widget.instituteId,
        feeStructure: fee,
      ),
    );
  }
}

class _BatchFeeCard extends ConsumerWidget {
  final String instituteId;
  final String batchId;
  final List<FeeStructure> feeStructures;
  final VoidCallback onGenerateInvoices;

  const _BatchFeeCard({
    required this.instituteId,
    required this.batchId,
    required this.feeStructures,
    required this.onGenerateInvoices,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchAsync = ref.watch(firestoreServiceProvider).getBatch(instituteId, batchId);

    return FutureBuilder<Batch?>(
      future: batchAsync,
      builder: (context, snapshot) {
        final batchName = snapshot.data?.name ?? 'Unknown Batch';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.groups, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        batchName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onGenerateInvoices,
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('Generate'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...feeStructures.map((fee) => _FeeStructureTile(
                    fee: fee,
                    instituteId: instituteId,
                  )),
            ],
          ),
        );
      },
    );
  }
}

class _FeeStructureTile extends ConsumerWidget {
  final FeeStructure fee;
  final String instituteId;

  const _FeeStructureTile({
    required this.fee,
    required this.instituteId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.currency_rupee,
          color: AppColors.primary,
          size: 20,
        ),
      ),
      title: Text(fee.name),
      subtitle: Text(
        '${fee.formattedAmount} / ${fee.cycle.displayName}',
        style: TextStyle(color: AppColors.textSecondary),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'edit') {
            _showEditDialog(context, fee);
          } else if (value == 'delete') {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete Fee Structure?'),
                content: const Text('This will not affect existing invoices.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: AppColors.absent),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await ref.read(firestoreServiceProvider).deleteFeeStructure(instituteId, fee.id);
            }
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, size: 20),
                SizedBox(width: 12),
                Text('Edit'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, size: 20, color: AppColors.absent),
                SizedBox(width: 12),
                Text('Delete', style: TextStyle(color: AppColors.absent)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, FeeStructure fee) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CreateFeeStructureSheet(
        instituteId: instituteId,
        existingFee: fee,
      ),
    );
  }
}

class _CreateFeeStructureSheet extends ConsumerStatefulWidget {
  final String instituteId;
  final FeeStructure? existingFee;

  const _CreateFeeStructureSheet({
    required this.instituteId,
    this.existingFee,
  });

  @override
  ConsumerState<_CreateFeeStructureSheet> createState() => _CreateFeeStructureSheetState();
}

class _CreateFeeStructureSheetState extends ConsumerState<_CreateFeeStructureSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedBatchId;
  BillingCycle _selectedCycle = BillingCycle.monthly;
  DateTime _effectiveFrom = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingFee != null) {
      _nameController.text = widget.existingFee!.name;
      _amountController.text = widget.existingFee!.amount.toStringAsFixed(0);
      _descriptionController.text = widget.existingFee!.description ?? '';
      _selectedBatchId = widget.existingFee!.batchId;
      _selectedCycle = widget.existingFee!.cycle;
      _effectiveFrom = widget.existingFee!.effectiveFrom;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(firestoreServiceProvider).batchesStream(widget.instituteId);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existingFee != null ? 'Edit Fee Structure' : 'Create Fee Structure',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),

              // Batch selector
              StreamBuilder<List<Batch>>(
                stream: batchesAsync,
                builder: (context, snapshot) {
                  final batches = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    value: _selectedBatchId,
                    decoration: const InputDecoration(
                      labelText: 'Batch',
                      prefixIcon: Icon(Icons.groups),
                    ),
                    items: batches
                        .where((b) => b.isActive)
                        .map((b) => DropdownMenuItem(
                              value: b.id,
                              child: Text(b.name),
                            ))
                        .toList(),
                    onChanged: widget.existingFee != null
                        ? null
                        : (value) => setState(() => _selectedBatchId = value),
                    validator: (value) =>
                        value == null ? 'Please select a batch' : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              // Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Fee Name',
                  prefixIcon: Icon(Icons.label),
                  hintText: 'e.g., Monthly Tuition',
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 16),

              // Amount field
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter an amount';
                  final amount = double.tryParse(value!);
                  if (amount == null || amount <= 0) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Billing cycle
              DropdownButtonFormField<BillingCycle>(
                value: _selectedCycle,
                decoration: const InputDecoration(
                  labelText: 'Billing Cycle',
                  prefixIcon: Icon(Icons.calendar_month),
                ),
                items: BillingCycle.values
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.displayName),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCycle = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Effective from date
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: const Text('Effective From'),
                subtitle: Text(DateFormat('MMM d, yyyy').format(_effectiveFrom)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _effectiveFrom,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    setState(() => _effectiveFrom = date);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Description (optional)
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Save button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveFeeStructure,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.existingFee != null ? 'Update' : 'Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveFeeStructure() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final firestoreService = ref.read(firestoreServiceProvider);

      if (widget.existingFee != null) {
        // Update existing
        await firestoreService.updateFeeStructure(
          widget.instituteId,
          widget.existingFee!.id,
          {
            'name': _nameController.text.trim(),
            'amount': double.parse(_amountController.text),
            'cycle': _selectedCycle.name,
            'effectiveFrom': _effectiveFrom,
            'description': _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
          },
        );
      } else {
        // Create new
        final fee = FeeStructure(
          id: '',
          batchId: _selectedBatchId!,
          name: _nameController.text.trim(),
          amount: double.parse(_amountController.text),
          cycle: _selectedCycle,
          effectiveFrom: _effectiveFrom,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          createdAt: now,
          updatedAt: now,
        );
        await firestoreService.createFeeStructure(widget.instituteId, fee);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingFee != null
                ? 'Fee structure updated'
                : 'Fee structure created'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.absent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _GenerateInvoicesDialog extends ConsumerStatefulWidget {
  final String instituteId;
  final FeeStructure feeStructure;

  const _GenerateInvoicesDialog({
    required this.instituteId,
    required this.feeStructure,
  });

  @override
  ConsumerState<_GenerateInvoicesDialog> createState() => _GenerateInvoicesDialogState();
}

class _GenerateInvoicesDialogState extends ConsumerState<_GenerateInvoicesDialog> {
  late DateTime _periodStart;
  late DateTime _periodEnd;
  late DateTime _dueDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    // Default period based on billing cycle
    switch (widget.feeStructure.cycle) {
      case BillingCycle.monthly:
        _periodStart = DateTime(now.year, now.month, 1);
        _periodEnd = DateTime(now.year, now.month + 1, 0);
        break;
      case BillingCycle.quarterly:
        final quarter = ((now.month - 1) ~/ 3) * 3 + 1;
        _periodStart = DateTime(now.year, quarter, 1);
        _periodEnd = DateTime(now.year, quarter + 3, 0);
        break;
      case BillingCycle.halfYearly:
        final half = now.month <= 6 ? 1 : 7;
        _periodStart = DateTime(now.year, half, 1);
        _periodEnd = DateTime(now.year, half + 6, 0);
        break;
      case BillingCycle.yearly:
        _periodStart = DateTime(now.year, 1, 1);
        _periodEnd = DateTime(now.year, 12, 31);
        break;
      case BillingCycle.oneTime:
        _periodStart = now;
        _periodEnd = now;
        break;
    }

    // Due date is 15 days after period start
    _dueDate = _periodStart.add(const Duration(days: 15));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Generate Invoices'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.feeStructure.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            '${widget.feeStructure.formattedAmount} / ${widget.feeStructure.cycle.displayName}',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Period
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.date_range, size: 20),
            title: const Text('Billing Period'),
            subtitle: Text(
              '${DateFormat('MMM d').format(_periodStart)} - ${DateFormat('MMM d, yyyy').format(_periodEnd)}',
            ),
          ),

          // Due date
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.event, size: 20),
            title: const Text('Due Date'),
            subtitle: Text(DateFormat('MMM d, yyyy').format(_dueDate)),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _dueDate,
                firstDate: _periodStart,
                lastDate: _periodEnd.add(const Duration(days: 30)),
              );
              if (date != null) {
                setState(() => _dueDate = date);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _generateInvoices,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Generate'),
        ),
      ],
    );
  }

  Future<void> _generateInvoices() async {
    setState(() => _isLoading = true);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final invoiceIds = await firestoreService.generateBatchInvoices(
        widget.instituteId,
        widget.feeStructure.batchId,
        widget.feeStructure.id,
        _periodStart,
        _periodEnd,
        _dueDate,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generated ${invoiceIds.length} invoices'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.absent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
