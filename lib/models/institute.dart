import 'package:cloud_firestore/cloud_firestore.dart';

class Institute {
  final String id;
  final String name;
  final String adminName;
  final String phone;
  final String email;
  final String? address;
  final String? logoUrl;
  final InstituteSettings settings;
  final DateTime createdAt;
  final DateTime updatedAt;

  Institute({
    required this.id,
    required this.name,
    required this.adminName,
    required this.phone,
    required this.email,
    this.address,
    this.logoUrl,
    required this.settings,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Institute.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Institute(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      adminName: (data['adminName'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      address: data['address'] as String?,
      logoUrl: data['logoUrl'] as String?,
      settings: InstituteSettings.fromMap((data['settings'] as Map<String, dynamic>?) ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'adminName': adminName,
      'phone': phone,
      'email': email,
      'address': address,
      'logoUrl': logoUrl,
      'settings': settings.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Institute copyWith({
    String? id,
    String? name,
    String? adminName,
    String? phone,
    String? email,
    String? address,
    String? logoUrl,
    InstituteSettings? settings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Institute(
      id: id ?? this.id,
      name: name ?? this.name,
      adminName: adminName ?? this.adminName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      logoUrl: logoUrl ?? this.logoUrl,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class InstituteSettings {
  final Duration attendanceEditWindow;
  final String defaultLanguage;
  final NotificationTemplates notificationTemplates;

  InstituteSettings({
    this.attendanceEditWindow = const Duration(hours: 2),
    this.defaultLanguage = 'en',
    NotificationTemplates? notificationTemplates,
  }) : notificationTemplates = notificationTemplates ?? NotificationTemplates();

  factory InstituteSettings.fromMap(Map<String, dynamic> map) {
    return InstituteSettings(
      attendanceEditWindow: Duration(minutes: (map['attendanceEditWindowMinutes'] as int?) ?? 120),
      defaultLanguage: (map['defaultLanguage'] as String?) ?? 'en',
      notificationTemplates: NotificationTemplates.fromMap((map['notificationTemplates'] as Map<String, dynamic>?) ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'attendanceEditWindowMinutes': attendanceEditWindow.inMinutes,
      'defaultLanguage': defaultLanguage,
      'notificationTemplates': notificationTemplates.toMap(),
    };
  }
}

class NotificationTemplates {
  final String presentTemplate;
  final String absentTemplate;
  final String lateTemplate;
  final String smsTemplate;

  NotificationTemplates({
    this.presentTemplate = '{student} attended {batch} on {date} at {time}. Thank you!',
    this.absentTemplate = '{student} was ABSENT from {batch} on {date}. Please contact the institute if this is unexpected.',
    this.lateTemplate = '{student} was LATE to {batch} on {date}. Arrived at {time}.',
    this.smsTemplate = '{institute}: {student} was {status} for {batch} on {date}.',
  });

  factory NotificationTemplates.fromMap(Map<String, dynamic> map) {
    return NotificationTemplates(
      presentTemplate: (map['presentTemplate'] as String?) ?? '{student} attended {batch} on {date} at {time}. Thank you!',
      absentTemplate: (map['absentTemplate'] as String?) ?? '{student} was ABSENT from {batch} on {date}. Please contact the institute if this is unexpected.',
      lateTemplate: (map['lateTemplate'] as String?) ?? '{student} was LATE to {batch} on {date}. Arrived at {time}.',
      smsTemplate: (map['smsTemplate'] as String?) ?? '{institute}: {student} was {status} for {batch} on {date}.',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'presentTemplate': presentTemplate,
      'absentTemplate': absentTemplate,
      'lateTemplate': lateTemplate,
      'smsTemplate': smsTemplate,
    };
  }
}
