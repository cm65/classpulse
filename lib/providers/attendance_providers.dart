import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Provider for batches in an institute
final batchesProvider = StreamProvider.family<List<Batch>, String>((ref, instituteId) {
  return ref.watch(firestoreServiceProvider).batchesStream(instituteId);
});

/// Provider for students in a specific batch
final studentsProvider = StreamProvider.family<List<Student>, ({String instituteId, String batchId})>((ref, params) {
  return ref.watch(firestoreServiceProvider).studentsStream(params.instituteId, params.batchId);
});

/// Provider for attendance entries of a specific record
final attendanceEntriesProvider = StreamProvider.family<List<StudentAttendance>, ({String instituteId, String attendanceId})>((ref, params) {
  return ref.watch(firestoreServiceProvider).attendanceEntriesStream(params.instituteId, params.attendanceId);
});

/// Provider to check if attendance exists for a batch on a specific date
final attendanceExistsProvider = FutureProvider.family<AttendanceRecord?, ({String instituteId, String batchId, DateTime date})>((ref, params) {
  return ref.watch(firestoreServiceProvider).getAttendance(params.instituteId, params.batchId, params.date);
});

/// Provider for student attendance history (raw stream, without dates)
final studentHistoryProvider = StreamProvider.family<List<StudentAttendance>, ({String instituteId, String studentId})>((ref, params) {
  return ref.watch(firestoreServiceProvider).studentHistoryStream(params.instituteId, params.studentId);
});

/// Provider for detailed student attendance history with dates (for calendar view)
/// Now accepts month/year parameters for efficient month-scoped queries
final studentHistoryWithDatesProvider = FutureProvider.family<List<StudentAttendanceHistoryEntry>, ({
  String instituteId,
  String batchId,
  String studentId,
  int? year,
  int? month,
})>((ref, params) {
  // Calculate date range based on month/year or default to last 3 months
  final DateTime startDate;
  final DateTime endDate;

  if (params.year != null && params.month != null) {
    // Fetch 3 months of data centered on the selected month for smooth navigation
    final selectedMonth = DateTime(params.year!, params.month!);
    startDate = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
    endDate = DateTime(selectedMonth.year, selectedMonth.month + 2, 0);
  } else {
    // Default: last 90 days
    endDate = DateTime.now();
    startDate = endDate.subtract(const Duration(days: 90));
  }

  return ref.watch(firestoreServiceProvider).getStudentAttendanceHistory(
    params.instituteId,
    params.batchId,
    params.studentId,
    startDate: startDate,
    endDate: endDate,
  );
});

/// Provider for monthly attendance report data (cached for 5 min)
final monthlyAttendanceProvider = FutureProvider.family<List<StudentMonthlyAttendance>, ({String instituteId, String batchId, DateTime month})>((ref, params) async {
  // Keep alive for 5 minutes to avoid re-fetching on navigation
  final link = ref.keepAlive();
  Future.delayed(const Duration(minutes: 5), () => link.close());

  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getMonthlyAttendanceReport(
    params.instituteId,
    params.batchId,
    params.month,
  );
});

/// Data class for today's attendance with batch info and edit status
class TodayAttendanceInfo {
  final AttendanceRecord record;
  final Batch batch;
  final AttendanceSummary summary;
  final bool canEdit;
  final Duration remainingEditTime;

  TodayAttendanceInfo({
    required this.record,
    required this.batch,
    required this.summary,
    required this.canEdit,
    required this.remainingEditTime,
  });
}

/// Default edit window (fallback if institute settings not available)
const defaultEditWindow = Duration(hours: 2);

/// Provider for today's attendance records with batch info and edit status (cached for 2 min)
final todayAttendanceListProvider = FutureProvider<List<TodayAttendanceInfo>>((ref) async {
  // Keep alive for 2 minutes to avoid re-fetching on dashboard navigation
  final link = ref.keepAlive();
  Future.delayed(const Duration(minutes: 2), () => link.close());
  final teacher = ref.watch(currentTeacherProvider).value;
  if (teacher == null) return [];

  final firestoreService = ref.watch(firestoreServiceProvider);

  // Get institute settings for edit window configuration
  final institute = await firestoreService.getInstitute(teacher.instituteId);
  final editWindow = institute?.settings.attendanceEditWindow ?? defaultEditWindow;

  // Get today's summaries (which fetches attendance records internally)
  final summaries = await firestoreService.getTodaysSummary(teacher.instituteId);
  if (summaries.isEmpty) return [];

  // Get batches
  final batchesSnapshot = await firestoreService.getBatches(teacher.instituteId);

  final result = <TodayAttendanceInfo>[];

  for (final batchId in summaries.keys) {
    // Get the batch info
    final batch = batchesSnapshot.firstWhere(
      (b) => b.id == batchId,
      orElse: () => Batch(
        id: batchId,
        instituteId: teacher.instituteId,
        name: 'Unknown Batch',
        scheduleDays: [],
        startTime: const ScheduleTime(hour: 9, minute: 0),
        endTime: const ScheduleTime(hour: 10, minute: 0),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    // Get the attendance record
    final record = await firestoreService.getAttendance(
      teacher.instituteId,
      batchId,
      DateTime.now(),
    );

    if (record != null) {
      final canEdit = record.canEdit(editWindow);
      final remainingTime = record.remainingEditTime(editWindow);

      result.add(TodayAttendanceInfo(
        record: record,
        batch: batch,
        summary: summaries[batchId]!,
        canEdit: canEdit,
        remainingEditTime: remainingTime,
      ));
    }
  }

  return result;
});
