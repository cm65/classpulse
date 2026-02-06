/// Analytics data models for the dashboard

/// Single point in an attendance trend line chart
class AttendanceTrendPoint {
  final DateTime date;
  final double attendancePercentage;
  final int totalStudents;
  final int presentCount;
  final int absentCount;
  final int lateCount;

  AttendanceTrendPoint({
    required this.date,
    required this.attendancePercentage,
    required this.totalStudents,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
  });

  /// Day of week (1=Monday, 7=Sunday)
  int get dayOfWeek => date.weekday;

  /// Week number in month (1-5)
  int get weekOfMonth => ((date.day - 1) ~/ 7) + 1;
}

/// Batch-level comparison data for bar charts
class BatchComparisonData {
  final String batchId;
  final String batchName;
  final double attendancePercentage;
  final int totalStudents;
  final int totalClasses;
  final int presentCount;
  final int absentCount;
  final int lateCount;

  BatchComparisonData({
    required this.batchId,
    required this.batchName,
    required this.attendancePercentage,
    required this.totalStudents,
    required this.totalClasses,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
  });

  /// Rank based on attendance (for sorting)
  int compareTo(BatchComparisonData other) {
    return other.attendancePercentage.compareTo(attendancePercentage);
  }
}

/// Student with concerning attendance patterns
class AtRiskStudent {
  final String studentId;
  final String studentName;
  final String batchId;
  final String batchName;
  final double attendancePercentage;
  final int consecutiveAbsences;
  final int totalAbsences;
  final int totalClasses;
  final AtRiskReason reason;
  final DateTime? lastPresent;

  AtRiskStudent({
    required this.studentId,
    required this.studentName,
    required this.batchId,
    required this.batchName,
    required this.attendancePercentage,
    required this.consecutiveAbsences,
    required this.totalAbsences,
    required this.totalClasses,
    required this.reason,
    this.lastPresent,
  });

  /// Risk severity: high (< 60%), medium (60-75%), low (75-85%)
  RiskLevel get riskLevel {
    if (attendancePercentage < 60) return RiskLevel.high;
    if (attendancePercentage < 75) return RiskLevel.medium;
    return RiskLevel.low;
  }

  /// Days since last present
  int? get daysSinceLastPresent {
    if (lastPresent == null) return null;
    return DateTime.now().difference(lastPresent!).inDays;
  }
}

/// Reason a student is considered at-risk
enum AtRiskReason {
  lowAttendance,
  consecutiveAbsences,
  decliningTrend,
  recentDropoff;

  String get displayName {
    switch (this) {
      case AtRiskReason.lowAttendance:
        return 'Low attendance rate';
      case AtRiskReason.consecutiveAbsences:
        return 'Multiple consecutive absences';
      case AtRiskReason.decliningTrend:
        return 'Declining attendance trend';
      case AtRiskReason.recentDropoff:
        return 'Recent attendance drop';
    }
  }

  String get shortName {
    switch (this) {
      case AtRiskReason.lowAttendance:
        return 'Low %';
      case AtRiskReason.consecutiveAbsences:
        return 'Consecutive';
      case AtRiskReason.decliningTrend:
        return 'Declining';
      case AtRiskReason.recentDropoff:
        return 'Drop-off';
    }
  }
}

/// Risk severity level
enum RiskLevel {
  high,
  medium,
  low;

  String get displayName {
    switch (this) {
      case RiskLevel.high:
        return 'High Risk';
      case RiskLevel.medium:
        return 'Medium Risk';
      case RiskLevel.low:
        return 'Low Risk';
    }
  }
}

/// Weekly attendance breakdown for comparison
class WeeklyStats {
  final int weekNumber;
  final DateTime weekStart;
  final DateTime weekEnd;
  final double attendancePercentage;
  final int classesHeld;
  final int totalPresent;
  final int totalAbsent;
  final int totalLate;

  WeeklyStats({
    required this.weekNumber,
    required this.weekStart,
    required this.weekEnd,
    required this.attendancePercentage,
    required this.classesHeld,
    required this.totalPresent,
    required this.totalAbsent,
    required this.totalLate,
  });

  /// Change from previous week (to show trend)
  double? percentageChange;

  /// Whether this week is better than previous
  bool? get isImproving => percentageChange != null ? percentageChange! > 0 : null;
}

/// Distribution of attendance statuses for pie charts
class AttendanceDistribution {
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int totalClasses;

