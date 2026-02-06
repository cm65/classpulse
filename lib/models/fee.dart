import 'package:cloud_firestore/cloud_firestore.dart';

/// Billing cycle for fee structures
enum BillingCycle {
  monthly,
  quarterly,
  halfYearly,
  yearly,
  oneTime;

  String get displayName {
    switch (this) {
      case BillingCycle.monthly:
        return 'Monthly';
      case BillingCycle.quarterly:
        return 'Quarterly';
      case BillingCycle.halfYearly:
        return 'Half-Yearly';
      case BillingCycle.yearly:
        return 'Yearly';
      case BillingCycle.oneTime:
        return 'One-Time';
    }
  }

  /// Number of months in this cycle
  int get monthsCount {
    switch (this) {
      case BillingCycle.monthly:
        return 1;
      case BillingCycle.quarterly:
        return 3;
      case BillingCycle.halfYearly:
        return 6;
      case BillingCycle.yearly:
        return 12;
      case BillingCycle.oneTime:
        return 0;
    }
  }
}

/// Fee structure for a batch
class FeeStructure {
  final String id;
  final String batchId;
  final String name;
  final double amount;
  final BillingCycle cycle;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final bool isActive;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  FeeStructure({
    required this.id,
    required this.batchId,
    required this.name,
    required this.amount,
    required this.cycle,
    required this.effectiveFrom,
    this.effectiveTo,
    this.isActive = true,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FeeStructure.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FeeStructure(
      id: doc.id,
      batchId: data['batchId'] as String,
      name: data['name'] as String,
      amount: (data['amount'] as num).toDouble(),
      cycle: BillingCycle.values.firstWhere(
        (c) => c.name == data['cycle'],
        orElse: () => BillingCycle.monthly,
      ),
      effectiveFrom: (data['effectiveFrom'] as Timestamp).toDate(),
      effectiveTo: data['effectiveTo'] != null
          ? (data['effectiveTo'] as Timestamp).toDate()
          : null,
      isActive: data['isActive'] as bool? ?? true,
      description: data['description'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'batchId': batchId,
        'name': name,
        'amount': amount,
        'cycle': cycle.name,
        'effectiveFrom': Timestamp.fromDate(effectiveFrom),
        'effectiveTo': effectiveTo != null ? Timestamp.fromDate(effectiveTo!) : null,
        'isActive': isActive,
        'description': description,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  FeeStructure copyWith({
    String? id,
    String? batchId,
    String? name,
    double? amount,
    BillingCycle? cycle,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    bool? isActive,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FeeStructure(
      id: id ?? this.id,
      batchId: batchId ?? this.batchId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      cycle: cycle ?? this.cycle,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Formatted amount string
  String get formattedAmount => '\u20B9${amount.toStringAsFixed(0)}';
}

/// Discount type
enum DiscountType {
  percentage,
  fixed;

  String get displayName {
    switch (this) {
      case DiscountType.percentage:
        return 'Percentage';
      case DiscountType.fixed:
        return 'Fixed Amount';
    }
  }
}

/// Discount applied to a student's fee
class FeeDiscount {
  final String id;
  final String studentId;
  final String? feeStructureId;
  final DiscountType type;
  final double value;
  final String reason;
  final DateTime validFrom;
  final DateTime? validTo;
  final bool isActive;
  final DateTime createdAt;

  FeeDiscount({
    required this.id,
    required this.studentId,
    this.feeStructureId,
    required this.type,
    required this.value,
    required this.reason,
    required this.validFrom,
    this.validTo,
    this.isActive = true,
    required this.createdAt,
  });

  factory FeeDiscount.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FeeDiscount(
      id: doc.id,
      studentId: data['studentId'] as String,
      feeStructureId: data['feeStructureId'] as String?,
      type: DiscountType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => DiscountType.percentage,
      ),
      value: (data['value'] as num).toDouble(),
      reason: data['reason'] as String,
      validFrom: (data['validFrom'] as Timestamp).toDate(),
      validTo: data['validTo'] != null
          ? (data['validTo'] as Timestamp).toDate()
          : null,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'studentId': studentId,
        'feeStructureId': feeStructureId,
        'type': type.name,
        'value': value,
        'reason': reason,
        'validFrom': Timestamp.fromDate(validFrom),
        'validTo': validTo != null ? Timestamp.fromDate(validTo!) : null,
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  /// Calculate discount amount for a given base amount
  double calculateDiscount(double baseAmount) {
    if (type == DiscountType.percentage) {
      return baseAmount * (value / 100);
    }
    return value;
  }

  /// Formatted discount string
  String get formattedDiscount {
    if (type == DiscountType.percentage) {
      return '${value.toStringAsFixed(0)}%';
    }
    return '\u20B9${value.toStringAsFixed(0)}';
  }
}

/// Payment status
enum PaymentStatus {
  pending,
  partial,
  paid,
  overdue;

  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.partial:
        return 'Partial';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.overdue:
        return 'Overdue';
    }
  }
}

/// Payment method
enum PaymentMethod {
  cash,
  upi,
  bankTransfer,
  cheque,
  card,
  other;

  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.cheque:
        return 'Cheque';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.other:
        return 'Other';
    }
  }
}

/// Fee invoice/bill for a student
class FeeInvoice {
  final String id;
  final String studentId;
  final String batchId;
  final String feeStructureId;
  final double baseAmount;
  final double discountAmount;
  final double finalAmount;
  final double paidAmount;
  final DateTime dueDate;
  final DateTime periodStart;
  final DateTime periodEnd;
  final PaymentStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  FeeInvoice({
    required this.id,
    required this.studentId,
    required this.batchId,
    required this.feeStructureId,
    required this.baseAmount,
    this.discountAmount = 0,
    required this.finalAmount,
    this.paidAmount = 0,
    required this.dueDate,
    required this.periodStart,
    required this.periodEnd,
    this.status = PaymentStatus.pending,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FeeInvoice.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FeeInvoice(
      id: doc.id,
      studentId: data['studentId'] as String,
      batchId: data['batchId'] as String,
      feeStructureId: data['feeStructureId'] as String,
      baseAmount: (data['baseAmount'] as num).toDouble(),
      discountAmount: (data['discountAmount'] as num?)?.toDouble() ?? 0,
      finalAmount: (data['finalAmount'] as num).toDouble(),
      paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0,
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      periodStart: (data['periodStart'] as Timestamp).toDate(),
      periodEnd: (data['periodEnd'] as Timestamp).toDate(),
      status: PaymentStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => PaymentStatus.pending,
      ),
      notes: data['notes'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'studentId': studentId,
        'batchId': batchId,
        'feeStructureId': feeStructureId,
        'baseAmount': baseAmount,
        'discountAmount': discountAmount,
        'finalAmount': finalAmount,
        'paidAmount': paidAmount,
        'dueDate': Timestamp.fromDate(dueDate),
        'periodStart': Timestamp.fromDate(periodStart),
        'periodEnd': Timestamp.fromDate(periodEnd),
        'status': status.name,
        'notes': notes,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  /// Outstanding balance
  double get balanceDue => finalAmount - paidAmount;

  /// Whether invoice is overdue
  bool get isOverdue => DateTime.now().isAfter(dueDate) && status != PaymentStatus.paid;

  /// Formatted amounts
  String get formattedBaseAmount => '\u20B9${baseAmount.toStringAsFixed(0)}';
  String get formattedFinalAmount => '\u20B9${finalAmount.toStringAsFixed(0)}';
  String get formattedPaidAmount => '\u20B9${paidAmount.toStringAsFixed(0)}';
  String get formattedBalanceDue => '\u20B9${balanceDue.toStringAsFixed(0)}';

  FeeInvoice copyWith({
    String? id,
    String? studentId,
    String? batchId,
    String? feeStructureId,
    double? baseAmount,
    double? discountAmount,
    double? finalAmount,
    double? paidAmount,
    DateTime? dueDate,
    DateTime? periodStart,
    DateTime? periodEnd,
    PaymentStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FeeInvoice(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      batchId: batchId ?? this.batchId,
      feeStructureId: feeStructureId ?? this.feeStructureId,
      baseAmount: baseAmount ?? this.baseAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      finalAmount: finalAmount ?? this.finalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      dueDate: dueDate ?? this.dueDate,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Payment record
class Payment {
  final String id;
  final String invoiceId;
  final String studentId;
  final double amount;
  final PaymentMethod method;
  final DateTime paidAt;
  final String? transactionId;
  final String? receiptNumber;
  final String? notes;
  final String collectedBy;
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.invoiceId,
    required this.studentId,
    required this.amount,
    required this.method,
    required this.paidAt,
    this.transactionId,
    this.receiptNumber,
    this.notes,
    required this.collectedBy,
    required this.createdAt,
  });

  factory Payment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Payment(
      id: doc.id,
      invoiceId: data['invoiceId'] as String,
      studentId: data['studentId'] as String,
      amount: (data['amount'] as num).toDouble(),
      method: PaymentMethod.values.firstWhere(
        (m) => m.name == data['method'],
        orElse: () => PaymentMethod.cash,
      ),
      paidAt: (data['paidAt'] as Timestamp).toDate(),
      transactionId: data['transactionId'] as String?,
      receiptNumber: data['receiptNumber'] as String?,
      notes: data['notes'] as String?,
      collectedBy: data['collectedBy'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'invoiceId': invoiceId,
        'studentId': studentId,
        'amount': amount,
        'method': method.name,
        'paidAt': Timestamp.fromDate(paidAt),
        'transactionId': transactionId,
        'receiptNumber': receiptNumber,
        'notes': notes,
        'collectedBy': collectedBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  /// Formatted amount
  String get formattedAmount => '\u20B9${amount.toStringAsFixed(0)}';
}

/// Student fee summary for reports
class StudentFeeSummary {
  final String studentId;
  final String studentName;
  final String batchId;
  final String batchName;
  final double totalDue;
  final double totalPaid;
  final double balance;
  final int overdueInvoices;
  final DateTime? lastPaymentDate;

  StudentFeeSummary({
    required this.studentId,
    required this.studentName,
    required this.batchId,
    required this.batchName,
    required this.totalDue,
    required this.totalPaid,
    required this.balance,
    this.overdueInvoices = 0,
    this.lastPaymentDate,
  });

  /// Formatted amounts
  String get formattedTotalDue => '\u20B9${totalDue.toStringAsFixed(0)}';
  String get formattedTotalPaid => '\u20B9${totalPaid.toStringAsFixed(0)}';
  String get formattedBalance => '\u20B9${balance.toStringAsFixed(0)}';

  /// Payment status based on balance
  PaymentStatus get status {
    if (balance <= 0) return PaymentStatus.paid;
    if (overdueInvoices > 0) return PaymentStatus.overdue;
    if (totalPaid > 0) return PaymentStatus.partial;
    return PaymentStatus.pending;
  }
}

/// Collection summary for fee reports
class FeeCollectionSummary {
  final DateTime periodStart;
  final DateTime periodEnd;
  final double totalBilled;
  final double totalCollected;
  final double totalPending;
  final double totalOverdue;
  final int invoiceCount;
  final int paidInvoiceCount;
  final int partialInvoiceCount;
  final int overdueInvoiceCount;
  final Map<PaymentMethod, double> collectionByMethod;

  FeeCollectionSummary({
    required this.periodStart,
    required this.periodEnd,
    required this.totalBilled,
    required this.totalCollected,
    required this.totalPending,
    required this.totalOverdue,
    required this.invoiceCount,
    required this.paidInvoiceCount,
    this.partialInvoiceCount = 0,
    required this.overdueInvoiceCount,
    this.collectionByMethod = const {},
  });

  /// Collection rate percentage
  double get collectionRate =>
      totalBilled > 0 ? (totalCollected / totalBilled) * 100 : 0;

  /// Formatted amounts
  String get formattedTotalBilled => '\u20B9${totalBilled.toStringAsFixed(0)}';
  String get formattedTotalCollected => '\u20B9${totalCollected.toStringAsFixed(0)}';
  String get formattedTotalPending => '\u20B9${totalPending.toStringAsFixed(0)}';
  String get formattedTotalOverdue => '\u20B9${totalOverdue.toStringAsFixed(0)}';
}
