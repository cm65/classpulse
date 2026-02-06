import 'package:cloud_firestore/cloud_firestore.dart';

class Batch {
  final String id;
  final String instituteId;
  final String name;
  final String? subject;
  final List<String> scheduleDays; // ['monday', 'wednesday', 'friday']
  final ScheduleTime startTime;
  final ScheduleTime endTime;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Batch({
    required this.id,
    required this.instituteId,
    required this.name,
    this.subject,
    required this.scheduleDays,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Batch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Batch(
      id: doc.id,
      instituteId: (data['instituteId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      subject: data['subject'] as String?,
      scheduleDays: List<String>.from((data['scheduleDays'] as List<dynamic>?) ?? []),
      startTime: ScheduleTime.fromMap((data['startTime'] as Map<String, dynamic>?) ?? {'hour': 9, 'minute': 0}),
      endTime: ScheduleTime.fromMap((data['endTime'] as Map<String, dynamic>?) ?? {'hour': 10, 'minute': 0}),
      isActive: (data['isActive'] as bool?) ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'instituteId': instituteId,
      'name': name,
      'subject': subject,
      'scheduleDays': scheduleDays,
      'startTime': startTime.toMap(),
      'endTime': endTime.toMap(),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Batch copyWith({
    String? id,
    String? instituteId,
    String? name,
    String? subject,
    List<String>? scheduleDays,
    ScheduleTime? startTime,
    ScheduleTime? endTime,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Batch(
      id: id ?? this.id,
      instituteId: instituteId ?? this.instituteId,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      scheduleDays: scheduleDays ?? this.scheduleDays,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get formattedSchedule {
    if (scheduleDays.isEmpty) return 'No schedule set';
    final days = scheduleDays.map((d) => d.substring(0, 3).toUpperCase()).join(', ');
    return '$days ${startTime.format24h()} - ${endTime.format24h()}';
  }
}

/// Custom time class to avoid conflict with Flutter's TimeOfDay
class ScheduleTime {
  final int hour;
  final int minute;

  const ScheduleTime({required this.hour, required this.minute});

  factory ScheduleTime.fromMap(Map<String, dynamic> map) {
    return ScheduleTime(
      hour: (map['hour'] as int?) ?? 0,
      minute: (map['minute'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hour': hour,
      'minute': minute,
    };
  }

  String format24h() {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String format12h() {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour >= 12 ? 'PM' : 'AM';
    return '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }
}
