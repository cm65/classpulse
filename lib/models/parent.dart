import 'package:cloud_firestore/cloud_firestore.dart';

/// Parent account status
enum ParentStatus {
  pending,   // Invited but not yet verified
  active,    // Verified and active
  inactive;  // Deactivated

  String get displayName {
    switch (this) {
      case ParentStatus.pending:
        return 'Pending';
      case ParentStatus.active:
        return 'Active';
      case ParentStatus.inactive:
        return 'Inactive';
    }
  }
}

/// Leave request status
enum LeaveRequestStatus {
  pending,
  approved,
  rejected,
  cancelled;

  String get displayName {
    switch (this) {
      case LeaveRequestStatus.pending:
        return 'Pending';
      case LeaveRequestStatus.approved:
        return 'Approved';
      case LeaveRequestStatus.rejected:
        return 'Rejected';
      case LeaveRequestStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Leave request type
enum LeaveType {
  sick,
  family,
  travel,
  exam,
  other;

  String get displayName {
    switch (this) {
      case LeaveType.sick:
        return 'Sick Leave';
      case LeaveType.family:
        return 'Family Emergency';
      case LeaveType.travel:
        return 'Travel';
      case LeaveType.exam:
        return 'School Exam';
      case LeaveType.other:
        return 'Other';
    }
  }
}

/// Announcement priority
enum AnnouncementPriority {
  low,
  normal,
  high,
  urgent;

  String get displayName {
    switch (this) {
      case AnnouncementPriority.low:
        return 'Low';
      case AnnouncementPriority.normal:
        return 'Normal';
      case AnnouncementPriority.high:
        return 'High';
      case AnnouncementPriority.urgent:
        return 'Urgent';
    }
  }
}

/// Parent account model
class Parent {
  final String id;
  final String instituteId;
  final String phone;
  final String name;
  final String? email;
  final List<String> studentIds; // Children linked to this parent
  final ParentStatus status;
  final String? fcmToken; // For push notifications
  final DateTime? lastLoginAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Parent({
    required this.id,
    required this.instituteId,
    required this.phone,
    required this.name,
    this.email,
    this.studentIds = const [],
    this.status = ParentStatus.pending,
    this.fcmToken,
    this.lastLoginAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Parent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Parent(
      id: doc.id,
      instituteId: (data['instituteId'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      email: data['email'] as String?,
      studentIds: (data['studentIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      status: ParentStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => ParentStatus.pending,
      ),
      fcmToken: data['fcmToken'] as String?,
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'instituteId': instituteId,
      'phone': phone,
      'name': name,
      'email': email,
      'studentIds': studentIds,
      'status': status.name,
      'fcmToken': fcmToken,
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Parent copyWith({
    String? id,
    String? instituteId,
    String? phone,
    String? name,
    String? email,
    List<String>? studentIds,
    ParentStatus? status,
    String? fcmToken,
    DateTime? lastLoginAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Parent(
      id: id ?? this.id,
      instituteId: instituteId ?? this.instituteId,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      email: email ?? this.email,
      studentIds: studentIds ?? this.studentIds,
      status: status ?? this.status,
      fcmToken: fcmToken ?? this.fcmToken,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isActive => status == ParentStatus.active;
  bool get hasChildren => studentIds.isNotEmpty;
}

/// Link between parent phone and student (for quick lookup)
class ParentStudentLink {
  final String id;
  final String parentPhone;
  final String studentId;
  final String studentName;
  final String batchId;
  final String batchName;
  final String instituteId;
  final DateTime createdAt;

  ParentStudentLink({
    required this.id,
    required this.parentPhone,
    required this.studentId,
    required this.studentName,
    required this.batchId,
    required this.batchName,
    required this.instituteId,
    required this.createdAt,
  });

  factory ParentStudentLink.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ParentStudentLink(
      id: doc.id,
      parentPhone: (data['parentPhone'] as String?) ?? '',
      studentId: (data['studentId'] as String?) ?? '',
      studentName: (data['studentName'] as String?) ?? '',
      batchId: (data['batchId'] as String?) ?? '',
      batchName: (data['batchName'] as String?) ?? '',
      instituteId: (data['instituteId'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'parentPhone': parentPhone,
      'studentId': studentId,
      'studentName': studentName,
      'batchId': batchId,
      'batchName': batchName,
      'instituteId': instituteId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Leave request from parent
class LeaveRequest {
  final String id;
  final String studentId;
  final String parentId;
  final String batchId;
  final String instituteId;
  final LeaveType type;
  final String reason;
  final DateTime startDate;
  final DateTime endDate;
  final LeaveRequestStatus status;
  final String? reviewedBy; // Teacher ID
  final String? reviewNotes;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  LeaveRequest({
    required this.id,
    required this.studentId,
    required this.parentId,
    required this.batchId,
    required this.instituteId,
    required this.type,
    required this.reason,
    required this.startDate,
    required this.endDate,
    this.status = LeaveRequestStatus.pending,
    this.reviewedBy,
    this.reviewNotes,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LeaveRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LeaveRequest(
      id: doc.id,
      studentId: (data['studentId'] as String?) ?? '',
      parentId: (data['parentId'] as String?) ?? '',
      batchId: (data['batchId'] as String?) ?? '',
      instituteId: (data['instituteId'] as String?) ?? '',
      type: LeaveType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => LeaveType.other,
      ),
      reason: (data['reason'] as String?) ?? '',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: LeaveRequestStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => LeaveRequestStatus.pending,
      ),
      reviewedBy: data['reviewedBy'] as String?,
      reviewNotes: data['reviewNotes'] as String?,
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'parentId': parentId,
      'batchId': batchId,
      'instituteId': instituteId,
      'type': type.name,
      'reason': reason,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': status.name,
      'reviewedBy': reviewedBy,
      'reviewNotes': reviewNotes,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  LeaveRequest copyWith({
    String? id,
    String? studentId,
    String? parentId,
    String? batchId,
    String? instituteId,
    LeaveType? type,
    String? reason,
    DateTime? startDate,
    DateTime? endDate,
    LeaveRequestStatus? status,
    String? reviewedBy,
    String? reviewNotes,
    DateTime? reviewedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LeaveRequest(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      parentId: parentId ?? this.parentId,
      batchId: batchId ?? this.batchId,
      instituteId: instituteId ?? this.instituteId,
      type: type ?? this.type,
      reason: reason ?? this.reason,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Number of days for leave
  int get durationDays => endDate.difference(startDate).inDays + 1;

  /// Check if leave is for a single day
  bool get isSingleDay => startDate.year == endDate.year &&
      startDate.month == endDate.month &&
      startDate.day == endDate.day;

  /// Check if pending
  bool get isPending => status == LeaveRequestStatus.pending;

  /// Check if approved
  bool get isApproved => status == LeaveRequestStatus.approved;
}

/// Institute announcement
class Announcement {
  final String id;
  final String instituteId;
  final String title;
  final String content;
  final AnnouncementPriority priority;
  final List<String>? targetBatchIds; // null = all batches
  final String createdBy; // Teacher ID
  final bool isPublished;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final int viewCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Announcement({
    required this.id,
    required this.instituteId,
    required this.title,
    required this.content,
    this.priority = AnnouncementPriority.normal,
    this.targetBatchIds,
    required this.createdBy,
    this.isPublished = false,
    this.publishedAt,
    this.expiresAt,
    this.viewCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Announcement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Announcement(
      id: doc.id,
      instituteId: (data['instituteId'] as String?) ?? '',
      title: (data['title'] as String?) ?? '',
      content: (data['content'] as String?) ?? '',
      priority: AnnouncementPriority.values.firstWhere(
        (p) => p.name == data['priority'],
        orElse: () => AnnouncementPriority.normal,
      ),
      targetBatchIds: (data['targetBatchIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      createdBy: (data['createdBy'] as String?) ?? '',
      isPublished: (data['isPublished'] as bool?) ?? false,
      publishedAt: (data['publishedAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      viewCount: (data['viewCount'] as int?) ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'instituteId': instituteId,
      'title': title,
      'content': content,
      'priority': priority.name,
      'targetBatchIds': targetBatchIds,
      'createdBy': createdBy,
      'isPublished': isPublished,
      'publishedAt': publishedAt != null ? Timestamp.fromDate(publishedAt!) : null,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'viewCount': viewCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Announcement copyWith({
    String? id,
    String? instituteId,
    String? title,
    String? content,
    AnnouncementPriority? priority,
    List<String>? targetBatchIds,
    String? createdBy,
    bool? isPublished,
    DateTime? publishedAt,
    DateTime? expiresAt,
    int? viewCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Announcement(
      id: id ?? this.id,
      instituteId: instituteId ?? this.instituteId,
      title: title ?? this.title,
      content: content ?? this.content,
      priority: priority ?? this.priority,
      targetBatchIds: targetBatchIds ?? this.targetBatchIds,
      createdBy: createdBy ?? this.createdBy,
      isPublished: isPublished ?? this.isPublished,
      publishedAt: publishedAt ?? this.publishedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      viewCount: viewCount ?? this.viewCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if announcement is active (published and not expired)
  bool get isActive {
    if (!isPublished) return false;
    if (expiresAt != null && expiresAt!.isBefore(DateTime.now())) return false;
    return true;
  }

  /// Check if announcement targets a specific batch
  bool targetsBatch(String batchId) {
    if (targetBatchIds == null) return true; // All batches
    return targetBatchIds!.contains(batchId);
  }

  /// Check if urgent
  bool get isUrgent => priority == AnnouncementPriority.urgent;
}

/// Summary of a child for parent dashboard
class ChildSummary {
  final String studentId;
  final String studentName;
  final String batchId;
  final String batchName;
  final double attendancePercentage;
  final int presentDays;
  final int absentDays;
  final int lateDays;
  final int totalClasses;
  final double? averagePerformance;
  final int? classRank;
  final double? pendingFees;
  final List<RecentAttendance> recentAttendance;

  ChildSummary({
    required this.studentId,
    required this.studentName,
    required this.batchId,
    required this.batchName,
    required this.attendancePercentage,
    required this.presentDays,
    required this.absentDays,
    required this.lateDays,
    required this.totalClasses,
    this.averagePerformance,
    this.classRank,
    this.pendingFees,
    this.recentAttendance = const [],
  });
}

/// Recent attendance entry for display
class RecentAttendance {
  final DateTime date;
  final String status; // present, absent, late, excused
  final String? remarks;

  RecentAttendance({
    required this.date,
    required this.status,
    this.remarks,
  });
}

/// Parent dashboard data
class ParentDashboardData {
  final Parent parent;
  final List<ChildSummary> children;
  final List<Announcement> announcements;
  final List<LeaveRequest> pendingLeaveRequests;
  final int unreadAnnouncementCount;

  ParentDashboardData({
    required this.parent,
    required this.children,
    required this.announcements,
    required this.pendingLeaveRequests,
    this.unreadAnnouncementCount = 0,
  });
}
