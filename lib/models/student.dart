import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/helpers.dart';

class Student {
  final String id;
  final String batchId;
  final String name;
  final String parentPhone;
  final String? studentId; // Roll number or external ID
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Student({
    required this.id,
    required this.batchId,
    required this.name,
    required this.parentPhone,
    this.studentId,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Student.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Student(
      id: doc.id,
      batchId: (data['batchId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      parentPhone: (data['parentPhone'] as String?) ?? '',
      studentId: data['studentId'] as String?,
      isActive: (data['isActive'] as bool?) ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'batchId': batchId,
      'name': name,
      'parentPhone': parentPhone,
      'studentId': studentId,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Student copyWith({
    String? id,
    String? batchId,
    String? name,
    String? parentPhone,
    String? studentId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Student(
      id: id ?? this.id,
      batchId: batchId ?? this.batchId,
      name: name ?? this.name,
      parentPhone: parentPhone ?? this.parentPhone,
      studentId: studentId ?? this.studentId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Validates Indian mobile phone number (10 digits starting with 6-9)
  static bool isValidIndianPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length == 10) {
      return RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned);
    }
    if (cleaned.length == 12 && cleaned.startsWith('91')) {
      return RegExp(r'^91[6-9]\d{9}$').hasMatch(cleaned);
    }
    return false;
  }

  /// Returns formatted phone number with +91 prefix (delegates to PhoneHelpers)
  String get formattedPhone => PhoneHelpers.formatWithCountryCode(parentPhone);
}
