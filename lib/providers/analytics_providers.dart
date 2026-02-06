import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Provider for the selected analytics period
final analyticsPeriodProvider = StateProvider<AnalyticsPeriod>((ref) {
  return AnalyticsPeriod.month;
});

/// Provider for complete dashboard analytics
final dashboardAnalyticsProvider = FutureProvider.family<DashboardAnalytics?, String>((ref, instituteId) async {
  final period = ref.watch(analyticsPeriodProvider);
  final firestoreService = ref.watch(firestoreServiceProvider);

  // Fetch all necessary data
  final batches = await firestoreService.getBatches(instituteId);
  if (batches.isEmpty) return null;

  final startDate = period.startDate;
  final endDate = period.endDate;
  final prevStart = period.previousPeriodStart;
  final prevEnd = period.previousPeriodEnd;

  // Compute analytics for each batch
  final batchComparisons = <BatchComparisonData>[];
  final allTrendPoints = <DateTime, _TrendAccumulator>{};
  var totalPresent = 0;
  var totalAbsent = 0;
  var totalLate = 0;
  var totalClasses = 0;
  var prevTotalPresent = 0;
  var prevTotalLate = 0;
  var prevTotalClasses = 0;

  for (final batch in batches) {
    if (!batch.isActive) continue;

    // Get attendance data for this batch in the period
    final attendanceRecords = await firestoreService.getAttendanceRecordsForRange(
      instituteId,
      batch.id,
      startDate,
      endDate,
    );

    // Get previous period data for comparison
    final prevAttendanceRecords = await firestoreService.getAttendanceRecordsForRange(
      instituteId,
      batch.id,
      prevStart,
      prevEnd,
    );

    var batchPresent = 0;
    var batchAbsent = 0;
    var batchLate = 0;
    var batchClasses = 0;

    for (final record in attendanceRecords) {
      final entries = await firestoreService.getAttendanceEntries(instituteId, record.id);

      for (final entry in entries) {
        batchClasses++;
        switch (entry.status) {
          case AttendanceStatus.present:
            batchPresent++;
            break;
          case AttendanceStatus.absent:
            batchAbsent++;
            break;
          case AttendanceStatus.late:
            batchLate++;
            break;
          case AttendanceStatus.unmarked:
            break;
        }
      }

      // Accumulate for trend data
      final dateKey = DateTime(record.date.year, record.date.month, record.date.day);
      allTrendPoints.putIfAbsent(dateKey, () => _TrendAccumulator());
      allTrendPoints[dateKey]!.addEntries(entries);
    }

    // Previous period stats
    for (final record in prevAttendanceRecords) {
      final entries = await firestoreService.getAttendanceEntries(instituteId, record.id);
      for (final entry in entries) {
        prevTotalClasses++;
        switch (entry.status) {
          case AttendanceStatus.present:
            prevTotalPresent++;
            break;
          case AttendanceStatus.absent:
            // Not used in calculations (we only need present+late rate)
            break;
          case AttendanceStatus.late:
            prevTotalLate++;
            break;
          case AttendanceStatus.unmarked:
            break;
        }
      }
    }

    // Get student count for this batch
    final students = await firestoreService.getStudentsForBatch(instituteId, batch.id);
    final totalStudents = students.where((s) => s.isActive).length;

    if (batchClasses > 0) {
      final batchAttendance = ((batchPresent + batchLate) / batchClasses) * 100;
      batchComparisons.add(BatchComparisonData(
        batchId: batch.id,
        batchName: batch.name,
        attendancePercentage: batchAttendance,
        totalStudents: totalStudents,
        totalClasses: attendanceRecords.length,
        presentCount: batchPresent,
        absentCount: batchAbsent,
        lateCount: batchLate,
      ));
    }

    totalPresent += batchPresent;
    totalAbsent += batchAbsent;
    totalLate += batchLate;
    totalClasses += batchClasses;
  }

  // Sort batch comparisons by attendance
  batchComparisons.sort((a, b) => b.attendancePercentage.compareTo(a.attendancePercentage));

  // Build trend data
  final trendData = allTrendPoints.entries.map((e) {
    final acc = e.value;
    return AttendanceTrendPoint(
      date: e.key,
      attendancePercentage: acc.attendancePercentage,
      totalStudents: acc.total,
      presentCount: acc.present,
      absentCount: acc.absent,
      lateCount: acc.late,
    );
  }).toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  // Get at-risk students
  final atRiskStudents = await _computeAtRiskStudents(
    firestoreService,
    instituteId,
    batches,
    startDate,
    endDate,
  );

  // Compute weekly stats
  final weeklyStats = _computeWeeklyStats(trendData, startDate, endDate);

  // Calculate overall percentages
  final overallAttendance = totalClasses > 0
      ? ((totalPresent + totalLate) / totalClasses) * 100
      : 0.0;
  final prevAttendance = prevTotalClasses > 0
      ? ((prevTotalPresent + prevTotalLate) / prevTotalClasses) * 100
      : 0.0;

  // Count total active students
  var totalActiveStudents = 0;
  for (final batch in batches) {
    if (!batch.isActive) continue;
    final students = await firestoreService.getStudentsForBatch(instituteId, batch.id);
    totalActiveStudents += students.where((s) => s.isActive).length;
  }

  return DashboardAnalytics(
    summary: AnalyticsSummary(
      overallAttendance: overallAttendance,
      previousPeriodAttendance: prevAttendance,
      totalStudents: totalActiveStudents,
      totalBatches: batches.where((b) => b.isActive).length,
      totalClassesThisMonth: trendData.length,
      atRiskCount: atRiskStudents.length,
    ),
    trendData: trendData,
    batchComparison: batchComparisons,
    atRiskStudents: atRiskStudents,
    weeklyStats: weeklyStats,
    distribution: AttendanceDistribution(
      presentCount: totalPresent,
      absentCount: totalAbsent,
      lateCount: totalLate,
      totalClasses: totalClasses,
    ),
    period: period,
  );
});

