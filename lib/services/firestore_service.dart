import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

/// Provider for Firestore service
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(FirebaseFirestore.instance);
});

class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService(this._firestore);

  // ==================== INSTITUTE ====================

  /// Create a new institute
  Future<String> createInstitute(Institute institute) async {
    final docRef = await _firestore.collection('institutes').add(
          institute.toFirestore(),
        );
    return docRef.id;
  }

  /// Get institute by ID
  Future<Institute?> getInstitute(String instituteId) async {
    final doc = await _firestore.collection('institutes').doc(instituteId).get();
    return doc.exists ? Institute.fromFirestore(doc) : null;
  }

  /// Stream institute data
  Stream<Institute?> instituteStream(String instituteId) {
    return _firestore
        .collection('institutes')
        .doc(instituteId)
        .snapshots()
        .map((doc) => doc.exists ? Institute.fromFirestore(doc) : null);
  }

  /// Update institute
  Future<void> updateInstitute(String instituteId, Map<String, dynamic> data) async {
    await _firestore.collection('institutes').doc(instituteId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== BATCHES ====================

  /// Create a new batch
  Future<String> createBatch(String instituteId, Batch batch) async {
    final docRef = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('batches')
        .add(batch.toFirestore());
    return docRef.id;
  }

  /// Get batches for an institute (with optional limit for pagination)
  Stream<List<Batch>> batchesStream(String instituteId, {int? limit}) {
    Query query = _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('batches')
        .where('isActive', isEqualTo: true)
        .orderBy('name');
    if (limit != null) {
      query = query.limit(limit);
    }
    return query
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Batch.fromFirestore(doc)).toList());
  }

  /// Get all batches (one-time fetch)
  Future<List<Batch>> getBatches(String instituteId) async {
    final snapshot = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('batches')
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .get();
    return snapshot.docs.map((doc) => Batch.fromFirestore(doc)).toList();
  }

  /// Get a single batch
  Future<Batch?> getBatch(String instituteId, String batchId) async {
    final doc = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('batches')
        .doc(batchId)
        .get();
    return doc.exists ? Batch.fromFirestore(doc) : null;
  }

  /// Update batch
  Future<void> updateBatch(
    String instituteId,
    String batchId,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('batches')
        .doc(batchId)
        .update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete batch (soft delete)
  Future<void> deleteBatch(String instituteId, String batchId) async {
    await updateBatch(instituteId, batchId, {'isActive': false});
  }

  // ==================== STUDENTS ====================

  /// Add a student to a batch
  Future<String> addStudent(String instituteId, String batchId, Student student) async {
    final docRef = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('batches')
        .doc(batchId)
        .collection('students')
        .add(student.toFirestore());
    return docRef.id;
  }

  /// Bulk add students
  Future<Map<String, dynamic>> bulkAddStudents(
    String instituteId,
    String batchId,
    List<Student> students,
  ) async {
    final batch = _firestore.batch();
    int addedCount = 0;
    final errors = <String>[];

    for (final student in students) {
      try {
        final docRef = _firestore
            .collection('institutes')
            .doc(instituteId)
            .collection('batches')
            .doc(batchId)
            .collection('students')
            .doc();
        batch.set(docRef, student.toFirestore());
        addedCount++;
      } catch (e) {
        errors.add('${student.name}: ${e.toString()}');
      }
    }

    await batch.commit();
    return {
      'added': addedCount,
      'errors': errors,
    };
  }

  /// Get students in a batch (with optional limit for pagination)
  Stream<List<Student>> studentsStream(String instituteId, String batchId, {int? limit}) {
    Query query = _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('batches')
        .doc(batchId)
        .collection('students')
        .where('isActive', isEqualTo: true)
        .orderBy('name');
    if (limit != null) {
      query = query.limit(limit);
    }
    return query
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Student.fromFirestore(doc)).toList());
  }

  /// Check for duplicate phone in batch
  Future<bool> isPhoneDuplicate(
    String instituteId,
    String batchId,
    String phone, {
    String? excludeStudentId,
  }) async {
    var query = _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('batches')
        .doc(batchId)
        .collection('students')
        .where('parentPhone', isEqualTo: phone)
        .where('isActive', isEqualTo: true);

    final snapshot = await query.get();

    if (excludeStudentId != null) {
      return snapshot.docs.any((doc) => doc.id != excludeStudentId);
    }
    return snapshot.docs.isNotEmpty;
  }

  /// Update student
  Future<void> updateStudent(
    String instituteId,
    String batchId,
    String studentId,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('batches')
        .doc(batchId)
        .collection('students')
        .doc(studentId)
        .update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete student (soft delete)
  Future<void> deleteStudent(
    String instituteId,
    String batchId,
    String studentId,
  ) async {
    await updateStudent(instituteId, batchId, studentId, {'isActive': false});
  }

  // ==================== ATTENDANCE ====================

  /// Submit attendance for a batch
  Future<String> submitAttendance({
    required String instituteId,
    required String batchId,
    required String submittedBy,
    required List<StudentAttendance> entries,
    required DateTime date,
  }) async {
    final batch = _firestore.batch();

    // Create attendance record
    final attendanceRef = _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('attendance')
        .doc();

    final record = AttendanceRecord(
      id: attendanceRef.id,
      instituteId: instituteId,
      batchId: batchId,
      date: date,
      submittedBy: submittedBy,
      submittedAt: DateTime.now(),
    );

    batch.set(attendanceRef, record.toFirestore());

    // Add individual student entries
    for (final entry in entries) {
      final entryRef = attendanceRef.collection('records').doc(entry.studentId);
      batch.set(entryRef, entry.toFirestore());
    }

    await batch.commit();
    return attendanceRef.id;
  }

  /// Get attendance record for a batch on a specific date
  Future<AttendanceRecord?> getAttendance(
    String instituteId,
    String batchId,
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final query = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('attendance')
        .where('batchId', isEqualTo: batchId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return AttendanceRecord.fromFirestore(query.docs.first);
  }

  /// Get student attendance entries for a record
  Stream<List<StudentAttendance>> attendanceEntriesStream(
    String instituteId,
    String attendanceId,
  ) {
    return _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('attendance')
        .doc(attendanceId)
        .collection('records')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StudentAttendance.fromFirestore(doc))
            .toList());
  }

  /// Update attendance entry
  Future<void> updateAttendanceEntry(
    String instituteId,
    String attendanceId,
    String studentId,
    AttendanceStatus status,
  ) async {
    await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('attendance')
        .doc(attendanceId)
        .collection('records')
        .doc(studentId)
        .update({
      'status': status.name,
      'markedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update attendance record metadata (e.g., lastEditedAt, lastEditedBy)
  Future<void> updateAttendanceRecord(
    String instituteId,
    String attendanceId,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('attendance')
        .doc(attendanceId)
        .update(data);
  }

  /// Get student attendance history
  Stream<List<StudentAttendance>> studentHistoryStream(
    String instituteId,
    String studentId, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query = _firestore
        .collectionGroup('records')
        .where('studentId', isEqualTo: studentId);

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => StudentAttendance.fromFirestore(doc))
        .toList());
  }

  /// Get detailed student attendance history with dates
  /// Returns a map of date -> attendance status for calendar view
  Future<List<StudentAttendanceHistoryEntry>> getStudentAttendanceHistory(
    String instituteId,
    String batchId,
    String studentId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 90));
    final end = endDate ?? DateTime.now();

    final attendanceQuery = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('attendance')
        .where('batchId', isEqualTo: batchId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .get();

    final history = <StudentAttendanceHistoryEntry>[];

    for (final doc in attendanceQuery.docs) {
      final record = AttendanceRecord.fromFirestore(doc);

      // Get student's attendance for this record
      final studentDoc = await doc.reference
          .collection('records')
          .doc(studentId)
          .get();

      if (studentDoc.exists) {
        final attendance = StudentAttendance.fromFirestore(studentDoc);
        history.add(StudentAttendanceHistoryEntry(
          date: record.date,
          status: attendance.status,
          batchId: batchId,
        ));
      }
    }

    return history;
  }

  /// Get monthly attendance report for all students in a batch
  Future<List<StudentMonthlyAttendance>> getMonthlyAttendanceReport(
    String instituteId,
    String batchId,
    DateTime month,
  ) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    // Get all students in the batch
    final studentsSnapshot = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('batches')
        .doc(batchId)
        .collection('students')
        .where('isActive', isEqualTo: true)
        .get();

    final students = studentsSnapshot.docs.map((doc) => Student.fromFirestore(doc)).toList();

    // Get all attendance records for the month
    final attendanceQuery = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('attendance')
        .where('batchId', isEqualTo: batchId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();

    // Map to track each student's attendance
    final studentStats = <String, Map<String, int>>{};
    for (final student in students) {
      studentStats[student.id] = {
        'present': 0,
        'absent': 0,
        'late': 0,
        'total': 0,
      };
    }

    // Fetch all records subcollections in PARALLEL (fixes N+1 query pattern)
    // Instead of sequential: for each doc -> await records (O(N) latency)
    // We do: fetch all records at once (O(1) latency)
    final recordsFutures = attendanceQuery.docs.map(
      (doc) => doc.reference.collection('records').get(),
    );
    final allRecordsSnapshots = await Future.wait(recordsFutures);

    // Process all fetched records
    for (final entriesSnapshot in allRecordsSnapshots) {
      for (final entryDoc in entriesSnapshot.docs) {
        final studentId = entryDoc.id;
        if (studentStats.containsKey(studentId)) {
          final status = (entryDoc.data()['status'] as String?) ?? 'unmarked';
          studentStats[studentId]!['total'] = studentStats[studentId]!['total']! + 1;

          switch (status) {
            case 'present':
              studentStats[studentId]!['present'] = studentStats[studentId]!['present']! + 1;
              break;
            case 'absent':
              studentStats[studentId]!['absent'] = studentStats[studentId]!['absent']! + 1;
              break;
            case 'late':
              studentStats[studentId]!['late'] = studentStats[studentId]!['late']! + 1;
              break;
          }
        }
      }
    }

    // Build result list
    return students.map((student) {
      final stats = studentStats[student.id]!;
      return StudentMonthlyAttendance(
        studentId: student.id,
        studentName: student.name,
        presentCount: stats['present']!,
        absentCount: stats['absent']!,
        lateCount: stats['late']!,
        totalDays: stats['total']!,
      );
    }).toList()
      ..sort((a, b) => a.studentName.compareTo(b.studentName));
  }

  /// Get today's attendance summary for all batches
  Future<Map<String, AttendanceSummary>> getTodaysSummary(
    String instituteId,
  ) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final query = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    final summaries = <String, AttendanceSummary>{};

    // Fetch all records subcollections in PARALLEL (fixes N+1 query pattern)
    final recordsFutures = query.docs.map(
      (doc) => doc.reference.collection('records').get(),
    );
    final allRecordsSnapshots = await Future.wait(recordsFutures);

    // Process results - index matches query.docs order
    for (var i = 0; i < query.docs.length; i++) {
      final record = AttendanceRecord.fromFirestore(query.docs[i]);
      final studentEntries = allRecordsSnapshots[i].docs
          .map((e) => StudentAttendance.fromFirestore(e))
          .toList();

      summaries[record.batchId] = AttendanceSummary.fromEntries(studentEntries);
    }

    return summaries;
  }

  /// Get absent students for today
  Future<List<Map<String, dynamic>>> getTodaysAbsentStudents(
    String instituteId,
  ) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final attendanceQuery = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    if (attendanceQuery.docs.isEmpty) {
      return [];
    }

    // Extract records and unique batch IDs
    final records = attendanceQuery.docs
        .map((doc) => AttendanceRecord.fromFirestore(doc))
        .toList();
    final uniqueBatchIds = records.map((r) => r.batchId).toSet();

    // Fetch all batches and records subcollections in PARALLEL (fixes double N+1)
    final batchFutures = uniqueBatchIds.map((id) => getBatch(instituteId, id));
    final recordsFutures = attendanceQuery.docs.map(
      (doc) => doc.reference
          .collection('records')
          .where('status', isEqualTo: AttendanceStatus.absent.name)
          .get(),
    );

    final results = await Future.wait([
      Future.wait(batchFutures),
      Future.wait(recordsFutures),
    ]);

    final batches = results[0] as List<Batch?>;
    final allRecordsSnapshots = results[1] as List<QuerySnapshot>;

    // Build batch ID -> name lookup
    final batchNames = <String, String>{};
    final batchIdList = uniqueBatchIds.toList();
    for (var i = 0; i < batchIdList.length; i++) {
      batchNames[batchIdList[i]] = batches[i]?.name ?? 'Unknown Batch';
    }

    // Process all absent students
    final absentStudents = <Map<String, dynamic>>[];
    for (var i = 0; i < records.length; i++) {
      final record = records[i];
      final entriesSnapshot = allRecordsSnapshots[i];

      for (final entry in entriesSnapshot.docs) {
        final student = StudentAttendance.fromFirestore(entry);
        absentStudents.add({
          'student': student,
          'batchName': batchNames[record.batchId] ?? 'Unknown Batch',
          'batchId': record.batchId,
        });
      }
    }

    return absentStudents;
  }

  // ==================== TEACHERS ====================

  /// Get all teachers for an institute
  Stream<List<Teacher>> teachersStream(String instituteId) {
    return _firestore
        .collection('teachers')
        .where('instituteId', isEqualTo: instituteId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Teacher.fromFirestore(doc)).toList());
  }

  /// Get all teachers (one-time fetch)
  Future<List<Teacher>> getTeachers(String instituteId) async {
    final snapshot = await _firestore
        .collection('teachers')
        .where('instituteId', isEqualTo: instituteId)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.map((doc) => Teacher.fromFirestore(doc)).toList();
  }

  /// Create a teacher invitation
  Future<String> createTeacherInvitation(TeacherInvitation invitation) async {
    // Check if phone already has a teacher account
    final existingTeacher = await _firestore
        .collection('teachers')
        .where('phone', isEqualTo: invitation.phone)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (existingTeacher.docs.isNotEmpty) {
      throw Exception('A teacher with this phone number already exists');
    }

    // Check for existing pending invitation
    final existingInvitation = await _firestore
        .collection('teacherInvitations')
        .where('phone', isEqualTo: invitation.phone)
        .where('instituteId', isEqualTo: invitation.instituteId)
        .where('isAccepted', isEqualTo: false)
        .limit(1)
        .get();

    if (existingInvitation.docs.isNotEmpty) {
      final existing = TeacherInvitation.fromFirestore(existingInvitation.docs.first);
      if (existing.isValid) {
        throw Exception('A pending invitation already exists for this phone number');
      }
      // Delete expired invitation
      await existingInvitation.docs.first.reference.delete();
    }

    final docRef = await _firestore.collection('teacherInvitations').add(
          invitation.toFirestore(),
        );
    return docRef.id;
  }

  /// Get pending invitations for an institute
  Stream<List<TeacherInvitation>> pendingInvitationsStream(String instituteId) {
    return _firestore
        .collection('teacherInvitations')
        .where('instituteId', isEqualTo: instituteId)
        .where('isAccepted', isEqualTo: false)
        .orderBy('invitedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TeacherInvitation.fromFirestore(doc))
            .where((inv) => inv.isValid)
            .toList());
  }

  /// Cancel a pending invitation
  Future<void> cancelInvitation(String invitationId) async {
    await _firestore.collection('teacherInvitations').doc(invitationId).delete();
  }

  /// Remove a teacher (soft delete)
  Future<void> removeTeacher(String teacherId) async {
    await _firestore.collection('teachers').doc(teacherId).update({
      'isActive': false,
    });
  }

  /// Update teacher role
  Future<void> updateTeacherRole(String teacherId, TeacherRole role) async {
    await _firestore.collection('teachers').doc(teacherId).update({
      'role': role.name,
    });
  }

  // ==================== AUDIT LOG ====================

  /// Add audit log entry
  Future<void> addAuditLog(AuditLog log) async {
    await _firestore
        .collection('institutes')
        .doc(log.instituteId)
        .collection('auditLog')
        .add(log.toFirestore());
  }

  /// Get audit logs
  Stream<List<AuditLog>> auditLogsStream(
    String instituteId, {
    int limit = 50,
    AuditAction? filterAction,
  }) {
    Query query = _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('auditLog')
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (filterAction != null) {
      query = query.where('action', isEqualTo: filterAction.name);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => AuditLog.fromFirestore(doc)).toList());
  }

  // ==================== ANALYTICS ====================

  /// Get attendance records for a batch within a date range
  Future<List<AttendanceRecord>> getAttendanceRecordsForRange(
    String instituteId,
    String batchId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final query = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('attendance')
        .where('batchId', isEqualTo: batchId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date', descending: true)
        .get();

    return query.docs.map((doc) => AttendanceRecord.fromFirestore(doc)).toList();
  }

  /// Get attendance entries for a specific record (one-time fetch)
  Future<List<StudentAttendance>> getAttendanceEntries(
    String instituteId,
    String attendanceId,
  ) async {
    final snapshot = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('attendance')
        .doc(attendanceId)
        .collection('records')
        .get();

    return snapshot.docs.map((doc) => StudentAttendance.fromFirestore(doc)).toList();
  }

  /// Get all students for a batch (one-time fetch)
  Future<List<Student>> getStudentsForBatch(
    String instituteId,
    String batchId,
  ) async {
    final snapshot = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('batches')
        .doc(batchId)
        .collection('students')
        .get();

    return snapshot.docs.map((doc) => Student.fromFirestore(doc)).toList();
  }

  /// Get a single student by ID (searches across all batches)
  Future<Student?> getStudent(String instituteId, String studentId) async {
    // Get all batches and search for student
    final batches = await getBatches(instituteId);
    for (final batch in batches) {
      final doc = await _firestore
          .collection('institutes')
          .doc(instituteId)
          .collection('batches')
          .doc(batch.id)
          .collection('students')
          .doc(studentId)
          .get();
      if (doc.exists) {
        return Student.fromFirestore(doc);
      }
    }
    return null;
  }

  // ==================== FEE STRUCTURES ====================

  /// Create a fee structure for a batch
  Future<String> createFeeStructure(String instituteId, FeeStructure fee) async {
    final docRef = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('feeStructures')
        .add(fee.toFirestore());
    return docRef.id;
  }

  /// Get fee structures for a batch
  Stream<List<FeeStructure>> feeStructuresStream(String instituteId, String batchId) {
    return _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('feeStructures')
        .where('batchId', isEqualTo: batchId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => FeeStructure.fromFirestore(doc)).toList());
  }

  /// Get all fee structures for an institute
  Stream<List<FeeStructure>> allFeeStructuresStream(String instituteId) {
    return _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('feeStructures')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => FeeStructure.fromFirestore(doc)).toList());
  }

  /// Get fee structure by ID
  Future<FeeStructure?> getFeeStructure(String instituteId, String feeId) async {
    final doc = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('feeStructures')
        .doc(feeId)
        .get();
    return doc.exists ? FeeStructure.fromFirestore(doc) : null;
  }

  /// Update fee structure
  Future<void> updateFeeStructure(
    String instituteId,
    String feeId,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('feeStructures')
        .doc(feeId)
        .update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete (deactivate) fee structure
  Future<void> deleteFeeStructure(String instituteId, String feeId) async {
    await updateFeeStructure(instituteId, feeId, {'isActive': false});
  }

  // ==================== FEE INVOICES ====================

  /// Create a fee invoice
  Future<String> createFeeInvoice(String instituteId, FeeInvoice invoice) async {
    final docRef = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('invoices')
        .add(invoice.toFirestore());
    return docRef.id;
  }

  /// Get invoices for a student
  Stream<List<FeeInvoice>> studentInvoicesStream(String instituteId, String studentId) {
    return _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('invoices')
        .where('studentId', isEqualTo: studentId)
        .orderBy('dueDate', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => FeeInvoice.fromFirestore(doc)).toList());
  }

  /// Get invoices for a batch
  Stream<List<FeeInvoice>> batchInvoicesStream(String instituteId, String batchId) {
    return _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('invoices')
        .where('batchId', isEqualTo: batchId)
        .orderBy('dueDate', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => FeeInvoice.fromFirestore(doc)).toList());
  }

  /// Get all invoices for an institute
  Stream<List<FeeInvoice>> allInvoicesStream(String instituteId) {
    return _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('invoices')
        .orderBy('dueDate', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => FeeInvoice.fromFirestore(doc)).toList());
  }

  /// Get pending/overdue invoices
  Future<List<FeeInvoice>> getPendingInvoices(String instituteId) async {
    final snapshot = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('invoices')
        .where('status', whereIn: ['pending', 'partial', 'overdue'])
        .orderBy('dueDate')
        .get();
    return snapshot.docs.map((doc) => FeeInvoice.fromFirestore(doc)).toList();
  }

  /// Get invoice by ID
  Future<FeeInvoice?> getInvoice(String instituteId, String invoiceId) async {
    final doc = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('invoices')
        .doc(invoiceId)
        .get();
    return doc.exists ? FeeInvoice.fromFirestore(doc) : null;
  }

  /// Update invoice
  Future<void> updateInvoice(
    String instituteId,
    String invoiceId,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('invoices')
        .doc(invoiceId)
        .update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== PAYMENTS ====================

  /// Record a payment
  Future<String> recordPayment(
    String instituteId,
    Payment payment,
    String invoiceId,
  ) async {
    // Use a transaction to ensure atomicity
    return await _firestore.runTransaction<String>((transaction) async {
      // Get the invoice
      final invoiceRef = _firestore
          .collection('institutes')
          .doc(instituteId)
          .collection('invoices')
          .doc(invoiceId);
      final invoiceDoc = await transaction.get(invoiceRef);

      if (!invoiceDoc.exists) {
        throw Exception('Invoice not found');
      }

      final invoice = FeeInvoice.fromFirestore(invoiceDoc);
      final newPaidAmount = invoice.paidAmount + payment.amount;
      final newStatus = newPaidAmount >= invoice.finalAmount
          ? PaymentStatus.paid
          : PaymentStatus.partial;

      // Create payment record
      final paymentRef = _firestore
          .collection('institutes')
          .doc(instituteId)
          .collection('payments')
          .doc();
      transaction.set(paymentRef, payment.toFirestore());

      // Update invoice
      transaction.update(invoiceRef, {
        'paidAmount': newPaidAmount,
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return paymentRef.id;
    });
  }

  /// Get payments for an invoice
  Stream<List<Payment>> invoicePaymentsStream(String instituteId, String invoiceId) {
    return _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('payments')
        .where('invoiceId', isEqualTo: invoiceId)
        .orderBy('paidAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Payment.fromFirestore(doc)).toList());
  }

  /// Get all payments for a student
  Stream<List<Payment>> studentPaymentsStream(String instituteId, String studentId) {
    return _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('payments')
        .where('studentId', isEqualTo: studentId)
        .orderBy('paidAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Payment.fromFirestore(doc)).toList());
  }

  /// Get payments in a date range (for reports)
  Future<List<Payment>> getPaymentsInRange(
    String instituteId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final snapshot = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('payments')
        .where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('paidAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('paidAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => Payment.fromFirestore(doc)).toList();
  }

  // ==================== FEE DISCOUNTS ====================

  /// Create a discount for a student
  Future<String> createFeeDiscount(String instituteId, FeeDiscount discount) async {
    final docRef = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('discounts')
        .add(discount.toFirestore());
    return docRef.id;
  }

  /// Get discounts for a student
  Stream<List<FeeDiscount>> studentDiscountsStream(String instituteId, String studentId) {
    return _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('discounts')
        .where('studentId', isEqualTo: studentId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => FeeDiscount.fromFirestore(doc)).toList());
  }

  /// Update discount
  Future<void> updateDiscount(
    String instituteId,
    String discountId,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('discounts')
        .doc(discountId)
        .update(data);
  }

  /// Delete (deactivate) discount
  Future<void> deleteDiscount(String instituteId, String discountId) async {
    await updateDiscount(instituteId, discountId, {'isActive': false});
  }

  // ==================== FEE REPORTS ====================

  /// Get fee collection summary for a period
  Future<FeeCollectionSummary> getFeeCollectionSummary(
    String instituteId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Get all invoices in the period
    final invoicesSnapshot = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('invoices')
        .where('periodStart', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('periodStart', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    final invoices = invoicesSnapshot.docs
        .map((doc) => FeeInvoice.fromFirestore(doc))
        .toList();

    // Get all payments in the period
    final payments = await getPaymentsInRange(instituteId, startDate, endDate);

    // Calculate totals
    var totalBilled = 0.0;
    var totalPending = 0.0;
    var totalOverdue = 0.0;
    var paidCount = 0;
    var partialCount = 0;
    var overdueCount = 0;

    for (final invoice in invoices) {
      totalBilled += invoice.finalAmount;
      if (invoice.status == PaymentStatus.paid) {
        paidCount++;
      } else if (invoice.status == PaymentStatus.partial) {
        partialCount++;
        totalPending += invoice.balanceDue;
      } else if (invoice.isOverdue) {
        overdueCount++;
        totalOverdue += invoice.balanceDue;
      } else {
        totalPending += invoice.balanceDue;
      }
    }

    // Collection by method
    final collectionByMethod = <PaymentMethod, double>{};
    var totalCollected = 0.0;
    for (final payment in payments) {
      totalCollected += payment.amount;
      collectionByMethod[payment.method] =
          (collectionByMethod[payment.method] ?? 0) + payment.amount;
    }

    return FeeCollectionSummary(
      periodStart: startDate,
      periodEnd: endDate,
      totalBilled: totalBilled,
      totalCollected: totalCollected,
      totalPending: totalPending,
      totalOverdue: totalOverdue,
      invoiceCount: invoices.length,
      paidInvoiceCount: paidCount,
      partialInvoiceCount: partialCount,
      overdueInvoiceCount: overdueCount,
      collectionByMethod: collectionByMethod,
    );
  }

  /// Generate invoices for a batch based on fee structure
  Future<List<String>> generateBatchInvoices(
    String instituteId,
    String batchId,
    String feeStructureId,
    DateTime periodStart,
    DateTime periodEnd,
    DateTime dueDate,
  ) async {
    final feeStructure = await getFeeStructure(instituteId, feeStructureId);
    if (feeStructure == null) {
      throw Exception('Fee structure not found');
    }

    final students = await getStudentsForBatch(instituteId, batchId);
    final activeStudents = students.where((s) => s.isActive).toList();

    final invoiceIds = <String>[];
    final now = DateTime.now();

    for (final student in activeStudents) {
      // Check for existing invoice in this period
      final existingSnapshot = await _firestore
          .collection('institutes')
          .doc(instituteId)
          .collection('invoices')
          .where('studentId', isEqualTo: student.id)
          .where('feeStructureId', isEqualTo: feeStructureId)
          .where('periodStart', isEqualTo: Timestamp.fromDate(periodStart))
          .get();

      if (existingSnapshot.docs.isNotEmpty) {
        continue; // Invoice already exists
      }

      // Get discounts for this student
      final discountsSnapshot = await _firestore
          .collection('institutes')
          .doc(instituteId)
          .collection('discounts')
          .where('studentId', isEqualTo: student.id)
          .where('isActive', isEqualTo: true)
          .get();

      var discountAmount = 0.0;
      for (final discountDoc in discountsSnapshot.docs) {
        final discount = FeeDiscount.fromFirestore(discountDoc);
        // Check if discount applies to this fee structure
        if (discount.feeStructureId == null ||
            discount.feeStructureId == feeStructureId) {
          // Check if discount is valid for this period
          if (discount.validFrom.isBefore(periodEnd) &&
              (discount.validTo == null || discount.validTo!.isAfter(periodStart))) {
            discountAmount += discount.calculateDiscount(feeStructure.amount);
          }
        }
      }

      final finalAmount = feeStructure.amount - discountAmount;

      final invoice = FeeInvoice(
        id: '',
        studentId: student.id,
        batchId: batchId,
        feeStructureId: feeStructureId,
        baseAmount: feeStructure.amount,
        discountAmount: discountAmount,
        finalAmount: finalAmount > 0 ? finalAmount : 0,
        dueDate: dueDate,
        periodStart: periodStart,
        periodEnd: periodEnd,
        createdAt: now,
        updatedAt: now,
      );

      final invoiceId = await createFeeInvoice(instituteId, invoice);
      invoiceIds.add(invoiceId);
    }

    return invoiceIds;
  }

  // ==================== SUBJECTS ====================

  /// Create a new subject
  Future<String> createSubject(String instituteId, Subject subject) async {
    final docRef = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('subjects')
        .add(subject.toFirestore());
    return docRef.id;
  }

  /// Get all subjects for an institute
  Stream<List<Subject>> subjectsStream(String instituteId) {
    return _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('subjects')
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Subject.fromFirestore(doc)).toList());
  }

  /// Get all subjects (one-time fetch)
  Future<List<Subject>> getSubjects(String instituteId) async {
    final snapshot = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('subjects')
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .get();
    return snapshot.docs.map((doc) => Subject.fromFirestore(doc)).toList();
  }

  /// Update subject
  Future<void> updateSubject(
    String instituteId,
    String subjectId,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('subjects')
        .doc(subjectId)
        .update(data);
  }

  /// Delete subject (soft delete)
  Future<void> deleteSubject(String instituteId, String subjectId) async {
    await updateSubject(instituteId, subjectId, {'isActive': false});
  }

  // ==================== TESTS ====================

  /// Create a new test
  Future<String> createTest(String instituteId, Test test) async {
    final docRef = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('tests')
        .add(test.toFirestore());
    return docRef.id;
  }

  /// Get all tests for a batch
  Stream<List<Test>> batchTestsStream(String instituteId, String batchId) {
    return _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('tests')
        .where('batchId', isEqualTo: batchId)
        .orderBy('testDate', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Test.fromFirestore(doc)).toList());
  }

  /// Get tests for a batch (one-time fetch)
  Future<List<Test>> getBatchTests(String instituteId, String batchId) async {
    final snapshot = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('tests')
        .where('batchId', isEqualTo: batchId)
        .orderBy('testDate', descending: true)
        .get();
    return snapshot.docs.map((doc) => Test.fromFirestore(doc)).toList();
  }

  /// Get a single test
  Future<Test?> getTest(String instituteId, String testId) async {
    final doc = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('tests')
        .doc(testId)
        .get();
    return doc.exists ? Test.fromFirestore(doc) : null;
  }

  /// Update test
  Future<void> updateTest(
    String instituteId,
    String testId,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('tests')
        .doc(testId)
        .update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete test
  Future<void> deleteTest(String instituteId, String testId) async {
    // Delete all scores for this test first
    final scoresSnapshot = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('scores')
        .where('testId', isEqualTo: testId)
        .get();

    final batch = _firestore.batch();
    for (final doc in scoresSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete the test
    batch.delete(_firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('tests')
        .doc(testId));

    await batch.commit();
  }

  /// Get recent tests for an institute
  Future<List<Test>> getRecentTests(
    String instituteId, {
    int limit = 10,
  }) async {
    final snapshot = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('tests')
        .orderBy('testDate', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) => Test.fromFirestore(doc)).toList();
  }

  // ==================== SCORES ====================

  /// Create or update a score
  Future<String> saveScore(String instituteId, Score score) async {
    // Check if score already exists for this test+student
    final existingQuery = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('scores')
        .where('testId', isEqualTo: score.testId)
        .where('studentId', isEqualTo: score.studentId)
        .limit(1)
        .get();

    if (existingQuery.docs.isNotEmpty) {
      // Update existing score
      final existingId = existingQuery.docs.first.id;
      await _firestore
          .collection('institutes')
          .doc(instituteId)
          .collection('scores')
          .doc(existingId)
          .update({
        'marksObtained': score.marksObtained,
        'isAbsent': score.isAbsent,
        'isExempt': score.isExempt,
        'remarks': score.remarks,
        'gradedBy': score.gradedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return existingId;
    } else {
      // Create new score
      final docRef = await _firestore
          .collection('institutes')
          .doc(instituteId)
          .collection('scores')
          .add(score.toFirestore());
      return docRef.id;
    }
  }

  /// Save multiple scores at once (bulk entry)
  Future<void> saveScoresBulk(String instituteId, List<Score> scores) async {
    final batch = _firestore.batch();
    final scoresCollection = _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('scores');

    for (final score in scores) {
      // Check if score exists
      final existingQuery = await scoresCollection
          .where('testId', isEqualTo: score.testId)
          .where('studentId', isEqualTo: score.studentId)
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        batch.update(existingQuery.docs.first.reference, {
          'marksObtained': score.marksObtained,
          'isAbsent': score.isAbsent,
          'isExempt': score.isExempt,
          'remarks': score.remarks,
          'gradedBy': score.gradedBy,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        batch.set(scoresCollection.doc(), score.toFirestore());
      }
    }

    await batch.commit();
  }

  /// Get all scores for a test
  Stream<List<Score>> testScoresStream(String instituteId, String testId) {
    return _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('scores')
        .where('testId', isEqualTo: testId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Score.fromFirestore(doc)).toList());
  }

  /// Get scores for a test (one-time fetch)
  Future<List<Score>> getTestScores(String instituteId, String testId) async {
    final snapshot = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('scores')
        .where('testId', isEqualTo: testId)
        .get();
    return snapshot.docs.map((doc) => Score.fromFirestore(doc)).toList();
  }

  /// Get all scores for a student
  Future<List<Score>> getStudentScores(
    String instituteId,
    String studentId,
  ) async {
    final snapshot = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('scores')
        .where('studentId', isEqualTo: studentId)
        .get();
    return snapshot.docs.map((doc) => Score.fromFirestore(doc)).toList();
  }

  /// Get a specific score
  Future<Score?> getScore(
    String instituteId,
    String testId,
    String studentId,
  ) async {
    final snapshot = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('scores')
        .where('testId', isEqualTo: testId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty
        ? Score.fromFirestore(snapshot.docs.first)
        : null;
  }

  // ==================== PERFORMANCE ANALYTICS ====================

  /// Get test analytics
  Future<TestAnalytics> getTestAnalytics(
    String instituteId,
    String testId,
  ) async {
    final test = await getTest(instituteId, testId);
    if (test == null) {
      throw Exception('Test not found');
    }

    // Get batch students count
    final studentsSnapshot = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('students')
        .where('batchId', isEqualTo: test.batchId)
        .where('isActive', isEqualTo: true)
        .get();
    final totalStudents = studentsSnapshot.docs.length;

    // Get all scores for this test
    final scores = await getTestScores(instituteId, testId);

    int gradedCount = 0;
    int absentCount = 0;
    int exemptCount = 0;
    int passedCount = 0;
    int failedCount = 0;
    final marks = <double>[];
    final gradeDistribution = <String, int>{};

    for (final score in scores) {
      if (score.isAbsent) {
        absentCount++;
      } else if (score.isExempt) {
        exemptCount++;
      } else if (score.marksObtained != null) {
        gradedCount++;
        marks.add(score.marksObtained!);

        // Check pass/fail
        if (test.passingMarks != null) {
          if (score.marksObtained! >= test.passingMarks!) {
            passedCount++;
          } else {
            failedCount++;
          }
        }

        // Calculate grade distribution
        final grade = score.letterGrade(test.maxMarks);
        if (grade != null) {
          gradeDistribution[grade] = (gradeDistribution[grade] ?? 0) + 1;
        }
      }
    }

    // Calculate statistics
    double? highest;
    double? lowest;
    double? average;
    double? median;

    if (marks.isNotEmpty) {
      marks.sort();
      highest = marks.last;
      lowest = marks.first;
      average = marks.reduce((a, b) => a + b) / marks.length;

      // Calculate median
      final mid = marks.length ~/ 2;
      if (marks.length.isOdd) {
        median = marks[mid];
      } else {
        median = (marks[mid - 1] + marks[mid]) / 2;
      }
    }

    return TestAnalytics(
      testId: testId,
      testName: test.name,
      maxMarks: test.maxMarks,
      totalStudents: totalStudents,
      gradedCount: gradedCount,
      absentCount: absentCount,
      exemptCount: exemptCount,
      passedCount: passedCount,
      failedCount: failedCount,
      highestMarks: highest,
      lowestMarks: lowest,
      averageMarks: average,
      medianMarks: median,
      gradeDistribution: gradeDistribution,
    );
  }

  /// Get student performance summary
  Future<StudentPerformanceSummary> getStudentPerformance(
    String instituteId,
    String studentId,
  ) async {
    // Get student details
    final student = await getStudent(instituteId, studentId);
    if (student == null) {
      throw Exception('Student not found');
    }

    final batch = await getBatch(instituteId, student.batchId);
    final batchName = batch?.name ?? 'Unknown Batch';

    // Get all tests for this batch
    final tests = await getBatchTests(instituteId, student.batchId);

    // Get all scores for this student
    final scores = await getStudentScores(instituteId, studentId);
    final scoreMap = {for (var s in scores) s.testId: s};

    int testsAppeared = 0;
    int testsPassed = 0;
    double totalPercentage = 0;
    final subjectMarks = <String, List<double>>{};
    final recentScores = <RecentTestScore>[];

    for (final test in tests) {
      final score = scoreMap[test.id];
      if (score != null && !score.isAbsent && !score.isExempt && score.marksObtained != null) {
        testsAppeared++;
        final pct = score.percentage(test.maxMarks)!;
        totalPercentage += pct;

        // Track subject performance
        if (test.subjectId != null) {
          subjectMarks.putIfAbsent(test.subjectId!, () => []).add(pct);
        }

        // Check pass
        if (test.passingMarks != null && score.marksObtained! >= test.passingMarks!) {
          testsPassed++;
        }
      }

      // Add to recent scores (top 5)
      if (recentScores.length < 5) {
        recentScores.add(RecentTestScore(
          testId: test.id,
          testName: test.name,
          testType: test.type,
          testDate: test.testDate,
          percentage: score?.percentage(test.maxMarks),
          letterGrade: score?.letterGrade(test.maxMarks),
          passed: score?.hasPassed(test.passingMarks),
        ));
      }
    }

    final avgPercentage = testsAppeared > 0 ? totalPercentage / testsAppeared : 0.0;

    // Calculate subject averages
    final subjectAverages = <String, double>{};
    for (final entry in subjectMarks.entries) {
      if (entry.value.isNotEmpty) {
        subjectAverages[entry.key] =
            entry.value.reduce((a, b) => a + b) / entry.value.length;
      }
    }

    // Calculate trend (compare last 3 vs previous 3 tests)
    double? trend;
    if (tests.length >= 6) {
      final sortedTests = tests.toList()..sort((a, b) => b.testDate.compareTo(a.testDate));
      final recent3 = <double>[];
      final previous3 = <double>[];

      for (final test in sortedTests.take(6)) {
        final score = scoreMap[test.id];
        if (score != null && !score.isAbsent && !score.isExempt && score.marksObtained != null) {
          final pct = score.percentage(test.maxMarks)!;
          if (recent3.length < 3) {
            recent3.add(pct);
          } else if (previous3.length < 3) {
            previous3.add(pct);
          }
        }
      }

      if (recent3.isNotEmpty && previous3.isNotEmpty) {
        final recentAvg = recent3.reduce((a, b) => a + b) / recent3.length;
        final prevAvg = previous3.reduce((a, b) => a + b) / previous3.length;
        trend = recentAvg - prevAvg;
      }
    }

    // Calculate rank in batch
    final batchStudents = await getStudentsForBatch(instituteId, student.batchId);
    final studentAverages = <String, double>{};

    for (final s in batchStudents) {
      final sScores = await getStudentScores(instituteId, s.id);
      final sScoreMap = {for (var sc in sScores) sc.testId: sc};
      double sTotalPct = 0;
      int sCount = 0;

      for (final test in tests) {
        final sc = sScoreMap[test.id];
        if (sc != null && !sc.isAbsent && !sc.isExempt && sc.marksObtained != null) {
          sTotalPct += sc.percentage(test.maxMarks)!;
          sCount++;
        }
      }

      if (sCount > 0) {
        studentAverages[s.id] = sTotalPct / sCount;
      }
    }

    // Sort by average descending
    final sortedStudents = studentAverages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final rank = sortedStudents.indexWhere((e) => e.key == studentId) + 1;

    return StudentPerformanceSummary(
      studentId: studentId,
      studentName: student.name,
      batchName: batchName,
      totalTests: tests.length,
      testsAppeared: testsAppeared,
      testsPassed: testsPassed,
      averagePercentage: avgPercentage,
      trend: trend,
      rank: rank > 0 ? rank : batchStudents.length,
      totalStudentsInBatch: batchStudents.length,
      subjectAverages: subjectAverages,
      recentScores: recentScores,
    );
  }

  /// Get batch performance overview
  Future<BatchPerformanceOverview> getBatchPerformanceOverview(
    String instituteId,
    String batchId,
  ) async {
    final batch = await getBatch(instituteId, batchId);
    if (batch == null) {
      throw Exception('Batch not found');
    }

    final students = await getStudentsForBatch(instituteId, batchId);
    final tests = await getBatchTests(instituteId, batchId);

    if (tests.isEmpty) {
      return BatchPerformanceOverview(
        batchId: batchId,
        batchName: batch.name,
        totalStudents: students.length,
        totalTests: 0,
        averageAttendance: 0,
        averageScore: 0,
        passRate: 0,
      );
    }

    // Calculate all student averages
    final studentPerformances = <String, ({double avg, int appeared, int total})>{};

    for (final student in students) {
      final scores = await getStudentScores(instituteId, student.id);
      final scoreMap = {for (var s in scores) s.testId: s};

      double totalPct = 0;
      int appeared = 0;

      for (final test in tests) {
        final score = scoreMap[test.id];
        if (score != null && !score.isAbsent && !score.isExempt && score.marksObtained != null) {
          totalPct += score.percentage(test.maxMarks)!;
          appeared++;
        }
      }

      studentPerformances[student.id] = (
        avg: appeared > 0 ? totalPct / appeared : 0,
        appeared: appeared,
        total: tests.length,
      );
    }

    // Calculate overall metrics
    double totalAttendance = 0;
    double totalScore = 0;
    int passedTests = 0;
    int totalGraded = 0;

    for (final test in tests) {
      final scores = await getTestScores(instituteId, test.id);
      for (final score in scores) {
        if (score.marksObtained != null && !score.isAbsent && !score.isExempt) {
          totalGraded++;
          totalScore += score.percentage(test.maxMarks)!;

          if (test.passingMarks != null && score.marksObtained! >= test.passingMarks!) {
            passedTests++;
          }
        }
      }
    }

    final avgAttendance = students.isNotEmpty
        ? studentPerformances.values.map((p) => p.appeared / p.total * 100).reduce((a, b) => a + b) / students.length
        : 0.0;
    final avgScore = totalGraded > 0 ? totalScore / totalGraded : 0.0;
    final passRate = totalGraded > 0 ? (passedTests / totalGraded) * 100 : 0.0;

    // Get top 5 performers
    final sortedByPerformance = studentPerformances.entries.toList()
      ..sort((a, b) => b.value.avg.compareTo(a.value.avg));

    final topPerformers = sortedByPerformance.take(5).map((e) {
      final student = students.firstWhere((s) => s.id == e.key);
      return StudentRanking(
        studentId: e.key,
        studentName: student.name,
        rank: sortedByPerformance.indexWhere((s) => s.key == e.key) + 1,
        averagePercentage: e.value.avg,
      );
    }).toList();

    // Get students needing attention (bottom 5 with avg < 50%)
    final needsAttention = sortedByPerformance.reversed
        .where((e) => e.value.avg < 50)
        .take(5)
        .map((e) {
      final student = students.firstWhere((s) => s.id == e.key);
      return StudentRanking(
        studentId: e.key,
        studentName: student.name,
        rank: sortedByPerformance.indexWhere((s) => s.key == e.key) + 1,
        averagePercentage: e.value.avg,
      );
    }).toList();

    return BatchPerformanceOverview(
      batchId: batchId,
      batchName: batch.name,
      totalStudents: students.length,
      totalTests: tests.length,
      averageAttendance: avgAttendance,
      averageScore: avgScore,
      passRate: passRate,
      topPerformers: topPerformers,
      needsAttention: needsAttention,
    );
  }

  /// Get student test results with rankings for a specific test
  Future<List<StudentTestResult>> getTestResults(
    String instituteId,
    String testId,
  ) async {
    final test = await getTest(instituteId, testId);
    if (test == null) {
      throw Exception('Test not found');
    }

    final students = await getStudentsForBatch(instituteId, test.batchId);
    final scores = await getTestScores(instituteId, testId);
    final scoreMap = {for (var s in scores) s.studentId: s};

    // Calculate rankings
    final gradedScores = scores
        .where((s) => s.marksObtained != null && !s.isAbsent && !s.isExempt)
        .toList()
      ..sort((a, b) => (b.marksObtained ?? 0).compareTo(a.marksObtained ?? 0));

    final rankMap = <String, int>{};
    int currentRank = 1;
    double? lastMarks;
    for (int i = 0; i < gradedScores.length; i++) {
      final score = gradedScores[i];
      if (lastMarks != score.marksObtained) {
        currentRank = i + 1;
      }
      rankMap[score.studentId] = currentRank;
      lastMarks = score.marksObtained;
    }

    return students.map((student) {
      final score = scoreMap[student.id];
      return StudentTestResult(
        studentId: student.id,
        studentName: student.name,
        score: score,
        maxMarks: test.maxMarks,
        passingMarks: test.passingMarks,
        rank: rankMap[student.id],
      );
    }).toList();
  }

  // ==================== PARENTS ====================

  /// Create or update a parent account
  Future<String> saveParent(Parent parent) async {
    if (parent.id.isEmpty) {
      final docRef = await _firestore
          .collection('parents')
          .add(parent.toFirestore());
      return docRef.id;
    } else {
      await _firestore
          .collection('parents')
          .doc(parent.id)
          .set(parent.toFirestore());
      return parent.id;
    }
  }

  /// Get parent by phone number
  Future<Parent?> getParentByPhone(String phone) async {
    final snapshot = await _firestore
        .collection('parents')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty
        ? Parent.fromFirestore(snapshot.docs.first)
        : null;
  }

  /// Get parent by ID
  Future<Parent?> getParent(String parentId) async {
    final doc = await _firestore.collection('parents').doc(parentId).get();
    return doc.exists ? Parent.fromFirestore(doc) : null;
  }

  /// Update parent
  Future<void> updateParent(String parentId, Map<String, dynamic> data) async {
    await _firestore.collection('parents').doc(parentId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get or create parent from student's parent phone
  Future<Parent> getOrCreateParentFromStudent(
    String instituteId,
    Student student,
    Batch batch,
  ) async {
    // Check if parent already exists
    var parent = await getParentByPhone(student.parentPhone);

    if (parent == null) {
      // Create new parent
      parent = Parent(
        id: '',
        instituteId: instituteId,
        phone: student.parentPhone,
        name: 'Parent of ${student.name}',
        studentIds: [student.id],
        status: ParentStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final parentId = await saveParent(parent);
      parent = parent.copyWith(id: parentId);
    } else {
      // Add student to existing parent if not already linked
      if (!parent.studentIds.contains(student.id)) {
        final updatedStudentIds = [...parent.studentIds, student.id];
        await updateParent(parent.id, {'studentIds': updatedStudentIds});
        parent = parent.copyWith(studentIds: updatedStudentIds);
      }
    }

    // Create/update parent-student link for quick lookup
    await _createParentStudentLink(
      parentPhone: student.parentPhone,
      student: student,
      batch: batch,
      instituteId: instituteId,
    );

    return parent;
  }

  /// Create parent-student link
  Future<void> _createParentStudentLink({
    required String parentPhone,
    required Student student,
    required Batch batch,
    required String instituteId,
  }) async {
    // Check if link already exists
    final existingLink = await _firestore
        .collection('parentStudentLinks')
        .where('parentPhone', isEqualTo: parentPhone)
        .where('studentId', isEqualTo: student.id)
        .limit(1)
        .get();

    if (existingLink.docs.isEmpty) {
      final link = ParentStudentLink(
        id: '',
        parentPhone: parentPhone,
        studentId: student.id,
        studentName: student.name,
        batchId: batch.id,
        batchName: batch.name,
        instituteId: instituteId,
        createdAt: DateTime.now(),
      );
      await _firestore.collection('parentStudentLinks').add(link.toFirestore());
    }
  }

  /// Get all students linked to a parent phone
  Future<List<ParentStudentLink>> getLinkedStudents(String parentPhone) async {
    final snapshot = await _firestore
        .collection('parentStudentLinks')
        .where('parentPhone', isEqualTo: parentPhone)
        .get();
    return snapshot.docs
        .map((doc) => ParentStudentLink.fromFirestore(doc))
        .toList();
  }

  // ==================== LEAVE REQUESTS ====================

  /// Create a leave request
  Future<String> createLeaveRequest(LeaveRequest request) async {
    final docRef = await _firestore
        .collection('leaveRequests')
        .add(request.toFirestore());
    return docRef.id;
  }

  /// Get leave requests for a student
  Stream<List<LeaveRequest>> studentLeaveRequestsStream(String studentId) {
    return _firestore
        .collection('leaveRequests')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => LeaveRequest.fromFirestore(doc)).toList());
  }

  /// Get pending leave requests for a batch
  Stream<List<LeaveRequest>> batchLeaveRequestsStream(
    String batchId, {
    LeaveRequestStatus? status,
  }) {
    var query = _firestore
        .collection('leaveRequests')
        .where('batchId', isEqualTo: batchId);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => LeaveRequest.fromFirestore(doc)).toList());
  }

  /// Get pending leave requests for an institute
  Future<List<LeaveRequest>> getPendingLeaveRequests(String instituteId) async {
    final snapshot = await _firestore
        .collection('leaveRequests')
        .where('instituteId', isEqualTo: instituteId)
        .where('status', isEqualTo: LeaveRequestStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => LeaveRequest.fromFirestore(doc))
        .toList();
  }

  /// Approve or reject a leave request
  Future<void> reviewLeaveRequest(
    String requestId, {
    required LeaveRequestStatus status,
    required String reviewedBy,
    String? reviewNotes,
  }) async {
    await _firestore.collection('leaveRequests').doc(requestId).update({
      'status': status.name,
      'reviewedBy': reviewedBy,
      'reviewNotes': reviewNotes,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancel a leave request (by parent)
  Future<void> cancelLeaveRequest(String requestId) async {
    await _firestore.collection('leaveRequests').doc(requestId).update({
      'status': LeaveRequestStatus.cancelled.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== ANNOUNCEMENTS ====================

  /// Create an announcement
  Future<String> createAnnouncement(Announcement announcement) async {
    final docRef = await _firestore
        .collection('announcements')
        .add(announcement.toFirestore());
    return docRef.id;
  }

  /// Get announcements for an institute
  Stream<List<Announcement>> announcementsStream(String instituteId) {
    return _firestore
        .collection('announcements')
        .where('instituteId', isEqualTo: instituteId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Announcement.fromFirestore(doc)).toList());
  }

  /// Get published announcements for parents
  Future<List<Announcement>> getActiveAnnouncements(
    String instituteId, {
    String? batchId,
  }) async {
    var query = _firestore
        .collection('announcements')
        .where('instituteId', isEqualTo: instituteId)
        .where('isPublished', isEqualTo: true);

    final snapshot = await query
        .orderBy('publishedAt', descending: true)
        .limit(20)
        .get();

    final announcements = snapshot.docs
        .map((doc) => Announcement.fromFirestore(doc))
        .where((a) => a.isActive)
        .toList();

    // Filter by batch if specified
    if (batchId != null) {
      return announcements.where((a) => a.targetsBatch(batchId)).toList();
    }

    return announcements;
  }

  /// Update announcement
  Future<void> updateAnnouncement(
    String announcementId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection('announcements').doc(announcementId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Publish an announcement
  Future<void> publishAnnouncement(String announcementId) async {
    await _firestore.collection('announcements').doc(announcementId).update({
      'isPublished': true,
      'publishedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete an announcement
  Future<void> deleteAnnouncement(String announcementId) async {
    await _firestore.collection('announcements').doc(announcementId).delete();
  }

  /// Increment announcement view count
  Future<void> incrementAnnouncementViews(String announcementId) async {
    await _firestore.collection('announcements').doc(announcementId).update({
      'viewCount': FieldValue.increment(1),
    });
  }

  // ==================== PARENT DASHBOARD ====================

  /// Get child summary for parent dashboard
  Future<ChildSummary> getChildSummary(
    String instituteId,
    String studentId,
    String batchId,
  ) async {
    // Get student and batch
    final students = await getStudentsForBatch(instituteId, batchId);
    final student = students.firstWhere(
      (s) => s.id == studentId,
      orElse: () => throw Exception('Student not found'),
    );
    final batch = await getBatch(instituteId, batchId);

    // Get attendance for last 30 days
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final attendanceRecords = await _firestore
        .collection('institutes')
        .doc(instituteId)
        .collection('attendance')
        .where('batchId', isEqualTo: batchId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
        .get();

    int present = 0;
    int absent = 0;
    int late = 0;
    int total = 0;
    final recentAttendance = <RecentAttendance>[];

    for (final recordDoc in attendanceRecords.docs) {
      final entriesSnapshot = await recordDoc.reference
          .collection('records')
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (entriesSnapshot.docs.isNotEmpty) {
        total++;
        final entry = StudentAttendance.fromFirestore(entriesSnapshot.docs.first);

        switch (entry.status) {
          case AttendanceStatus.present:
            present++;
            break;
          case AttendanceStatus.absent:
            absent++;
            break;
          case AttendanceStatus.late:
            late++;
            break;
          case AttendanceStatus.unmarked:
            // Don't count unmarked
            break;
        }

        // Add to recent attendance (last 7 entries)
        if (recentAttendance.length < 7) {
          final recordData = recordDoc.data();
          recentAttendance.add(RecentAttendance(
            date: (recordData['date'] as Timestamp).toDate(),
            status: entry.status.name,
            remarks: null, // StudentAttendance doesn't have remarks field
          ));
        }
      }
    }

    final attendancePercentage = total > 0 ? (present + late) / total * 100 : 0.0;

    // Get performance data if available
    double? averagePerformance;
    int? classRank;
    try {
      final perfSummary = await getStudentPerformance(instituteId, studentId);
      averagePerformance = perfSummary.averagePercentage;
      classRank = perfSummary.rank;
    } catch (_) {
      // Performance data not available
    }

    // Get pending fees
    double? pendingFees;
    try {
      final invoices = await _firestore
          .collection('institutes')
          .doc(instituteId)
          .collection('invoices')
          .where('studentId', isEqualTo: studentId)
          .where('status', whereIn: [
            PaymentStatus.pending.name,
            PaymentStatus.partial.name,
            PaymentStatus.overdue.name,
          ])
          .get();

      pendingFees = invoices.docs.fold<double>(0, (sum, doc) {
        final data = doc.data();
        return sum + ((data['balanceDue'] as num?)?.toDouble() ?? 0);
      });
    } catch (_) {
      // Fee data not available
    }

    return ChildSummary(
      studentId: studentId,
      studentName: student.name,
      batchId: batchId,
      batchName: batch?.name ?? 'Unknown Batch',
      attendancePercentage: attendancePercentage,
      presentDays: present,
      absentDays: absent,
      lateDays: late,
      totalClasses: total,
      averagePerformance: averagePerformance,
      classRank: classRank,
      pendingFees: pendingFees,
      recentAttendance: recentAttendance,
    );
  }

  /// Get parent dashboard data
  Future<ParentDashboardData> getParentDashboard(String parentPhone) async {
    // Get parent
    final parent = await getParentByPhone(parentPhone);
    if (parent == null) {
      throw Exception('Parent not found');
    }

    // Get linked students
    final links = await getLinkedStudents(parentPhone);

    // Get child summaries
    final children = <ChildSummary>[];
    final batchIds = <String>{};

    for (final link in links) {
      try {
        final summary = await getChildSummary(
          link.instituteId,
          link.studentId,
          link.batchId,
        );
        children.add(summary);
        batchIds.add(link.batchId);
      } catch (_) {
        // Skip if error
      }
    }

    // Get announcements for linked batches
    final announcements = <Announcement>[];
    if (links.isNotEmpty) {
      final allAnnouncements = await getActiveAnnouncements(parent.instituteId);
      for (final announcement in allAnnouncements) {
        // Check if announcement targets any of the parent's children's batches
        if (announcement.targetBatchIds == null ||
            announcement.targetBatchIds!.any((b) => batchIds.contains(b))) {
          announcements.add(announcement);
        }
      }
    }

    // Get pending leave requests
    final pendingRequests = <LeaveRequest>[];
    for (final link in links) {
      final requests = await _firestore
          .collection('leaveRequests')
          .where('studentId', isEqualTo: link.studentId)
          .where('status', isEqualTo: LeaveRequestStatus.pending.name)
          .get();
      pendingRequests.addAll(
        requests.docs.map((doc) => LeaveRequest.fromFirestore(doc)),
      );
    }

    return ParentDashboardData(
      parent: parent,
      children: children,
      announcements: announcements,
      pendingLeaveRequests: pendingRequests,
    );
  }
}
