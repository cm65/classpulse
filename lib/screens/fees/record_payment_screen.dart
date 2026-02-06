import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../utils/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../providers/fee_providers.dart';
import '../../widgets/common_widgets.dart';

/// Screen to record a payment for an invoice
class RecordPaymentScreen extends ConsumerStatefulWidget {
  final String instituteId;
  final String? preselectedInvoiceId;

  const RecordPaymentScreen({
    super.key,
    required this.instituteId,
    this.preselectedInvoiceId,
  });

  @override
  ConsumerState<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends ConsumerState<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _transactionIdController = TextEditingController();
  final _notesController = TextEditingController();

  FeeInvoice? _selectedInvoice;
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  DateTime _paymentDate = DateTime.now();
  bool _isLoading = false;
  bool _payFullAmount = true;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedInvoiceId != null) {
      _loadPreselectedInvoice();
    }
  }

  Future<void> _loadPreselectedInvoice() async {
    final invoice = await ref.read(firestoreServiceProvider)
        .getInvoice(widget.instituteId, widget.preselectedInvoiceId!);
    if (invoice != null && mounted) {
      setState(() {
        _selectedInvoice = invoice;
        _amountController.text = invoice.balanceDue.toStringAsFixed(0);
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _transactionIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingInvoicesAsync = ref.watch(pendingInvoicesProvider(widget.instituteId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Payment'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Invoice selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Invoice',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    pendingInvoicesAsync.when(
                      data: (invoices) {
                        if (invoices.isEmpty) {
                          return const Text('No pending invoices');
                        }
                        return _buildInvoiceDropdown(invoices);
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (e, s) => Text('Error: $e'),
                    ),
                    if (_selectedInvoice != null) ...[
                      const SizedBox(height: 16),
                      _InvoiceSummary(invoice: _selectedInvoice!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Payment details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),

                    // Amount
                    if (_selectedInvoice != null) ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Pay full balance'),
                        subtitle: Text(_selectedInvoice!.formattedBalanceDue),
                        value: _payFullAmount,
                        onChanged: (value) {
                          setState(() {
                            _payFullAmount = value;
                            if (value) {
                              _amountController.text =
                                  _selectedInvoice!.balanceDue.toStringAsFixed(0);
                            }
                          });
                        },
                      ),
                      if (!_payFullAmount) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _amountController,
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            prefixIcon: Icon(Icons.currency_rupee),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Enter amount';
                            final amount = double.tryParse(value!);
                            if (amount == null || amount <= 0) return 'Invalid amount';
                            if (amount > _selectedInvoice!.balanceDue) {
                              return 'Amount exceeds balance';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],

                    // Payment method
                    DropdownButtonFormField<PaymentMethod>(
                      value: _selectedMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        prefixIcon: Icon(Icons.payment),
                      ),
                      items: PaymentMethod.values
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(m.displayName),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedMethod = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Transaction ID (for non-cash payments)
                    if (_selectedMethod != PaymentMethod.cash) ...[
                      TextFormField(
                        controller: _transactionIdController,
                        decoration: InputDecoration(
                          labelText: _selectedMethod == PaymentMethod.upi
                              ? 'UPI Transaction ID'
                              : _selectedMethod == PaymentMethod.cheque
                                  ? 'Cheque Number'
                                  : 'Transaction ID',
                          prefixIcon: const Icon(Icons.tag),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Payment date
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Payment Date'),
                      subtitle: Text(DateFormat('MMM d, yyyy').format(_paymentDate)),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _paymentDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _paymentDate = date);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        prefixIcon: Icon(Icons.notes),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit button
            ElevatedButton(
              onPressed: _selectedInvoice != null && !_isLoading
                  ? _recordPayment
                  : null,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Record Payment'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceDropdown(List<FeeInvoice> invoices) {
    return FutureBuilder<Map<String, _InvoiceDisplayInfo>>(
      future: _getInvoiceDisplayInfos(invoices),
      builder: (context, snapshot) {
        final displayInfos = snapshot.data ?? {};

        return DropdownButtonFormField<String>(
          value: _selectedInvoice?.id,
          decoration: const InputDecoration(
            hintText: 'Select an invoice',
            prefixIcon: Icon(Icons.receipt),
          ),
          items: invoices.map((invoice) {
            final info = displayInfos[invoice.id];
            return DropdownMenuItem(
              value: invoice.id,
              child: Text(
                info != null
                    ? '${info.studentName} - ${invoice.formattedBalanceDue}'
                    : 'Invoice ${invoice.id.substring(0, 6)}...',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              final invoice = invoices.firstWhere((i) => i.id == value);
              setState(() {
                _selectedInvoice = invoice;
                _amountController.text = invoice.balanceDue.toStringAsFixed(0);
                _payFullAmount = true;
              });
            }
          },
          validator: (value) => value == null ? 'Please select an invoice' : null,
        );
      },
    );
  }

  Future<Map<String, _InvoiceDisplayInfo>> _getInvoiceDisplayInfos(
    List<FeeInvoice> invoices,
  ) async {
    final result = <String, _InvoiceDisplayInfo>{};
    final firestoreService = ref.read(firestoreServiceProvider);

    for (final invoice in invoices) {
      final batch = await firestoreService.getBatch(widget.instituteId, invoice.batchId);
      if (batch != null) {
        final students = await firestoreService.getStudentsForBatch(
          widget.instituteId,
          batch.id,
        );
        final student = students.firstWhere(
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
        result[invoice.id] = _InvoiceDisplayInfo(
          studentName: student.name,
          batchName: batch.name,
        );
      }
    }
    return result;
  }

  Future<void> _recordPayment() async {
    if (!_formKey.currentState!.validate() || _selectedInvoice == null) return;

    setState(() => _isLoading = true);

    try {
      final teacher = ref.read(currentTeacherProvider).value;
      if (teacher == null) throw Exception('No teacher logged in');

      final amount = _payFullAmount
          ? _selectedInvoice!.balanceDue
          : double.parse(_amountController.text);

      final payment = Payment(
        id: '',
        invoiceId: _selectedInvoice!.id,
        studentId: _selectedInvoice!.studentId,
        amount: amount,
        method: _selectedMethod,
        paidAt: _paymentDate,
        transactionId: _transactionIdController.text.trim().isEmpty
            ? null
            : _transactionIdController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        collectedBy: teacher.id,
        createdAt: DateTime.now(),
      );

      await ref.read(firestoreServiceProvider).recordPayment(
            widget.instituteId,
            payment,
            _selectedInvoice!.id,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment of \u20B9${amount.toStringAsFixed(0)} recorded'),
            backgroundColor: AppColors.present,
          ),
        );
        Navigator.pop(context);
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

class _InvoiceDisplayInfo {
  final String studentName;
  final String batchName;

  _InvoiceDisplayInfo({required this.studentName, required this.batchName});
}

class _InvoiceSummary extends StatelessWidget {
  final FeeInvoice invoice;

  const _InvoiceSummary({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount'),
              Text(invoice.formattedFinalAmount),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Already Paid'),
              Text(
                invoice.formattedPaidAmount,
                style: const TextStyle(color: AppColors.present),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Balance Due',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                invoice.formattedBalanceDue,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: invoice.isOverdue ? AppColors.absent : AppColors.primary,
                    ),
              ),
            ],
          ),
          if (invoice.isOverdue) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.absent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning, size: 14, color: AppColors.absent),
                  const SizedBox(width: 4),
                  Text(
                    'Overdue by ${DateTime.now().difference(invoice.dueDate).inDays} days',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.absent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
