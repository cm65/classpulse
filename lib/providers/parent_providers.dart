import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/firestore_service.dart';

/// Provider for parent by phone number
final parentByPhoneProvider = FutureProvider.family<Parent?, String>((ref, phone) {
  return ref.watch(firestoreServiceProvider).getParentByPhone(phone);
});

/// Provider for parent by ID
final parentProvider = FutureProvider.family<Parent?, String>((ref, parentId) {
  return ref.watch(firestoreServiceProvider).getParent(parentId);
});

/// Provider for students linked to a parent phone
final linkedStudentsProvider = FutureProvider.family<List<ParentStudentLink>, String>((ref, parentPhone) {
  return ref.watch(firestoreServiceProvider).getLinkedStudents(parentPhone);
});

/// Provider for leave requests for a specific student
final studentLeaveRequestsProvider = StreamProvider.family<List<LeaveRequest>, String>((ref, studentId) {
  return ref.watch(firestoreServiceProvider).studentLeaveRequestsStream(studentId);
});

/// Provider for leave requests for a batch (for teachers)
final batchLeaveRequestsProvider = StreamProvider.family<List<LeaveRequest>, String>((ref, batchId) {
  return ref.watch(firestoreServiceProvider).batchLeaveRequestsStream(batchId);
});

/// Provider for pending leave requests by batch (with status filter)
final batchPendingLeaveRequestsProvider = StreamProvider.family<List<LeaveRequest>, String>((ref, batchId) {
  return ref
      .watch(firestoreServiceProvider)
      .batchLeaveRequestsStream(batchId, status: LeaveRequestStatus.pending);
});

/// Provider for pending leave requests (for teachers)
final pendingLeaveRequestsProvider = FutureProvider.family<List<LeaveRequest>, String>((ref, instituteId) {
  return ref.watch(firestoreServiceProvider).getPendingLeaveRequests(instituteId);
});

/// Provider for announcements stream
final announcementsProvider = StreamProvider.family<List<Announcement>, String>((ref, instituteId) {
  return ref.watch(firestoreServiceProvider).announcementsStream(instituteId);
});

/// Provider for active announcements (for parents)
final activeAnnouncementsProvider = FutureProvider.family<List<Announcement>, ({
  String instituteId,
  String? batchId,
})>((ref, params) {
  return ref
      .watch(firestoreServiceProvider)
      .getActiveAnnouncements(params.instituteId, batchId: params.batchId);
});

/// Provider for parent dashboard data
final parentDashboardProvider = FutureProvider.family<ParentDashboardData, String>((ref, parentPhone) {
  return ref.watch(firestoreServiceProvider).getParentDashboard(parentPhone);
});

/// Provider for child summary
final childSummaryProvider = FutureProvider.family<ChildSummary, ({
  String instituteId,
  String studentId,
  String batchId,
})>((ref, params) {
  return ref.watch(firestoreServiceProvider).getChildSummary(
        params.instituteId,
        params.studentId,
        params.batchId,
      );
});

/// State notifier for managing parent authentication
class ParentAuthNotifier extends StateNotifier<AsyncValue<Parent?>> {
  final FirestoreService _firestoreService;

  ParentAuthNotifier(this._firestoreService) : super(const AsyncValue.data(null));

  /// Attempt to log in parent with phone number
  Future<Parent?> loginWithPhone(String phone) async {
    state = const AsyncValue.loading();
    try {
      final parent = await _firestoreService.getParentByPhone(phone);
      state = AsyncValue.data(parent);
      return parent;
    } on Exception catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  /// Update FCM token for push notifications
  Future<void> updateFcmToken(String parentId, String token) async {
    try {
      await _firestoreService.updateParent(parentId, {'fcmToken': token});
    } on Exception {
      // Silently fail - FCM token update is not critical
    }
  }

  /// Update last login time
  Future<void> updateLastLogin(String parentId) async {
    try {
      await _firestoreService.updateParent(parentId, {
        'lastLoginAt': DateTime.now(),
      });
    } on Exception {
      // Silently fail
    }
  }

  /// Log out
  void logout() {
    state = const AsyncValue.data(null);
  }
}

/// Provider for parent auth state
final parentAuthProvider = StateNotifierProvider<ParentAuthNotifier, AsyncValue<Parent?>>(
  (ref) => ParentAuthNotifier(ref.watch(firestoreServiceProvider)),
);

/// Provider for leave request creation
class LeaveRequestNotifier extends StateNotifier<AsyncValue<void>> {
  final FirestoreService _firestoreService;

