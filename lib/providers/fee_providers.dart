import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Provider for fee structures of a specific batch
final batchFeeStructuresProvider = StreamProvider.family<List<FeeStructure>, ({String instituteId, String batchId})>(
  (ref, params) {
    final firestoreService = ref.watch(firestoreServiceProvider);
    return firestoreService.feeStructuresStream(params.instituteId, params.batchId);
  },
);

/// Provider for all fee structures in an institute
final allFeeStructuresProvider = StreamProvider.family<List<FeeStructure>, String>(
  (ref, instituteId) {
    final firestoreService = ref.watch(firestoreServiceProvider);
    return firestoreService.allFeeStructuresStream(instituteId);
  },
);

/// Provider for invoices of a specific student
final studentInvoicesProvider = StreamProvider.family<List<FeeInvoice>, ({String instituteId, String studentId})>(
  (ref, params) {
    final firestoreService = ref.watch(firestoreServiceProvider);
    return firestoreService.studentInvoicesStream(params.instituteId, params.studentId);
  },
);

/// Provider for invoices of a specific batch
final batchInvoicesProvider = StreamProvider.family<List<FeeInvoice>, ({String instituteId, String batchId})>(
  (ref, params) {
    final firestoreService = ref.watch(firestoreServiceProvider);
    return firestoreService.batchInvoicesStream(params.instituteId, params.batchId);
  },
);

/// Provider for all invoices in an institute
final allInvoicesProvider = StreamProvider.family<List<FeeInvoice>, String>(
  (ref, instituteId) {
    final firestoreService = ref.watch(firestoreServiceProvider);
    return firestoreService.allInvoicesStream(instituteId);
  },
);

/// Provider for pending invoices
final pendingInvoicesProvider = FutureProvider.family<List<FeeInvoice>, String>(
  (ref, instituteId) async {
    final firestoreService = ref.watch(firestoreServiceProvider);
    return firestoreService.getPendingInvoices(instituteId);
  },
);

/// Provider for payments of a specific invoice
final invoicePaymentsProvider = StreamProvider.family<List<Payment>, ({String instituteId, String invoiceId})>(
  (ref, params) {
    final firestoreService = ref.watch(firestoreServiceProvider);
    return firestoreService.invoicePaymentsStream(params.instituteId, params.invoiceId);
  },
);

/// Provider for payments of a specific student
final studentPaymentsProvider = StreamProvider.family<List<Payment>, ({String instituteId, String studentId})>(
  (ref, params) {
    final firestoreService = ref.watch(firestoreServiceProvider);
    return firestoreService.studentPaymentsStream(params.instituteId, params.studentId);
  },
);

/// Provider for discounts of a specific student
final studentDiscountsProvider = StreamProvider.family<List<FeeDiscount>, ({String instituteId, String studentId})>(
  (ref, params) {
    final firestoreService = ref.watch(firestoreServiceProvider);
    return firestoreService.studentDiscountsStream(params.instituteId, params.studentId);
  },
);

/// Provider for fee collection summary
final feeCollectionSummaryProvider = FutureProvider.family<FeeCollectionSummary, ({
  String instituteId,
  DateTime startDate,
  DateTime endDate,
})>(
  (ref, params) async {
    final firestoreService = ref.watch(firestoreServiceProvider);
    return firestoreService.getFeeCollectionSummary(
      params.instituteId,
      params.startDate,
      params.endDate,
    );
  },
);

/// Provider for fee dashboard stats
final feeDashboardProvider = FutureProvider.family<FeeDashboardData, String>(
  (ref, instituteId) async {
    final firestoreService = ref.watch(firestoreServiceProvider);

    // Get pending invoices
    final pendingInvoices = await firestoreService.getPendingInvoices(instituteId);

    // Get current month's collection
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final summary = await firestoreService.getFeeCollectionSummary(
      instituteId,
      monthStart,
      monthEnd,
    );

    // Count overdue
    var totalOverdue = 0.0;
    var overdueCount = 0;
    for (final invoice in pendingInvoices) {
      if (invoice.isOverdue) {
        overdueCount++;
        totalOverdue += invoice.balanceDue;
      }
    }

    // Calculate total pending
    var totalPending = 0.0;
    for (final invoice in pendingInvoices) {
      totalPending += invoice.balanceDue;
    }

    return FeeDashboardData(
      totalPending: totalPending,
      totalOverdue: totalOverdue,
      pendingInvoiceCount: pendingInvoices.length,
      overdueInvoiceCount: overdueCount,
      monthlyCollection: summary.totalCollected,
      monthlyBilled: summary.totalBilled,
      collectionRate: summary.collectionRate,
    );
  },
);

/// Dashboard data for fees
class FeeDashboardData {
  final double totalPending;
  final double totalOverdue;
  final int pendingInvoiceCount;
  final int overdueInvoiceCount;
  final double monthlyCollection;
  final double monthlyBilled;
  final double collectionRate;

  FeeDashboardData({
    required this.totalPending,
    required this.totalOverdue,
    required this.pendingInvoiceCount,
    required this.overdueInvoiceCount,
    required this.monthlyCollection,
    required this.monthlyBilled,
    required this.collectionRate,
  });

  String get formattedTotalPending => '\u20B9${totalPending.toStringAsFixed(0)}';
  String get formattedTotalOverdue => '\u20B9${totalOverdue.toStringAsFixed(0)}';
  String get formattedMonthlyCollection => '\u20B9${monthlyCollection.toStringAsFixed(0)}';
  String get formattedMonthlyBilled => '\u20B9${monthlyBilled.toStringAsFixed(0)}';
}

/// Provider for student fee summary
final studentFeeSummaryProvider = FutureProvider.family<StudentFeeSummary?, ({
  String instituteId,
  String studentId,
  String studentName,
  String batchId,
  String batchName,
})>(
  (ref, params) async {
    final invoices = await ref.watch(
      studentInvoicesProvider((instituteId: params.instituteId, studentId: params.studentId)).future,
    );

    if (invoices.isEmpty) return null;

    var totalDue = 0.0;
    var totalPaid = 0.0;
    var overdueCount = 0;
    DateTime? lastPaymentDate;

    for (final invoice in invoices) {
      totalDue += invoice.finalAmount;
      totalPaid += invoice.paidAmount;
      if (invoice.isOverdue) overdueCount++;
    }

    // Get last payment date
    final payments = await ref.watch(
      studentPaymentsProvider((instituteId: params.instituteId, studentId: params.studentId)).future,
    );

    if (payments.isNotEmpty) {
      lastPaymentDate = payments.first.paidAt;
    }

    return StudentFeeSummary(
      studentId: params.studentId,
      studentName: params.studentName,
      batchId: params.batchId,
      batchName: params.batchName,
      totalDue: totalDue,
      totalPaid: totalPaid,
      balance: totalDue - totalPaid,
      overdueInvoices: overdueCount,
      lastPaymentDate: lastPaymentDate,
    );
  },
);