/// Provider for at-risk students only (lighter query)
final atRiskStudentsProvider = FutureProvider.family<List<AtRiskStudent>, String>((ref, instituteId) async {
  final analytics = await ref.watch(dashboardAnalyticsProvider(instituteId).future);
  return analytics?.atRiskStudents ?? [];
});

/// Provider for batch comparison data
final batchComparisonProvider = FutureProvider.family<List<BatchComparisonData>, String>((ref, instituteId) async {
  final analytics = await ref.watch(dashboardAnalyticsProvider(instituteId).future);
  return analytics?.batchComparison ?? [];
});

/// Helper class to accumulate trend data
class _TrendAccumulator {
  int present = 0;
  int absent = 0;
  int late = 0;
  int total = 0;

  void addEntries(List<StudentAttendance> entries) {
    for (final entry in entries) {
      total++;
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
          break;
      }
    }
  }

  double get attendancePercentage {
    if (total == 0) return 0;
    return ((present + late) / total) * 100;
  }
}

/// Compute at-risk students based on attendance patterns
Future<List<AtRiskStudent>> _computeAtRiskStudents(
  FirestoreService firestoreService,
  String instituteId,
  List<Batch> batches,
  DateTime startDate,
  DateTime endDate,
) async {
  final atRiskStudents = <AtRiskStudent>[];

  for (final batch in batches) {
    if (!batch.isActive) continue;

    final students = await firestoreService.getStudentsForBatch(instituteId, batch.id);

    for (final student in students) {
      if (!student.isActive) continue;

      // Get student's attendance history
      final history = await firestoreService.getStudentAttendanceHistory(
        instituteId,
        batch.id,
        student.id,
        startDate: startDate,
        endDate: endDate,
      );

      if (history.isEmpty) continue;

      // Calculate stats
      var presentCount = 0;
      var absentCount = 0;
      var lateCount = 0;
      var consecutiveAbsences = 0;
      var maxConsecutiveAbsences = 0;
      DateTime? lastPresent;

      // Sort by date descending for consecutive absence tracking
      final sortedHistory = List<StudentAttendanceHistoryEntry>.from(history)
        ..sort((a, b) => b.date.compareTo(a.date));

      for (final entry in sortedHistory) {
        switch (entry.status) {
          case AttendanceStatus.present:
            presentCount++;
            if (lastPresent == null) lastPresent = entry.date;
            if (consecutiveAbsences > maxConsecutiveAbsences) {
              maxConsecutiveAbsences = consecutiveAbsences;
            }
            consecutiveAbsences = 0;
            break;
          case AttendanceStatus.absent:
            absentCount++;
            consecutiveAbsences++;
            break;
          case AttendanceStatus.late:
            lateCount++;
            if (lastPresent == null) lastPresent = entry.date;
            if (consecutiveAbsences > maxConsecutiveAbsences) {
              maxConsecutiveAbsences = consecutiveAbsences;
            }
            consecutiveAbsences = 0;
            break;
          case AttendanceStatus.unmarked:
            break;
        }
      }

      // Check final consecutive absences
      if (consecutiveAbsences > maxConsecutiveAbsences) {
        maxConsecutiveAbsences = consecutiveAbsences;
      }

      final totalClasses = presentCount + absentCount + lateCount;
      if (totalClasses == 0) continue;

      final attendancePercentage = ((presentCount + lateCount) / totalClasses) * 100;

      // Determine if student is at-risk
      AtRiskReason? reason;

      if (attendancePercentage < 75) {
        reason = AtRiskReason.lowAttendance;
      } else if (maxConsecutiveAbsences >= 3) {
        reason = AtRiskReason.consecutiveAbsences;
      }
      // Could add more sophisticated trend detection here

      if (reason != null) {
        atRiskStudents.add(AtRiskStudent(
          studentId: student.id,
          studentName: student.name,
          batchId: batch.id,
          batchName: batch.name,
          attendancePercentage: attendancePercentage,
          consecutiveAbsences: maxConsecutiveAbsences,
          totalAbsences: absentCount,
          totalClasses: totalClasses,
          reason: reason,
          lastPresent: lastPresent,
        ));
      }
    }
  }

  // Sort by risk level (high first) then by attendance percentage
  atRiskStudents.sort((a, b) {
    final levelCompare = a.riskLevel.index.compareTo(b.riskLevel.index);
    if (levelCompare != 0) return levelCompare;
    return a.attendancePercentage.compareTo(b.attendancePercentage);
  });

  return atRiskStudents;
}

