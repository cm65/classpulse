import 'package:cloud_firestore/cloud_firestore.dart';

enum TeacherRole {
  admin,
  teacher;

  String get displayName {
    switch (this) {
      case TeacherRole.admin:
        return 'Admin';
      case TeacherRole.teacher:
        return 'Teacher';
    }
  }

  static TeacherRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'admin':
        return TeacherRole.admin;
      default:
        return TeacherRole.teacher;
    }
  }

  /// Check if role has admin privileges
  bool get isAdmin => this == TeacherRole.admin;
}

class Teacher {
  final String id; // Firebase Auth UID
  final String instituteId;
  final String name;
  final String phone;
  final TeacherRole role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  Teacher({
    required this.id,
    required this.instituteId,
    required this.name,
    required this.phone,
    this.role = TeacherRole.teacher,
    this.isActive = true,
    required this.createdAt,
    this.lastLoginAt,
  });

  factory Teacher.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Teacher(
      id: doc.id,
      instituteId: (data['instituteId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      role: TeacherRole.fromString((data['role'] as String?) ?? 'teacher'),
      isActive: (data['isActive'] as bool?) ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'instituteId': instituteId,
      'name': name,
      'phone': phone,
      'role': role.name,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
    };
  }

  Teacher copyWith({
    String? id,
    String? instituteId,
    String? name,
    String? phone,
    TeacherRole? role,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return Teacher(
      id: id ?? this.id,
      instituteId: instituteId ?? this.instituteId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  /// Check if teacher can perform admin actions
  bool get canManageInstitute => role.isAdmin;

  /// Check if teacher can manage teachers
  bool get canManageTeachers => role.isAdmin;

  /// Check if teacher can view audit logs
  bool get canViewAuditLogs => role.isAdmin;

  /// Check if teacher can configure settings
  bool get canConfigureSettings => role.isAdmin;
}

/// Pending teacher invitation
class TeacherInvitation {
  final String id;
  final String instituteId;
  final String instituteName;
  final String phone;
  final TeacherRole role;
  final String invitedBy;
  final DateTime invitedAt;
  final DateTime expiresAt;
  final bool isAccepted;

  TeacherInvitation({
    required this.id,
    required this.instituteId,
    required this.instituteName,
    required this.phone,
    this.role = TeacherRole.teacher,
    required this.invitedBy,
    required this.invitedAt,
    required this.expiresAt,
    this.isAccepted = false,
  });

  factory TeacherInvitation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TeacherInvitation(
      id: doc.id,
      instituteId: (data['instituteId'] as String?) ?? '',
      instituteName: (data['instituteName'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      role: TeacherRole.fromString((data['role'] as String?) ?? 'teacher'),
      invitedBy: (data['invitedBy'] as String?) ?? '',
      invitedAt: (data['invitedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(days: 7)),
      isAccepted: (data['isAccepted'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'instituteId': instituteId,
      'instituteName': instituteName,
      'phone': phone,
      'role': role.name,
      'invitedBy': invitedBy,
      'invitedAt': Timestamp.fromDate(invitedAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isAccepted': isAccepted,
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !isExpired && !isAccepted;
}
