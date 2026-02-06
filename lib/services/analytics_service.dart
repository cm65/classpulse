import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> logAttendanceSubmitted({
    required String instituteId,
    required String batchId,
    required int studentCount,
  }) async {
    await _analytics.logEvent(
      name: 'attendance_submitted',
      parameters: {
        'institute_id': instituteId,
        'batch_id': batchId,
        'student_count': studentCount,
      },
    );
  }

  Future<void> logStudentAdded({
    required String instituteId,
    required String batchId,
  }) async {
    await _analytics.logEvent(
      name: 'student_added',
      parameters: {
        'institute_id': instituteId,
        'batch_id': batchId,
      },
    );
  }

  Future<void> logBatchCreated({
    required String instituteId,
  }) async {
    await _analytics.logEvent(
      name: 'batch_created',
      parameters: {'institute_id': instituteId},
    );
  }

  Future<void> logNotificationSent({
    required String channel,
    required String status,
  }) async {
    await _analytics.logEvent(
      name: 'notification_sent',
      parameters: {
        'channel': channel,
        'status': status,
      },
    );
  }

  Future<void> logReportViewed({
    required String reportType,
    required String instituteId,
  }) async {
    await _analytics.logEvent(
      name: 'report_viewed',
      parameters: {
        'report_type': reportType,
        'institute_id': instituteId,
      },
    );
  }

  Future<void> logCsvImported({
    required String instituteId,
    required int studentCount,
  }) async {
    await _analytics.logEvent(
      name: 'csv_imported',
      parameters: {
        'institute_id': instituteId,
        'student_count': studentCount,
      },
    );
  }

  Future<void> setUserProperties({
    required String userId,
    String? instituteId,
    String? role,
  }) async {
    await _analytics.setUserId(id: userId);
    if (instituteId != null) {
      await _analytics.setUserProperty(
        name: 'institute_id',
        value: instituteId,
      );
    }
    if (role != null) {
      await _analytics.setUserProperty(name: 'role', value: role);
    }
  }
}