  AttendanceDistribution({
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.totalClasses,
  });

  double get presentPercentage => totalClasses > 0 ? (presentCount / totalClasses) * 100 : 0;
  double get absentPercentage => totalClasses > 0 ? (absentCount / totalClasses) * 100 : 0;
  double get latePercentage => totalClasses > 0 ? (lateCount / totalClasses) * 100 : 0;
  double get attendanceRate => totalClasses > 0 ? ((presentCount + lateCount) / totalClasses) * 100 : 0;
}

/// Summary statistics for the analytics dashboard header
class AnalyticsSummary {
  final double overallAttendance;
  final double previousPeriodAttendance;
  final int totalStudents;
  final int totalBatches;
  final int totalClassesThisMonth;
  final int atRiskCount;

  AnalyticsSummary({
    required this.overallAttendance,
    required this.previousPeriodAttendance,
    required this.totalStudents,
    required this.totalBatches,
    required this.totalClassesThisMonth,
    required this.atRiskCount,
  });

  /// Change from previous period
  double get attendanceChange => overallAttendance - previousPeriodAttendance;

  /// Whether attendance is improving
  bool get isImproving => attendanceChange > 0;

  /// Percentage point change
  String get changeText {
    final change = attendanceChange.abs().toStringAsFixed(1);
    return isImproving ? '+$change%' : '-$change%';
  }
}

/// Time period for analytics queries
enum AnalyticsPeriod {
  week,
  month,
  quarter,
  year;

  String get displayName {
    switch (this) {
      case AnalyticsPeriod.week:
        return 'This Week';
      case AnalyticsPeriod.month:
        return 'This Month';
      case AnalyticsPeriod.quarter:
        return 'This Quarter';
      case AnalyticsPeriod.year:
        return 'This Year';
    }
  }

  /// Get start date for this period
  DateTime get startDate {
    final now = DateTime.now();
    switch (this) {
      case AnalyticsPeriod.week:
        return now.subtract(Duration(days: now.weekday - 1));
      case AnalyticsPeriod.month:
        return DateTime(now.year, now.month, 1);
      case AnalyticsPeriod.quarter:
        final quarterMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        return DateTime(now.year, quarterMonth, 1);
      case AnalyticsPeriod.year:
        return DateTime(now.year, 1, 1);
    }
  }

  /// Get end date for this period
  DateTime get endDate => DateTime.now();

  /// Get the previous period's start date for comparison
  DateTime get previousPeriodStart {
    final now = DateTime.now();
    switch (this) {
      case AnalyticsPeriod.week:
        return startDate.subtract(const Duration(days: 7));
      case AnalyticsPeriod.month:
        return DateTime(now.year, now.month - 1, 1);
      case AnalyticsPeriod.quarter:
        final quarterMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        return DateTime(now.year, quarterMonth - 3, 1);
      case AnalyticsPeriod.year:
        return DateTime(now.year - 1, 1, 1);
    }
  }

  /// Get previous period's end date
  DateTime get previousPeriodEnd {
    return startDate.subtract(const Duration(days: 1));
  }
}

/// Container for all dashboard analytics data
class DashboardAnalytics {
  final AnalyticsSummary summary;
  final List<AttendanceTrendPoint> trendData;
  final List<BatchComparisonData> batchComparison;
  final List<AtRiskStudent> atRiskStudents;
  final List<WeeklyStats> weeklyStats;
  final AttendanceDistribution distribution;
  final AnalyticsPeriod period;
  final DateTime generatedAt;

  DashboardAnalytics({
    required this.summary,
    required this.trendData,
    required this.batchComparison,
    required this.atRiskStudents,
    required this.weeklyStats,
    required this.distribution,
    required this.period,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();

  /// Best performing batch
  BatchComparisonData? get bestBatch {
    if (batchComparison.isEmpty) return null;
    return batchComparison.reduce((a, b) =>
        a.attendancePercentage > b.attendancePercentage ? a : b);
  }

  /// Worst performing batch
  BatchComparisonData? get worstBatch {
    if (batchComparison.isEmpty) return null;
    return batchComparison.reduce((a, b) =>
        a.attendancePercentage < b.attendancePercentage ? a : b);
  }

  /// High risk students only
  List<AtRiskStudent> get highRiskStudents =>
      atRiskStudents.where((s) => s.riskLevel == RiskLevel.high).toList();
}
