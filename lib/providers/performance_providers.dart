import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Provider for subjects in an institute
final subjectsProvider = StreamProvider.family<List<Subject>, String>((ref, instituteId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.subjectsStream(instituteId);
});

/// Provider for tests in a batch
final batchTestsProvider = StreamProvider.family<List<Test>, ({String instituteId, String batchId})>((ref, params) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.batchTestsStream(params.instituteId, params.batchId);
});

/// Provider for a single test
final testProvider = FutureProvider.family<Test?, ({String instituteId, String testId})>((ref, params) async {
  final firestoreService = ref.read(firestoreServiceProvider);
  return firestoreService.getTest(params.instituteId, params.testId);
});

/// Provider for scores of a test
final testScoresProvider = StreamProvider.family<List<Score>, ({String instituteId, String testId})>((ref, params) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.testScoresStream(params.instituteId, params.testId);
});

/// Provider for test analytics
final testAnalyticsProvider = FutureProvider.family<TestAnalytics, ({String instituteId, String testId})>((ref, params) async {
  final firestoreService = ref.read(firestoreServiceProvider);
  return firestoreService.getTestAnalytics(params.instituteId, params.testId);
});

/// Provider for test results (students with scores and rankings)
final testResultsProvider = FutureProvider.family<List<StudentTestResult>, ({String instituteId, String testId})>((ref, params) async {
  final firestoreService = ref.read(firestoreServiceProvider);
  return firestoreService.getTestResults(params.instituteId, params.testId);
});

/// Provider for a student's overall performance
final studentPerformanceProvider = FutureProvider.family<StudentPerformanceSummary, ({String instituteId, String studentId})>((ref, params) async {
  final firestoreService = ref.read(firestoreServiceProvider);
  return firestoreService.getStudentPerformance(params.instituteId, params.studentId);
});

/// Provider for batch performance overview
final batchPerformanceProvider = FutureProvider.family<BatchPerformanceOverview, ({String instituteId, String batchId})>((ref, params) async {
  final firestoreService = ref.read(firestoreServiceProvider);
  return firestoreService.getBatchPerformanceOverview(params.instituteId, params.batchId);
});

/// Provider for recent tests across institute
final recentTestsProvider = FutureProvider.family<List<Test>, String>((ref, instituteId) async {
  final firestoreService = ref.read(firestoreServiceProvider);
  return firestoreService.getRecentTests(instituteId, limit: 10);
});

/// Provider for student scores
final studentScoresProvider = FutureProvider.family<List<Score>, ({String instituteId, String studentId})>((ref, params) async {
  final firestoreService = ref.read(firestoreServiceProvider);
  return firestoreService.getStudentScores(params.instituteId, params.studentId);
});

/// Dashboard data for performance overview
class PerformanceDashboardData {
  final int totalTests;
  final int recentTestsCount; // Tests in last 30 days
  final int upcomingGradingCount; // Tests with ungradedstudents
  final double averageBatchPerformance;
  final List<Test> recentTests;
  final List<({String batchName, double average})> batchAverages;

  PerformanceDashboardData({
    required this.totalTests,
    required this.recentTestsCount,
    required this.upcomingGradingCount,
    required this.averageBatchPerformance,
    required this.recentTests,
    required this.batchAverages,
  });
}

/// Provider for performance dashboard data
final performanceDashboardProvider = FutureProvider.family<PerformanceDashboardData, String>((ref, instituteId) async {
  final firestoreService = ref.read(firestoreServiceProvider);

  // Get all batches
  final batches = await firestoreService.getBatches(instituteId);

  // Get recent tests
  final recentTests = await firestoreService.getRecentTests(instituteId, limit: 10);

  // Count tests in last 30 days
  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
  final recentTestsCount = recentTests.where((t) => t.testDate.isAfter(thirtyDaysAgo)).length;

  // Count total tests and calculate batch averages
  int totalTests = 0;
  double totalBatchAvg = 0;
  int batchesWithTests = 0;
  final batchAverages = <({String batchName, double average})>[];

  for (final batch in batches) {
    final batchTests = await firestoreService.getBatchTests(instituteId, batch.id);
    totalTests += batchTests.length;

    if (batchTests.isNotEmpty) {
      try {
        final overview = await firestoreService.getBatchPerformanceOverview(instituteId, batch.id);
        batchAverages.add((batchName: batch.name, average: overview.averageScore));
        totalBatchAvg += overview.averageScore;
        batchesWithTests++;
      } catch (_) {
        // Skip batches with errors
      }
    }
  }

  // Sort batch averages by performance
  batchAverages.sort((a, b) => b.average.compareTo(a.average));

  // Count tests needing grading
  int upcomingGradingCount = 0;
  for (final test in recentTests) {
    final students = await firestoreService.getStudentsForBatch(instituteId, test.batchId);
    final scores = await firestoreService.getTestScores(instituteId, test.id);
    final ungradedCount = students.length - scores.length;
    if (ungradedCount > 0) {
      upcomingGradingCount++;
    }
  }

  return PerformanceDashboardData(
    totalTests: totalTests,
    recentTestsCount: recentTestsCount,
    upcomingGradingCount: upcomingGradingCount,
    averageBatchPerformance: batchesWithTests > 0 ? totalBatchAvg / batchesWithTests : 0,
    recentTests: recentTests,
    batchAverages: batchAverages,
  );
});