  LeaveRequestNotifier(this._firestoreService) : super(const AsyncValue.data(null));

  /// Create a new leave request
  Future<bool> createLeaveRequest({
    required String studentId,
    required String parentId,
    required String batchId,
    required String instituteId,
    required LeaveType type,
    required String reason,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    state = const AsyncValue.loading();
    try {
      final request = LeaveRequest(
        id: '',
        studentId: studentId,
        parentId: parentId,
        batchId: batchId,
        instituteId: instituteId,
        type: type,
        reason: reason,
        startDate: startDate,
        endDate: endDate,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _firestoreService.createLeaveRequest(request);
      state = const AsyncValue.data(null);
      return true;
    } on Exception catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Cancel a leave request
  Future<bool> cancelLeaveRequest(String requestId) async {
    state = const AsyncValue.loading();
    try {
      await _firestoreService.cancelLeaveRequest(requestId);
      state = const AsyncValue.data(null);
      return true;
    } on Exception catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

/// Provider for leave request operations
final leaveRequestNotifierProvider = StateNotifierProvider<LeaveRequestNotifier, AsyncValue<void>>(
  (ref) => LeaveRequestNotifier(ref.watch(firestoreServiceProvider)),
);

/// Provider for announcement operations (for teachers)
class AnnouncementNotifier extends StateNotifier<AsyncValue<void>> {
  final FirestoreService _firestoreService;

  AnnouncementNotifier(this._firestoreService) : super(const AsyncValue.data(null));

  /// Create a new announcement
  Future<bool> createAnnouncement({
    required String instituteId,
    required String title,
    required String content,
    required String createdBy,
    AnnouncementPriority priority = AnnouncementPriority.normal,
    List<String>? targetBatchIds,
    DateTime? expiresAt,
    bool publish = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      final announcement = Announcement(
        id: '',
        instituteId: instituteId,
        title: title,
        content: content,
        priority: priority,
        targetBatchIds: targetBatchIds,
        createdBy: createdBy,
        isPublished: publish,
        publishedAt: publish ? DateTime.now() : null,
        expiresAt: expiresAt,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _firestoreService.createAnnouncement(announcement);
      state = const AsyncValue.data(null);
      return true;
    } on Exception catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Update an announcement
  Future<bool> updateAnnouncement(String announcementId, Map<String, dynamic> updates) async {
    state = const AsyncValue.loading();
    try {
      await _firestoreService.updateAnnouncement(announcementId, updates);
      state = const AsyncValue.data(null);
      return true;
    } on Exception catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Publish an announcement
  Future<bool> publishAnnouncement(String announcementId) async {
    state = const AsyncValue.loading();
    try {
      await _firestoreService.publishAnnouncement(announcementId);
      state = const AsyncValue.data(null);
      return true;
    } on Exception catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Delete an announcement
  Future<bool> deleteAnnouncement(String announcementId) async {
    state = const AsyncValue.loading();
    try {
      await _firestoreService.deleteAnnouncement(announcementId);
      state = const AsyncValue.data(null);
      return true;
    } on Exception catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

/// Provider for announcement operations
final announcementNotifierProvider = StateNotifierProvider<AnnouncementNotifier, AsyncValue<void>>(
  (ref) => AnnouncementNotifier(ref.watch(firestoreServiceProvider)),
);

/// Provider for leave request review (for teachers)
class LeaveReviewNotifier extends StateNotifier<AsyncValue<void>> {
  final FirestoreService _firestoreService;

  LeaveReviewNotifier(this._firestoreService) : super(const AsyncValue.data(null));

  /// Approve a leave request
  Future<bool> approveLeaveRequest({
    required String requestId,
    required String reviewerId,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _firestoreService.reviewLeaveRequest(
        requestId,
        status: LeaveRequestStatus.approved,
        reviewedBy: reviewerId,
        reviewNotes: notes,
      );
      state = const AsyncValue.data(null);
      return true;
    } on Exception catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  /// Reject a leave request
  Future<bool> rejectLeaveRequest({
    required String requestId,
    required String reviewerId,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _firestoreService.reviewLeaveRequest(
        requestId,
        status: LeaveRequestStatus.rejected,
        reviewedBy: reviewerId,
        reviewNotes: notes,
      );
      state = const AsyncValue.data(null);
      return true;
    } on Exception catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

/// Provider for leave review operations
final leaveReviewNotifierProvider = StateNotifierProvider<LeaveReviewNotifier, AsyncValue<void>>(
  (ref) => LeaveReviewNotifier(ref.watch(firestoreServiceProvider)),
);
