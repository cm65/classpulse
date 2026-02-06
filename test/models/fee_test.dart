import 'package:flutter_test/flutter_test.dart';
import 'package:classpulse/models/fee.dart';

import '../helpers/test_data.dart';

void main() {
  group('BillingCycle', () {
    test('monthsCount returns correct values', () {
      expect(BillingCycle.monthly.monthsCount, 1);
      expect(BillingCycle.quarterly.monthsCount, 3);
      expect(BillingCycle.halfYearly.monthsCount, 6);
      expect(BillingCycle.yearly.monthsCount, 12);
      expect(BillingCycle.oneTime.monthsCount, 0);
    });

    test('displayName returns human-readable values', () {
      expect(BillingCycle.monthly.displayName, 'Monthly');
      expect(BillingCycle.quarterly.displayName, 'Quarterly');
      expect(BillingCycle.halfYearly.displayName, 'Half-Yearly');
      expect(BillingCycle.yearly.displayName, 'Yearly');
      expect(BillingCycle.oneTime.displayName, 'One-Time');
    });
  });

  group('FeeStructure', () {
    test('formattedAmount formats correctly', () {
      final fee = TestData.feeStructure(amount: 5000);
      expect(fee.formattedAmount, '\u20B95000');
    });

    test('toFirestore and back preserves data', () {
      final fee = TestData.feeStructure();
      final data = fee.toFirestore();

      expect(data['batchId'], 'batch-1');
      expect(data['name'], 'Monthly Tuition');
      expect(data['amount'], 5000);
      expect(data['cycle'], 'monthly');
      expect(data['isActive'], true);
    });

    test('copyWith works correctly', () {
      final fee = TestData.feeStructure();
      final updated = fee.copyWith(amount: 6000, name: 'Updated Fee');

      expect(updated.amount, 6000);
      expect(updated.name, 'Updated Fee');
      expect(updated.batchId, fee.batchId);
    });
  });

  group('FeeDiscount', () {
    test('calculateDiscount for percentage', () {
      final discount = FeeDiscount(
        id: 'd1',
        studentId: 's1',
        type: DiscountType.percentage,
        value: 10,
        reason: 'Sibling discount',
        validFrom: DateTime(2024, 1, 1),
        createdAt: DateTime(2024, 1, 1),
      );

      expect(discount.calculateDiscount(5000), 500);
    });

    test('calculateDiscount for fixed', () {
      final discount = FeeDiscount(
        id: 'd1',
        studentId: 's1',
        type: DiscountType.fixed,
        value: 500,
        reason: 'Scholarship',
        validFrom: DateTime(2024, 1, 1),
        createdAt: DateTime(2024, 1, 1),
      );

      expect(discount.calculateDiscount(5000), 500);
    });

    test('formattedDiscount displays correctly', () {
      final percentDiscount = FeeDiscount(
        id: 'd1',
        studentId: 's1',
        type: DiscountType.percentage,
        value: 10,
        reason: 'Test',
        validFrom: DateTime(2024, 1, 1),
        createdAt: DateTime(2024, 1, 1),
      );
      expect(percentDiscount.formattedDiscount, '10%');

      final fixedDiscount = FeeDiscount(
        id: 'd2',
        studentId: 's1',
        type: DiscountType.fixed,
        value: 500,
        reason: 'Test',
        validFrom: DateTime(2024, 1, 1),
        createdAt: DateTime(2024, 1, 1),
      );
      expect(fixedDiscount.formattedDiscount, '\u20B9500');
    });
  });

  group('FeeInvoice', () {
    test('balanceDue calculates correctly', () {
      final invoice = TestData.feeInvoice(
        finalAmount: 5000,
        paidAmount: 2000,
      );
      expect(invoice.balanceDue, 3000);
    });

    test('balanceDue is zero when fully paid', () {
      final invoice = TestData.feeInvoice(
        finalAmount: 5000,
        paidAmount: 5000,
      );
      expect(invoice.balanceDue, 0);
    });

    test('isOverdue returns true for past due date with pending status', () {
      final invoice = TestData.feeInvoice(
        dueDate: DateTime.now().subtract(const Duration(days: 5)),
        status: PaymentStatus.pending,
      );
      expect(invoice.isOverdue, true);
    });

    test('isOverdue returns false for paid invoices', () {
      final invoice = TestData.feeInvoice(
        dueDate: DateTime.now().subtract(const Duration(days: 5)),
        status: PaymentStatus.paid,
      );
      expect(invoice.isOverdue, false);
    });

    test('isOverdue returns false for future due date', () {
      final invoice = TestData.feeInvoice(
        dueDate: DateTime.now().add(const Duration(days: 30)),
      );
      expect(invoice.isOverdue, false);
    });

    test('copyWith works correctly', () {
      final invoice = TestData.feeInvoice();
      final updated = invoice.copyWith(paidAmount: 3000, status: PaymentStatus.partial);

      expect(updated.paidAmount, 3000);
      expect(updated.status, PaymentStatus.partial);
      expect(updated.studentId, invoice.studentId);
    });
  });

  group('StudentFeeSummary', () {
    test('status returns paid when balance is zero', () {
      final summary = StudentFeeSummary(
        studentId: 's1',
        studentName: 'Test',
        batchId: 'b1',
        batchName: 'Batch',
        totalDue: 5000,
        totalPaid: 5000,
        balance: 0,
      );
      expect(summary.status, PaymentStatus.paid);
    });

    test('status returns overdue when overdue invoices exist', () {
      final summary = StudentFeeSummary(
        studentId: 's1',
        studentName: 'Test',
        batchId: 'b1',
        batchName: 'Batch',
        totalDue: 5000,
        totalPaid: 0,
        balance: 5000,
        overdueInvoices: 1,
      );
      expect(summary.status, PaymentStatus.overdue);
    });

    test('status returns partial when some payment made', () {
      final summary = StudentFeeSummary(
        studentId: 's1',
        studentName: 'Test',
        batchId: 'b1',
        batchName: 'Batch',
        totalDue: 5000,
        totalPaid: 2000,
        balance: 3000,
      );
      expect(summary.status, PaymentStatus.partial);
    });

    test('status returns pending when no payment', () {
      final summary = StudentFeeSummary(
        studentId: 's1',
        studentName: 'Test',
        batchId: 'b1',
        batchName: 'Batch',
        totalDue: 5000,
        totalPaid: 0,
        balance: 5000,
      );
      expect(summary.status, PaymentStatus.pending);
    });
  });

  group('FeeCollectionSummary', () {
    test('collectionRate calculates correctly', () {
      final summary = FeeCollectionSummary(
        periodStart: DateTime(2024, 1, 1),
        periodEnd: DateTime(2024, 1, 31),
        totalBilled: 100000,
        totalCollected: 75000,
        totalPending: 25000,
        totalOverdue: 5000,
        invoiceCount: 20,
        paidInvoiceCount: 15,
        overdueInvoiceCount: 2,
      );
      expect(summary.collectionRate, 75.0);
    });

    test('collectionRate handles zero billed', () {
      final summary = FeeCollectionSummary(
        periodStart: DateTime(2024, 1, 1),
        periodEnd: DateTime(2024, 1, 31),
        totalBilled: 0,
        totalCollected: 0,
        totalPending: 0,
        totalOverdue: 0,
        invoiceCount: 0,
        paidInvoiceCount: 0,
        overdueInvoiceCount: 0,
      );
      expect(summary.collectionRate, 0);
    });
  });
}
