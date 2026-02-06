import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of tests/exams
enum TestType {
  quiz,
  unitTest,
  midterm,
  final_,
  practice,
  assignment,
  other;

  String get displayName {
    switch (this) {
      case TestType.quiz:
        return 'Quiz';
      case TestType.unitTest:
        return 'Unit Test';
      case TestType.midterm:
        return 'Midterm';
      case TestType.final_:
        return 'Final Exam';
      case TestType.practice:
        return 'Practice Test';
      case TestType.assignment:
        return 'Assignment';
      case TestType.other:
        return 'Other';
    }
  }

  String get shortName {
    switch (this) {
      case TestType.quiz:
        return 'Q';
      case TestType.unitTest:
        return 'UT';
      case TestType.midterm:
        return 'MT';
      case TestType.final_:
        return 'F';
      case TestType.practice:
        return 'P';
      case TestType.assignment:
        return 'A';
      case TestType.other:
        return 'O';
    }
  }
}

/// Subject for organizing tests
class Subject {
  final String id;
  final String name;
  final String? code;
  final String? color; // Hex color for UI
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;

  Subject({
    required this.id,
    required this.name,
    this.code,
    this.color,
    this.sortOrder = 0,
    this.isActive = true,
    required this.createdAt,
  });

  factory Subject.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Subject(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      code: data['code'] as String?,
      color: data['color'] as String?,
      sortOrder: (data['sortOrder'] as int?) ?? 0,
      isActive: (data['isActive'] as bool?) ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'code': code,
      'color': color,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Subject copyWith({
    String? id,
    String? name,
    String? code,
    String? color,
    int? sortOrder,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Subject(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Test/Exam definition
class Test {
  final String id;
  final String batchId;
  final String? subjectId;
  final String name;
  final String? description;
  final TestType type;
  final double maxMarks;
  final double? passingMarks;
  final DateTime testDate;
  final int? durationMinutes;
  final bool isPublished; // Whether scores are visible to parents
  final String? createdBy; // Teacher ID
  final DateTime createdAt;
  final DateTime updatedAt;

  Test({
    required this.id,
    required this.batchId,
    this.subjectId,
    required this.name,
    this.description,
    required this.type,
    required this.maxMarks,
    this.passingMarks,
    required this.testDate,
    this.durationMinutes,
    this.isPublished = false,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Test.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Test(
      id: doc.id,
      batchId: (data['batchId'] as String?) ?? '',
      subjectId: data['subjectId'] as String?,
      name: (data['name'] as String?) ?? '',
      description: data['description'] as String?,
      type: TestType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => TestType.other,
      ),
      maxMarks: ((data['maxMarks'] as num?) ?? 100).toDouble(),
      passingMarks: (data['passingMarks'] as num?)?.toDouble(),
      testDate: (data['testDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationMinutes: data['durationMinutes'] as int?,
      isPublished: (data['isPublished'] as bool?) ?? false,
      createdBy: data['createdBy'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'batchId': batchId,
      'subjectId': subjectId,
      'name': name,
      'description': description,
      'type': type.name,
      'maxMarks': maxMarks,
      'passingMarks': passingMarks,
      'testDate': Timestamp.fromDate(testDate),
      'durationMinutes': durationMinutes,
      'isPublished': isPublished,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Test copyWith({
    String? id,
    String? batchId,
    String? subjectId,
    String? name,
    String? description,
    TestType? type,
    double? maxMarks,
    double? passingMarks,
    DateTime? testDate,
    int? durationMinutes,
    bool? isPublished,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Test(
      id: id ?? this.id,
      batchId: batchId ?? this.batchId,
      subjectId: subjectId ?? this.subjectId,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      maxMarks: maxMarks ?? this.maxMarks,
      passingMarks: passingMarks ?? this.passingMarks,
      testDate: testDate ?? this.testDate,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isPublished: isPublished ?? this.isPublished,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get the passing percentage
  double? get passingPercentage {
    if (passingMarks == null) return null;
    return (passingMarks! / maxMarks) * 100;
  }

  /// Format duration as string
  String get formattedDuration {
    if (durationMinutes == null) return 'No time limit';
    if (durationMinutes! < 60) return '$durationMinutes mins';
    final hours = durationMinutes! ~/ 60;
    final mins = durationMinutes! % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }
}

/// Student score for a test
class Score {
  final String id;
  final String testId;
  final String studentId;
  final double? marksObtained; // null if absent/not graded
  final bool isAbsent;
  final bool isExempt; // Exempt from this test
  final String? remarks;
  final String? gradedBy; // Teacher ID
  final DateTime createdAt;
  final DateTime updatedAt;

  Score({
    required this.id,
    required this.testId,
    required this.studentId,
    this.marksObtained,
    this.isAbsent = false,
    this.isExempt = false,
    this.remarks,
    this.gradedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Score.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Score(
      id: doc.id,
      testId: (data['testId'] as String?) ?? '',
      studentId: (data['studentId'] as String?) ?? '',
      marksObtained: (data['marksObtained'] as num?)?.toDouble(),
      isAbsent: (data['isAbsent'] as bool?) ?? false,
      isExempt: (data['isExempt'] as bool?) ?? false,
      remarks: data['remarks'] as String?,
      gradedBy: data['gradedBy'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'testId': testId,
      'studentId': studentId,
      'marksObtained': marksObtained,
      'isAbsent': isAbsent,
      'isExempt': isExempt,
      'remarks': remarks,
      'gradedBy': gradedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Score copyWith({
    String? id,
    String? testId,
    String? studentId,
    double? marksObtained,
    bool? isAbsent,
    bool? isExempt,
    String? remarks,
    String? gradedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Score(
      id: id ?? this.id,
      testId: testId ?? this.testId,
      studentId: studentId ?? this.studentId,
      marksObtained: marksObtained ?? this.marksObtained,
      isAbsent: isAbsent ?? this.isAbsent,
      isExempt: isExempt ?? this.isExempt,
      remarks: remarks ?? this.remarks,
      gradedBy: gradedBy ?? this.gradedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Calculate percentage (if applicable)
  double? percentage(double maxMarks) {
    if (marksObtained == null || isAbsent || isExempt) return null;
    return (marksObtained! / maxMarks) * 100;
  }

  /// Get letter grade based on percentage
  String? letterGrade(double maxMarks) {
    final pct = percentage(maxMarks);
    if (pct == null) return null;
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B+';
    if (pct >= 60) return 'B';
    if (pct >= 50) return 'C';
    if (pct >= 40) return 'D';
    return 'F';
  }

  /// Check if passed (if passing marks defined)
  bool? hasPassed(double? passingMarks) {
    if (passingMarks == null || marksObtained == null) return null;
    if (isAbsent || isExempt) return null;
    return marksObtained! >= passingMarks;
  }
}

/// Summary of a student's performance in a test
class StudentTestResult {
  final String studentId;
  final String studentName;
  final Score? score;
  final double maxMarks;
  final double? passingMarks;
  final int? rank;

  StudentTestResult({
    required this.studentId,
    required this.studentName,
    this.score,
    required this.maxMarks,
    this.passingMarks,
    this.rank,
  });

  double? get percentage => score?.percentage(maxMarks);
  String? get letterGrade => score?.letterGrade(maxMarks);
  bool? get hasPassed => score?.hasPassed(passingMarks);

  String get displayScore {
    if (score == null) return 'Not graded';
    if (score!.isAbsent) return 'Absent';
    if (score!.isExempt) return 'Exempt';
    if (score!.marksObtained == null) return 'Pending';
    return '${score!.marksObtained!.toStringAsFixed(1)}/${maxMarks.toStringAsFixed(0)}';
  }
}

/// Test analytics/statistics
class TestAnalytics {
  final String testId;
  final String testName;
  final double maxMarks;
  final int totalStudents;
  final int gradedCount;
  final int absentCount;
  final int exemptCount;
  final int passedCount;
  final int failedCount;
  final double? highestMarks;
  final double? lowestMarks;
  final double? averageMarks;
  final double? medianMarks;
  final Map<String, int> gradeDistribution; // e.g., {'A+': 5, 'A': 10, ...}

  TestAnalytics({
    required this.testId,
    required this.testName,
    required this.maxMarks,
    required this.totalStudents,
    required this.gradedCount,
    required this.absentCount,
    required this.exemptCount,
    required this.passedCount,
    required this.failedCount,
    this.highestMarks,
    this.lowestMarks,
    this.averageMarks,
    this.medianMarks,
    this.gradeDistribution = const {},
  });

  double get gradedPercentage =>
      totalStudents > 0 ? (gradedCount / totalStudents) * 100 : 0;

  double get passPercentage =>
      gradedCount > 0 ? (passedCount / gradedCount) * 100 : 0;

  double get averagePercentage =>
      averageMarks != null ? (averageMarks! / maxMarks) * 100 : 0;

  String get formattedAverage =>
      averageMarks != null ? averageMarks!.toStringAsFixed(1) : '-';
}

/// Student's overall performance summary
class StudentPerformanceSummary {
  final String studentId;
  final String studentName;
  final String batchName;
  final int totalTests;
  final int testsAppeared;
  final int testsPassed;
  final double averagePercentage;
  final double? trend; // Positive = improving, negative = declining
  final int rank;
  final int totalStudentsInBatch;
  final Map<String, double> subjectAverages; // subjectId -> avg percentage
  final List<RecentTestScore> recentScores;

  StudentPerformanceSummary({
    required this.studentId,
    required this.studentName,
    required this.batchName,
    required this.totalTests,
    required this.testsAppeared,
    required this.testsPassed,
    required this.averagePercentage,
    this.trend,
    required this.rank,
    required this.totalStudentsInBatch,
    this.subjectAverages = const {},
    this.recentScores = const [],
  });

  double get attendanceRate =>
      totalTests > 0 ? (testsAppeared / totalTests) * 100 : 0;

  double get passRate =>
      testsAppeared > 0 ? (testsPassed / testsAppeared) * 100 : 0;

  String get rankSuffix {
    if (rank >= 11 && rank <= 13) return 'th';
    switch (rank % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  String get formattedRank => '$rank$rankSuffix';

  bool get isImproving => trend != null && trend! > 0;
  bool get isDeclining => trend != null && trend! < 0;
}

/// Recent test score for display
class RecentTestScore {
  final String testId;
  final String testName;
  final TestType testType;
  final DateTime testDate;
  final double? percentage;
  final String? letterGrade;
  final bool? passed;

  RecentTestScore({
    required this.testId,
    required this.testName,
    required this.testType,
    required this.testDate,
    this.percentage,
    this.letterGrade,
    this.passed,
  });
}

/// Batch performance overview
class BatchPerformanceOverview {
  final String batchId;
  final String batchName;
  final int totalStudents;
  final int totalTests;
  final double averageAttendance; // Test attendance
  final double averageScore;
  final double passRate;
  final List<StudentRanking> topPerformers;
  final List<StudentRanking> needsAttention; // Low performers
  final List<SubjectPerformance> subjectPerformances;

  BatchPerformanceOverview({
    required this.batchId,
    required this.batchName,
    required this.totalStudents,
    required this.totalTests,
    required this.averageAttendance,
    required this.averageScore,
    required this.passRate,
    this.topPerformers = const [],
    this.needsAttention = const [],
    this.subjectPerformances = const [],
  });
}

/// Student ranking entry
class StudentRanking {
  final String studentId;
  final String studentName;
  final int rank;
  final double averagePercentage;
  final double? trend;

  StudentRanking({
    required this.studentId,
    required this.studentName,
    required this.rank,
    required this.averagePercentage,
    this.trend,
  });
}

/// Subject-wise performance
class SubjectPerformance {
  final String subjectId;
  final String subjectName;
  final int testCount;
  final double averageScore;
  final double passRate;
  final double? trend;

  SubjectPerformance({
    required this.subjectId,
    required this.subjectName,
    required this.testCount,
    required this.averageScore,
    required this.passRate,
    this.trend,
  });
}
