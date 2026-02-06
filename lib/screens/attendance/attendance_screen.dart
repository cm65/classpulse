import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vibration/vibration.dart';

import '../../utils/theme.dart';
import '../../utils/design_tokens.dart';
import '../../utils/helpers.dart';
import '../../services/services.dart';
import '../../services/connectivity_service.dart';
import '../../models/models.dart';
import '../../widgets/common_widgets.dart';
import '../../providers/attendance_providers.dart';
import 'notification_status_screen.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  final Batch batch;
  final String instituteId;
  final DateTime? date;

  const AttendanceScreen({
    super.key,
    required this.batch,
    required this.instituteId,
    this.date,
  });

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  late DateTime _selectedDate;
  final Map<String, StudentAttendance> _attendanceMap = {};
  bool _isSubmitting = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.date ?? DateTime.now();
  }

  void _initAttendanceEntries(List<Student> students) {
    for (final student in students) {
      if (!_attendanceMap.containsKey(student.id)) {
        _attendanceMap[student.id] = StudentAttendance(
          id: student.id,
          studentId: student.id,
          studentName: student.name,
          parentPhone: student.parentPhone,
          status: AttendanceStatus.unmarked,
        );
      }
    }
  }

  void _toggleAttendance(String studentId) async {
    final current = _attendanceMap[studentId];
    if (current == null) return;

    // Haptic feedback
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 10);
    }

    setState(() {
      _attendanceMap[studentId] = current.copyWith(
        status: current.status.next(),
        markedAt: DateTime.now(),
      );
      _hasChanges = true;
    });
  }

  void _markAll(AttendanceStatus status) async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Mark All ${status.displayName}',
      message: 'Are you sure you want to mark all students as ${status.displayName.toLowerCase()}?',
    );

    if (!confirmed) return;

    setState(() {
      for (final key in _attendanceMap.keys) {
        _attendanceMap[key] = _attendanceMap[key]!.copyWith(
          status: status,
          markedAt: DateTime.now(),
        );
      }
      _hasChanges = true;
    });
  }

  Future<void> _submitAttendance() async {
    final entries = _attendanceMap.values.toList();
    final summary = AttendanceSummary.fromEntries(entries);

    // Check for unmarked students
    if (!summary.isComplete) {
      final markAsAbsent = await showConfirmationDialog(
        context: context,
        title: 'Unmarked Students',
        message: '${summary.unmarkedCount} student(s) are unmarked. Do you want to mark them as absent?',
        confirmText: 'Mark as Absent',
        cancelText: 'Go Back',
      );

      if (!markAsAbsent) return;

      // Mark unmarked as absent
      setState(() {
        for (final key in _attendanceMap.keys) {
          if (_attendanceMap[key]!.status == AttendanceStatus.unmarked) {
            _attendanceMap[key] = _attendanceMap[key]!.copyWith(
              status: AttendanceStatus.absent,
              markedAt: DateTime.now(),
            );
          }
        }
      });
    }

    // Confirm submission
    final updatedSummary = AttendanceSummary.fromEntries(_attendanceMap.values.toList());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Attendance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attendance Summary:'),
            const SizedBox(height: 12),
            _SummaryRow(
              icon: Icons.check_circle,
              color: AppColors.present,
              label: 'Present',
              count: updatedSummary.presentCount,
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              icon: Icons.cancel,
              color: AppColors.absent,
              label: 'Absent',
              count: updatedSummary.absentCount,
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              icon: Icons.access_time,
              color: AppColors.late,
              label: 'Late',
              count: updatedSummary.lateCount,
            ),
            const Divider(height: 24),
            Text(
              'Total: ${updatedSummary.totalStudents} students',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Parents will be notified immediately.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Submit attendance
    setState(() => _isSubmitting = true);

    try {
      final teacher = ref.read(currentTeacherProvider).value;
      if (teacher == null) throw Exception('Not logged in');

      final firestoreService = ref.read(firestoreServiceProvider);

      final attendanceId = await firestoreService.submitAttendance(
        instituteId: widget.instituteId,
        batchId: widget.batch.id,
        submittedBy: teacher.id,
        entries: _attendanceMap.values.toList(),
        date: _selectedDate,
      );

      // Add audit log
      await firestoreService.addAuditLog(AuditLog.create(
        instituteId: widget.instituteId,
        userId: teacher.id,
        userName: teacher.name,
        action: AuditAction.attendanceSubmit,
        metadata: {
          'batchId': widget.batch.id,
          'batchName': widget.batch.name,
          'date': _selectedDate.toIso8601String(),
          'presentCount': updatedSummary.presentCount,
          'absentCount': updatedSummary.absentCount,
          'lateCount': updatedSummary.lateCount,
        },
      ));

      if (mounted) {
        // Success haptic feedback - double vibration for confirmation
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(pattern: [0, 50, 100, 50]);
        }

        // Check if offline to show appropriate message
        final currentConnectivity = ref.read(connectivityProvider).value;
        final submittedOffline = currentConnectivity?.isOffline ?? false;
        final hasNotifications = updatedSummary.absentCount > 0 || updatedSummary.lateCount > 0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                if (submittedOffline) ...[
                  const Icon(Icons.cloud_upload, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Attendance saved! Will sync when online.'),
                  ),
                ] else ...[
                  const Expanded(
                    child: Text('Attendance submitted! Notifications are being sent.'),
                  ),
                ],
              ],
            ),
            backgroundColor: submittedOffline ? AppColors.warning : AppColors.success,
            duration: Duration(seconds: submittedOffline ? 4 : 3),
            action: (!submittedOffline && hasNotifications)
                ? SnackBarAction(
                    label: 'View Status',
                    textColor: Colors.white,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotificationStatusScreen(
                            instituteId: widget.instituteId,
                            attendanceId: attendanceId,
                            batchName: widget.batch.name,
                            date: _selectedDate,
                          ),
                        ),
                      );
                    },
                  )
                : null,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHelpers.getActionError('submit attendance', e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider((
      instituteId: widget.instituteId,
      batchId: widget.batch.id,
    )));
    final connectivity = ref.watch(connectivityProvider);
    final isOffline = connectivity.value?.isOffline ?? false;

    return WillPopScope(
      onWillPop: () async {
        if (_hasChanges) {
          final discard = await showConfirmationDialog(
            context: context,
            title: 'Discard Changes?',
            message: 'You have unsaved attendance marks. Are you sure you want to go back?',
            confirmText: 'Discard',
            isDangerous: true,
          );
          return discard;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.batch.name),
              Text(
                DateFormat('EEEE, MMMM d').format(_selectedDate),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            PopupMenuButton<AttendanceStatus>(
              icon: const Icon(Icons.checklist),
              tooltip: 'Mark All',
              onSelected: _markAll,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: AttendanceStatus.present,
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.present),
                      SizedBox(width: 8),
                      Text('Mark All Present'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: AttendanceStatus.absent,
                  child: Row(
                    children: [
                      Icon(Icons.cancel, color: AppColors.absent),
                      SizedBox(width: 8),
                      Text('Mark All Absent'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // Offline banner
            if (isOffline) const OfflineBanner(),

            // Main content
            Expanded(
              child: studentsAsync.when(
          data: (students) {
            if (students.isEmpty) {
              return EmptyStateWidget(
                icon: Icons.person_add_alt_1,
                title: 'No Students',
                subtitle: 'Add students to this batch to mark attendance',
                action: ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to add student
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Student'),
                ),
              );
            }

            _initAttendanceEntries(students);

            return Column(
              children: [
                // Quick summary bar
                _buildSummaryBar(),

                // Student list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final attendance = _attendanceMap[student.id]!;
                      return _StudentAttendanceCard(
                        student: student,
                        attendance: attendance,
                        onTap: () => _toggleAttendance(student.id),
                      );
                    },
                  ),
                ),
              ],
            );
          },
          loading: () => const ShimmerListLoading(type: ShimmerListType.student, itemCount: 5),
          error: (error, stack) => ErrorStateWidget(
            error: error,
            onRetry: () => ref.invalidate(studentsProvider((
              instituteId: widget.instituteId,
              batchId: widget.batch.id,
            ))),
          ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _attendanceMap.isNotEmpty
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LoadingButton(
                    isLoading: _isSubmitting,
                    onPressed: _submitAttendance,
                    child: const Text('Submit Attendance'),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildSummaryBar() {
    final summary = AttendanceSummary.fromEntries(_attendanceMap.values.toList());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(
            label: 'Present',
            count: summary.presentCount,
            color: AppColors.present,
          ),
          _SummaryItem(
            label: 'Absent',
            count: summary.absentCount,
            color: AppColors.absent,
          ),
          _SummaryItem(
            label: 'Late',
            count: summary.lateCount,
            color: AppColors.late,
          ),
          _SummaryItem(
            label: 'Unmarked',
            count: summary.unmarkedCount,
            color: AppColors.unmarked,
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int count;

  const _SummaryRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(label),
        const Spacer(),
        Text(
          count.toString(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _StudentAttendanceCard extends StatelessWidget {
  final Student student;
  final StudentAttendance attendance;
  final VoidCallback onTap;

  const _StudentAttendanceCard({
    required this.student,
    required this.attendance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = attendance.status;
    final color = status.name.attendanceColor;
    final bgColor = status.name.attendanceBackgroundColor;

    return Semantics(
      label: '${student.name}, ${attendance.status.displayName}. Tap to change status.',
      button: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(minHeight: 72),
            child: Row(
              children: [
                // Status icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getStatusIcon(status),
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Student info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        student.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                      ),
                      if (student.studentId != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${student.studentId}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),

                // Status text
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  IconData _getStatusIcon(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return Icons.check;
      case AttendanceStatus.absent:
        return Icons.close;
      case AttendanceStatus.late:
        return Icons.access_time;
      case AttendanceStatus.unmarked:
        return Icons.remove;
    }
  }
}
