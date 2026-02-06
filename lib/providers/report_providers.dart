import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Provider for today's attendance summary across all batches
final todaysSummaryProvider = FutureProvider.family<TodaysSummaryData, String>((ref, instituteId) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final summaries = await firestoreService.getTodaysSummary(instituteId);
  final absentStudents = await firestoreService.getTodaysAbsentStudents(instituteId);

  return TodaysSummaryData(
    batchSummaries: summaries,
    absentStudents: absentStudents,
  );
});

/// Provider for today's absent students
final todaysAbsentProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, instituteId) {
  return ref.watch(firestoreServiceProvider).getTodaysAbsentStudents(instituteId);
});

/// Provider for audit logs
final auditLogsProvider = StreamProvider.family<List<AuditLog>, ({String instituteId, int limit, AuditAction? filterAction})>((ref, params) {
  return ref.watch(firestoreServiceProvider).auditLogsStream(
    params.instituteId,
    limit: params.limit,
    filterAction: params.filterAction,
  );
});

/// Data class for today's summary
class TodaysSummaryData {
  final Map<String, AttendanceSummary> batchSummaries;
  final List<Map<String, dynamic>> absentStudents;

  TodaysSummaryData({
    required this.batchSummaries,
    required this.absentStudents,
  });

  int get totalPresent => batchSummaries.values.fold(0, (sum, s) => sum + s.presentCount);
  int get totalAbsent => batchSummaries.values.fold(0, (sum, s) => sum + s.absentCount);
  int get totalLate => batchSummaries.values.fold(0, (sum, s) => sum + s.lateCount);
  int get totalStudents => batchSummaries.values.fold(0, (sum, s) => sum + s.totalStudents);
  int get batchesMarked => batchSummaries.length;

  double get overallAttendanceRate {
    if (totalStudents == 0) return 0;
    return ((totalPresent + totalLate) / totalStudents) * 100;
  }
}

/// Provider for notification status of a specific attendance record
final notificationStatusProvider = StreamProvider.family<List<NotificationStatusEntry>, ({String instituteId, String attendanceId})>((ref, params) {
  return FirebaseFirestore.instance
      .collection('institutes')
      .doc(params.instituteId)
      .collection('attendance')
      .doc(params.attendanceId)
      .collection('records')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return NotificationStatusEntry(
              studentId: (data['studentId'] as String?) ?? '',
              studentName: (data['studentName'] as String?) ?? '',
              status: NotificationStatus.fromString((data['notificationStatus'] as String?) ?? 'pending'),
              channel: NotificationChannel.fromString((data['notificationChannel'] as String?) ?? 'none'),
              error: data['notificationError'] as String?,
              sentAt: (data['notificationSentAt'] as Timestamp?)?.toDate(),
            );
          }).toList());
});

/// Provider for pending notifications count
final pendingNotificationsProvider = FutureProvider.family<int, String>((ref, instituteId) async {
  final today = DateTime.now();
  final startOfDay = DateTime(today.year, today.month, today.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  final attendanceQuery = await FirebaseFirestore.instance
      .collection('institutes')
      .doc(instituteId)
      .collection('attendance')
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
      .where('date', isLessThan: Timestamp.fromDate(endOfDay))
      .get();

  int pendingCount = 0;
  for (final doc in attendanceQuery.docs) {
    final records = await doc.reference
        .collection('records')
        .where('notificationStatus', isEqualTo: 'pending')
        .get();
    pendingCount += records.docs.length;
  }

  return pendingCount;
});

/// Data class for notification status entry
class NotificationStatusEntry {
  final String studentId;
  final String studentName;
  final NotificationStatus status;
  final NotificationChannel channel;
  final String? error;
  final DateTime? sentAt;

  NotificationStatusEntry({
    required this.studentId,
    required this.studentName,
    required this.status,
    required this.channel,
    this.error,
    this.sentAt,
  });

  bool get isPending => status == NotificationStatus.pending;
  bool get isFailed => status == NotificationStatus.failed;
  bool get isDelivered => status == NotificationStatus.delivered || status == NotificationStatus.read;
}