/// Compute weekly statistics from trend data
List<WeeklyStats> _computeWeeklyStats(
  List<AttendanceTrendPoint> trendData,
  DateTime startDate,
  DateTime endDate,
) {
  if (trendData.isEmpty) return [];

  // Group by week
  final weeklyMap = <int, List<AttendanceTrendPoint>>{};

  for (final point in trendData) {
    // Calculate week number from start date
    final weekNum = point.date.difference(startDate).inDays ~/ 7;
    weeklyMap.putIfAbsent(weekNum, () => []).add(point);
  }

  final weeklyStats = <WeeklyStats>[];

  for (final entry in weeklyMap.entries) {
    final weekNum = entry.key;
    final points = entry.value;

    var totalPresent = 0;
    var totalAbsent = 0;
    var totalLate = 0;
    var totalEntries = 0;

    for (final point in points) {
      totalPresent += point.presentCount;
      totalAbsent += point.absentCount;
      totalLate += point.lateCount;
      totalEntries += point.totalStudents;
    }

    final weekStart = startDate.add(Duration(days: weekNum * 7));
    final weekEnd = weekStart.add(const Duration(days: 6));

    final attendancePercentage = totalEntries > 0
        ? ((totalPresent + totalLate) / totalEntries) * 100
        : 0.0;

    weeklyStats.add(WeeklyStats(
      weekNumber: weekNum + 1,
      weekStart: weekStart,
      weekEnd: weekEnd.isAfter(endDate) ? endDate : weekEnd,
      attendancePercentage: attendancePercentage,
      classesHeld: points.length,
      totalPresent: totalPresent,
      totalAbsent: totalAbsent,
      totalLate: totalLate,
    ));
  }

  // Sort by week number and calculate changes
  weeklyStats.sort((a, b) => a.weekNumber.compareTo(b.weekNumber));

  for (var i = 1; i < weeklyStats.length; i++) {
    weeklyStats[i].percentageChange =
        weeklyStats[i].attendancePercentage - weeklyStats[i - 1].attendancePercentage;
  }

  return weeklyStats;
}
