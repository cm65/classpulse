import 'package:cloud_firestore/cloud_firestore.dart';

enum AuditAction {
  attendanceMark,
  attendanceSubmit,
  attendanceEdit,
  studentAdd,
  studentEdit,
  studentDelete,
  batchCreate,
  batchEdit,
  batchDelete,
  teacherInvite,
  teacherRemove,
  settingsChange,
  login,
  logout;

  String get displayName {
    switch (this) {
      case AuditAction.attendanceMark:
        return 'Marked Attendance';
      case AuditAction.attendanceSubmit:
        return 'Submitted Attendance';
      case AuditAction.attendanceEdit:
        return 'Edited Attendance';
      case AuditAction.studentAdd:
        return 'Added Student';
      case AuditAction.studentEdit:
        return 'Edited Student';
      case AuditAction.studentDelete:
        return 'Removed Student';
      case AuditAction.batchCreate:
        return 'Created Batch';
      case AuditAction.batchEdit:
        return 'Edited Batch';
      case AuditAction.batchDelete:
        return 'Deleted Batch';
      case AuditAction.teacherInvite:
        return 'Invited Teacher';
      case AuditAction.teacherRemove:
        return 'Removed Teacher';
      case AuditAction.settingsChange:
        return 'Changed Settings';
      case AuditAction.login:
        return 'Logged In';
      case AuditAction.logout:
        return 'Logged Out';
    }
  }

  static AuditAction fromString(String value) {
    switch (value) {
      case 'attendanceMark':
        return AuditAction.attendanceMark;
      case 'attendanceSubmit':
        return AuditAction.attendanceSubmit;
      case 'attendanceEdit':
        return AuditAction.attendanceEdit;
      case 'studentAdd':
        return AuditAction.studentAdd;
      case 'studentEdit':
        return AuditAction.studentEdit;
      case 'studentDelete':
        return AuditAction.studentDelete;
      case 'batchCreate':
        return AuditAction.batchCreate;
      case 'batchEdit':
        return AuditAction.batchEdit;
      case 'batchDelete':
        return AuditAction.batchDelete;
      case 'teacherInvite':
        return AuditAction.teacherInvite;
      case 'teacherRemove':
        return AuditAction.teacherRemove;
      case 'settingsChange':
        return AuditAction.settingsChange;
      case 'login':
        return AuditAction.login;
      case 'logout':
        return AuditAction.logout;
      default:
        return AuditAction.attendanceMark;
    }
  }
}

class AuditLog {
  final String id;
  final String instituteId;
  final String userId;
  final String userName;
  final AuditAction action;
  final DateTime timestamp;
  final Map<String, dynamic>? oldValue;
  final Map<String, dynamic>? newValue;
  final Map<String, dynamic>? metadata;

  AuditLog({
    required this.id,
    required this.instituteId,
    required this.userId,
    required this.userName,
    required this.action,
    required this.timestamp,
    this.oldValue,
    this.newValue,
    this.metadata,
  });

  factory AuditLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AuditLog(
      id: doc.id,
      instituteId: (data['instituteId'] as String?) ?? '',
      userId: (data['userId'] as String?) ?? '',
      userName: (data['userName'] as String?) ?? '',
      action: AuditAction.fromString((data['action'] as String?) ?? ''),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      oldValue: data['oldValue'] as Map<String, dynamic>?,
      newValue: data['newValue'] as Map<String, dynamic>?,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'instituteId': instituteId,
      'userId': userId,
      'userName': userName,
      'action': action.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'oldValue': oldValue,
      'newValue': newValue,
      'metadata': metadata,
    };
  }

  /// Create a new audit log entry
  static AuditLog create({
    required String instituteId,
    required String userId,
    required String userName,
    required AuditAction action,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
    Map<String, dynamic>? metadata,
  }) {
    return AuditLog(
      id: '', // Will be set by Firestore
      instituteId: instituteId,
      userId: userId,
      userName: userName,
      action: action,
      timestamp: DateTime.now(),
      oldValue: oldValue,
      newValue: newValue,
      metadata: metadata,
    );
  }

  /// Format changes for display
  String get changeDescription {
    if (oldValue == null && newValue == null) {
      return action.displayName;
    }

    final changes = <String>[];

    if (newValue != null) {
      for (final key in newValue!.keys) {
        final newVal = newValue![key];
        final oldVal = oldValue?[key];

        if (oldVal != newVal) {
          if (oldVal != null) {
            changes.add('$key: $oldVal -> $newVal');
          } else {
            changes.add('$key: $newVal');
          }
        }
      }
    }

    return changes.isEmpty ? action.displayName : changes.join(', ');
  }
}
