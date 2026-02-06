import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus {
  unmarked,
  present,
  absent,
  late;

  String get displayName {
    switch (this) {
      case AttendanceStatus.unmarked:
        return 'Unmarked';
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.late:
        return 'Late';
    }
  }

  String get emoji {
    switch (this) {
      case AttendanceStatus.unmarked:
        return '';
      case AttendanceStatus.present:
        return '';
      case AttendanceStatus.absent:
        return '';
      case AttendanceStatus.late:
        return '';
    }
  }

  static AttendanceStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'present':
        return AttendanceStatus.present;
      case 'absent':
        return AttendanceStatus.absent;
      case 'late':
        return AttendanceStatus.late;
      default:
        return AttendanceStatus.unmarked;
    }
  }

  /// Cycle to next status: unmarked -> present -> absent -> late -> unmarked
  AttendanceStatus next() {
    switch (this) {
      case AttendanceStatus.unmarked:
        return AttendanceStatus.present;
      case AttendanceStatus.present:
        return AttendanceStatus.absent;
      case AttendanceStatus.absent:
        return AttendanceStatus.late;
      case AttendanceStatus.late:
        return AttendanceStatus.unmarked;
    }
  }
}

enum NotificationStatus {
  pending,
  sent,
  delivered,
  read,
  failed;

  static NotificationStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'sent':
        return NotificationStatus.sent;
      case 'delivered':
        return NotificationStatus.delivered;
      case 'read':
        return NotificationStatus.read;
      case 'failed':
        return NotificationStatus.failed;
      default:
        return NotificationStatus.pending;
    }
  }
}

enum NotificationChannel {
  whatsapp,
  sms,
  none;

  static NotificationChannel fromString(String value) {
    switch (value.toLowerCase()) {
      case 'whatsapp':
        return NotificationChannel.whatsapp;
      case 'sms':
        return NotificationChannel.sms;
      default:
        return NotificationChannel.none;
    }
  }
}

/// Represents a single day's attendance record for a batch
class AttendanceRecord {
  final String id;
  final String instituteId;
  final String batchId;
  final DateTime date;
  final String submittedBy; // Teacher user ID
  final DateTime submittedAt;
  final DateTime? lastEditedAt;
  final String? lastEditedBy;
  final bool isSynced;

  AttendanceRecord({
    required this.id,
    required this.instituteId,
    required this.batchId,
    required this.date,
    required this.submittedBy,
    required this.submittedAt,
    this.lastEditedAt,
    this.lastEditedBy,
    this.isSynced = true,
  });

  factory AttendanceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceRecord(
      id: doc.id,
      instituteId: (data['instituteId'] as String?) ?? '',
      batchId: (data['batchId'] as String?) ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      submittedBy: (data['submittedBy'] as String?) ?? '',
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastEditedAt: (data['lastEditedAt'] as Timestamp?)?.toDate(),
      lastEditedBy: data['lastEditedBy'] as String?,
      isSynced: (data['isSynced'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'instituteId': instituteId,
      'batchId': batchId,
      'date': Timestamp.fromDate(date),
      'submittedBy': submittedBy,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'lastEditedAt': lastEditedAt != null ? Timestamp.fromDate(lastEditedAt!) : null,
      'lastEditedBy': lastEditedBy,
      'isSynced': isSynced,
    };
  }

  /// Check if attendance can still be edited based on time window
  bool canEdit(Duration editWindow) {
    final now = DateTime.now();
    final deadline = submittedAt.add(editWindow);
    return now.isBefore(deadline);
  }

  /// Get remaining edit time
  Duration remainingEditTime(Duration editWindow) {
    final now = DateTime.now();
    final deadline = submittedAt.add(editWindow);
    if (now.isAfter(deadline)) return Duration.zero;
    return deadline.difference(now);
  }
}

/// Individual student's attendance entry within an attendance record
class StudentAttendance {
  final String id;
  final String studentId;
  final String studentName;
  final String parentPhone;
  final AttendanceStatus status;
  final DateTime? markedAt;
  final NotificationStatus notificationStatus;
  final NotificationChannel notificationChannel;
  final String? notificationError;

  StudentAttendance({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.parentPhone,
    this.status = AttendanceStatus.unmarked,
    this.markedAt,
    this.notificationStatus = NotificationStatus.pending,
    this.notificationChannel = NotificationChannel.none,
    this.notificationError,
  });

  factory StudentAttendance.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentAttendance(
      id: doc.id,
      studentId: (data['studentId'] as String?) ?? '',
      studentName: (data['studentName'] as String?) ?? '',
      parentPhone: (data['parentPhone'] as String?) ?? '',
      status: AttendanceStatus.fromString((data['status'] as String?) ?? 'unmarked'),
      markedAt: (data['markedAt'] as Timestamp?)?.toDate(),
      notificationStatus: NotificationStatus.fromString((data['notificationStatus'] as String?) ?? 'pending'),
      notificationChannel: NotificationChannel.fromString((data['notificationChannel'] as String?) ?? 'none'),
      notificationError: data['notificationError'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'parentPhone': parentPhone,
      'status': status.name,
      'markedAt': markedAt != null ? Timestamp.fromDate(markedAt!) : null,
      'notificationStatus': notificationStatus.name,
      'notificationChannel': notificationChannel.name,
      'notificationError': notificationError,
    };
  }

  StudentAttendance copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? parentPhone,
    AttendanceStatus? status,
    DateTime? markedAt,
    NotificationStatus? notificationStatus,
    NotificationChannel? notificationChannel,
    String? notificationError,
  }) {
    return StudentAttendance(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      parentPhone: parentPhone ?? this.parentPhone,
      status: status ?? this.status,
      markedAt: markedAt ?? this.markedAt,
      notificationStatus: notificationStatus ?? this.notificationStatus,
      notificationChannel: notificationChannel ?? this.notificationChannel,
      notificationError: notificationError ?? this.notificationError,
    );
  }
}

/// Summary of attendance for quick dashboard display
class AttendanceSummary {
  final int totalStudents;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int unmarkedCount;

  AttendanceSummary({
    required this.totalStudents,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.unmarkedCount,
  });

  factory AttendanceSummary.fromEntries(List<StudentAttendance> entries) {
    return AttendanceSummary(
      totalStudents: entries.length,
      presentCount: entries.where((e) => e.status == AttendanceStatus.present).length,
      absentCount: entries.where((e) => e.status == AttendanceStatus.absent).length,
      lateCount: entries.where((e) => e.status == AttendanceStatus.late).length,
      unmarkedCount: entries.where((e) => e.status == AttendanceStatus.unmarked).length,
    );
  }

  double get attendancePercentage {
    if (totalStudents == 0) return 0;
    return ((presentCount + lateCount) / totalStudents) * 100;
  }

  bool get isComplete => unmarkedCount == 0;
}

/// Entry for student attendance history with date context
class StudentAttendanceHistoryEntry {
  final DateTime date;
  final AttendanceStatus status;
  final String batchId;

  StudentAttendanceHistoryEntry({
    required this.date,
    required this.status,
    required this.batchId,
  });

  /// Date key for calendar mapping (YYYY-MM-DD)
  String get dateKey => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// Student's monthly attendance summary for reports
class StudentMonthlyAttendance {
  final String studentId;
  final String studentName;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int totalDays;

  StudentMonthlyAttendance({
    required this.studentId,
    required this.studentName,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.totalDays,
  });

  double get attendancePercentage {
    if (totalDays == 0) return 0;
    return ((presentCount + lateCount) / totalDays) * 100;
  }
}
