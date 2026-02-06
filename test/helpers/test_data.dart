import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:classpulse/models/models.dart';

/// Test data factories for all models
class TestData {
  static final _now = DateTime(2024, 6, 15, 10, 30);
  static final _yesterday = DateTime(2024, 6, 14, 10, 30);

  // ─── Institute ──────────────────────────────────────────────
  static Institute institute({
    String id = 'inst-1',
    String name = 'Test Academy',
    String adminName = 'Admin User',
    String phone = '9876543210',
    String email = 'admin@test.com',
    String? address,
    InstituteSettings? settings,
  }) {
    return Institute(
      id: id,
      name: name,
      adminName: adminName,
      phone: phone,
      email: email,
      address: address ?? '123 Test Street',
      settings: settings ?? InstituteSettings(),
      createdAt: _now,
      updatedAt: _now,
    );
  }

  // ─── Batch ──────────────────────────────────────────────────
  static Batch batch({
    String id = 'batch-1',
    String instituteId = 'inst-1',
    String name = 'Morning Batch',
    String? subject,
    List<String>? scheduleDays,
    ScheduleTime? startTime,
    ScheduleTime? endTime,
    bool isActive = true,
  }) {
    return Batch(
      id: id,
      instituteId: instituteId,
      name: name,
      subject: subject ?? 'Mathematics',
      scheduleDays: scheduleDays ?? ['monday', 'wednesday', 'friday'],
      startTime: startTime ?? const ScheduleTime(hour: 9, minute: 0),
      endTime: endTime ?? const ScheduleTime(hour: 10, minute: 30),
      isActive: isActive,
      createdAt: _now,
      updatedAt: _now,
    );
  }

  // ─── Student ────────────────────────────────────────────────
  static Student student({
    String id = 'student-1',
    String batchId = 'batch-1',
    String name = 'Rahul Sharma',
    String parentPhone = '9876543210',
    String? studentId,
    bool isActive = true,
  }) {
    return Student(
      id: id,
      batchId: batchId,
      name: name,
      parentPhone: parentPhone,
      studentId: studentId,
      isActive: isActive,
      createdAt: _now,
      updatedAt: _now,
    );
  }

  // ─── Teacher ────────────────────────────────────────────────
  static Teacher teacher({
    String id = 'teacher-1',
    String instituteId = 'inst-1',
    String name = 'Test Teacher',
    String phone = '9999999999',
    TeacherRole role = TeacherRole.teacher,
    bool isActive = true,
  }) {
    return Teacher(
      id: id,
      instituteId: instituteId,
      name: name,
      phone: phone,
      role: role,
      isActive: isActive,
      createdAt: _now,
    );
  }

  static Teacher admin({
    String id = 'admin-1',
    String instituteId = 'inst-1',
    String name = 'Test Admin',
    String phone = '9999999998',
  }) {
    return teacher(
      id: id,
      instituteId: instituteId,
      name: name,
      phone: phone,
      role: TeacherRole.admin,
    );
  }

  // ─── AttendanceRecord ───────────────────────────────────────
  static AttendanceRecord attendanceRecord({
    String id = 'att-1',
    String instituteId = 'inst-1',
    String batchId = 'batch-1',
    DateTime? date,
    String submittedBy = 'teacher-1',
    DateTime? submittedAt,
    bool isSynced = true,
  }) {
    return AttendanceRecord(
      id: id,
      instituteId: instituteId,
      batchId: batchId,
      date: date ?? _now,
      submittedBy: submittedBy,
      submittedAt: submittedAt ?? _now,
      isSynced: isSynced,
    );
  }

  // ─── StudentAttendance ──────────────────────────────────────
  static StudentAttendance studentAttendance({
    String id = 'sa-1',
    String studentId = 'student-1',
    String studentName = 'Rahul Sharma',
    String parentPhone = '9876543210',
    AttendanceStatus status = AttendanceStatus.present,
    DateTime? markedAt,
  }) {
    return StudentAttendance(
      id: id,
      studentId: studentId,
      studentName: studentName,
      parentPhone: parentPhone,
      status: status,
      markedAt: markedAt ?? _now,
    );
  }

  // ─── FeeStructure ──────────────────────────────────────────
  static FeeStructure feeStructure({
    String id = 'fee-1',
    String batchId = 'batch-1',
    String name = 'Monthly Tuition',
    double amount = 5000,
    BillingCycle cycle = BillingCycle.monthly,
    bool isActive = true,
  }) {
    return FeeStructure(
      id: id,
      batchId: batchId,
      name: name,
      amount: amount,
      cycle: cycle,
      effectiveFrom: _now,
      isActive: isActive,
      createdAt: _now,
      updatedAt: _now,
    );
  }

  // ─── FeeInvoice ────────────────────────────────────────────
  static FeeInvoice feeInvoice({
    String id = 'inv-1',
    String studentId = 'student-1',
    String batchId = 'batch-1',
    String feeStructureId = 'fee-1',
    double baseAmount = 5000,
    double discountAmount = 0,
    double finalAmount = 5000,
    double paidAmount = 0,
    DateTime? dueDate,
    PaymentStatus status = PaymentStatus.pending,
  }) {
    return FeeInvoice(
      id: id,
      studentId: studentId,
      batchId: batchId,
      feeStructureId: feeStructureId,
      baseAmount: baseAmount,
      discountAmount: discountAmount,
      finalAmount: finalAmount,
      paidAmount: paidAmount,
      dueDate: dueDate ?? _now.add(const Duration(days: 30)),
      periodStart: _now,
      periodEnd: DateTime(2024, 7, 15),
      status: status,
      createdAt: _now,
      updatedAt: _now,
    );
  }

  // ─── AuditLog ──────────────────────────────────────────────
  static AuditLog auditLog({
    String id = 'log-1',
    String instituteId = 'inst-1',
    String userId = 'teacher-1',
    String userName = 'Test Teacher',
    AuditAction action = AuditAction.attendanceSubmit,
  }) {
    return AuditLog(
      id: id,
      instituteId: instituteId,
      userId: userId,
      userName: userName,
      action: action,
      timestamp: _now,
    );
  }

  // ─── Firestore Document helpers ─────────────────────────────

  /// Seed a FakeFirebaseFirestore with a document and return a DocumentSnapshot
  static Future<DocumentSnapshot> createFakeDoc(
    FakeFirebaseFirestore fakeFirestore,
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    await fakeFirestore.collection(collection).doc(docId).set(data);
    return fakeFirestore.collection(collection).doc(docId).get();
  }
}
