import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vibration/vibration.dart';

import '../../utils/theme.dart';
import '../../services/services.dart';
import '../../models/models.dart';
import '../../providers/attendance_providers.dart';
import '../../widgets/common_widgets.dart';

/// Screen for editing previously submitted attendance within the edit window
class EditAttendanceScreen extends ConsumerStatefulWidget {
  final Batch batch;
  final AttendanceRecord attendanceRecord;
  final String instituteId;

  const EditAttendanceScreen({
    super.key,
    required this.batch,
    required this.attendanceRecord,
    required this.instituteId,
  });

  @override
  ConsumerState<EditAttendanceScreen> createState() => _EditAttendanceScreenState();
}

class _EditAttendanceScreenState extends ConsumerState<EditAttendanceScreen> {
  final Map<String, StudentAttendance> _attendanceMap = {};
  final Map<String, AttendanceStatus> _originalStatusMap = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadExistingAttendance();
  }

  Future<void> _loadExistingAttendance() async {
    final firestoreService = ref.read(firestoreServiceProvider);

    // Get existing attendance entries
    final entriesSnapshot = await firestoreService
        .attendanceEntriesStream(widget.instituteId, widget.attendanceRecord.id)
        .first;

    setState(() {
      for (final entry in entriesSnapshot) {
        _attendanceMap[entry.studentId] = entry;
        _originalStatusMap[entry.studentId] = entry.status;
      }
      _isLoading = false;
    });
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
      _checkForChanges();
    });
  }

  void _checkForChanges() {
    _hasChanges = false;
    for (final entry in _attendanceMap.entries) {
      if (_originalStatusMap[entry.key] != entry.value.status) {
        _hasChanges = true;
        break;
      }
    }
  }

  List<_AttendanceChange> _getChanges() {
    final changes = <_AttendanceChange>[];
    for (final entry in _attendanceMap.entries) {
      final originalStatus = _originalStatusMap[entry.key];
      if (originalStatus != null && originalStatus != entry.value.status) {
        changes.add(_AttendanceChange(
          studentId: entry.key,
          studentName: entry.value.studentName,
          originalStatus: originalStatus,
          newStatus: entry.value.status,
        ));
      }
    }
    return changes;
  }

  Future<void> _saveChanges() async {
    final changes = _getChanges();
    if (changes.isEmpty) {
      Navigator.pop(context);
      return;
    }

    // Check if still within edit window
    if (!widget.attendanceRecord.canEdit(defaultEditWindow)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Edit window has expired. Changes cannot be saved.'),
          backgroundColor: AppColors.error,
        ),
      );
      Navigator.pop(context);
      return;
    }

    // Confirm changes
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Changes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${changes.length} change(s) will be saved:'),
            const SizedBox(height: 12),
            ...changes.map((change) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(change.studentName)),
                      _StatusChangeIndicator(
                        from: change.originalStatus,
                        to: change.newStatus,
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
            const Text(
              'Parents of affected students will be notified of the correction.',
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
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);

    try {
      final teacher = ref.read(currentTeacherProvider).value;
      if (teacher == null) throw Exception('Not logged in');

      final firestoreService = ref.read(firestoreServiceProvider);

      // Update each changed entry
      for (final change in changes) {
        await firestoreService.updateAttendanceEntry(
          widget.instituteId,
          widget.attendanceRecord.id,
          change.studentId,
          change.newStatus,
        );

        // Add audit log for each change
        await firestoreService.addAuditLog(AuditLog.create(
          instituteId: widget.instituteId,
          userId: teacher.id,
          userName: teacher.name,
          action: AuditAction.attendanceEdit,
          metadata: {
            'batchId': widget.batch.id,
            'batchName': widget.batch.name,
            'attendanceRecordId': widget.attendanceRecord.id,
            'studentId': change.studentId,
            'studentName': change.studentName,
            'originalStatus': change.originalStatus.name,
            'newStatus': change.newStatus.name,
            'date': widget.attendanceRecord.date.toIso8601String(),
          },
        ));
      }

      // Update the attendance record's lastEditedAt
      await firestoreService.updateAttendanceRecord(
        widget.instituteId,
        widget.attendanceRecord.id,
        {
          'lastEditedAt': DateTime.now(),
          'lastEditedBy': teacher.id,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${changes.length} change(s) saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate changes were made
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final remainingTime = widget.attendanceRecord.remainingEditTime(defaultEditWindow);

    return WillPopScope(
      onWillPop: () async {
        if (_hasChanges) {
          final discard = await showConfirmationDialog(
            context: context,
            title: 'Discard Changes?',
            message: 'You have unsaved changes. Are you sure you want to go back?',
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
              const Text('Edit Attendance'),
              Text(
                widget.batch.name,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            // Remaining time indicator
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: remainingTime.inMinutes < 30
                    ? AppColors.error.withOpacity(0.1)
                    : AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer,
                    size: 16,
                    color: remainingTime.inMinutes < 30 ? AppColors.error : AppColors.warning,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatRemainingTime(remainingTime),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: remainingTime.inMinutes < 30 ? AppColors.error : AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Info banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: AppColors.info.withOpacity(0.1),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.info, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tap students to change their status. Changes are highlighted.',
                            style: TextStyle(
                              color: AppColors.info,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Quick summary bar
                  _buildSummaryBar(),

                  // Student list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _attendanceMap.length,
                      itemBuilder: (context, index) {
                        final entry = _attendanceMap.values.toList()[index];
                        final originalStatus = _originalStatusMap[entry.studentId];
                        final hasChanged = originalStatus != entry.status;

                        return _EditStudentAttendanceCard(
                          attendance: entry,
                          hasChanged: hasChanged,
                          originalStatus: originalStatus,
                          onTap: () => _toggleAttendance(entry.studentId),
                        );
                      },
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: _attendanceMap.isNotEmpty
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LoadingButton(
                    isLoading: _isSaving,
                    onPressed: _hasChanges ? _saveChanges : null,
                    backgroundColor: _hasChanges ? AppColors.primary : AppColors.textHint,
                    child: Text(_hasChanges ? 'Save Changes' : 'No Changes'),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  String _formatRemainingTime(Duration duration) {
    if (duration.inMinutes < 1) return '<1 min';
    if (duration.inMinutes < 60) return '${duration.inMinutes} min';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  Widget _buildSummaryBar() {
    final summary = AttendanceSummary.fromEntries(_attendanceMap.values.toList());
    final changes = _getChanges();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
          Container(
            height: 30,
            width: 1,
            color: AppColors.divider,
          ),
          _SummaryItem(
            label: 'Changed',
            count: changes.length,
            color: AppColors.warning,
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
            fontSize: 20,
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

class _EditStudentAttendanceCard extends StatelessWidget {
  final StudentAttendance attendance;
  final bool hasChanged;
  final AttendanceStatus? originalStatus;
  final VoidCallback onTap;

  const _EditStudentAttendanceCard({
    required this.attendance,
    required this.hasChanged,
    this.originalStatus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = attendance.status;
    final color = status.name.attendanceColor;
    final bgColor = hasChanged
        ? AppColors.warning.withOpacity(0.15)
        : status.name.attendanceBackgroundColor;

    return Padding(
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
            decoration: hasChanged
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning, width: 2),
                  )
                : null,
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
                        attendance.studentName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                      ),
                      if (hasChanged && originalStatus != null) ...[
                        const SizedBox(height: 4),
                        _StatusChangeIndicator(
                          from: originalStatus!,
                          to: status,
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

class _StatusChangeIndicator extends StatelessWidget {
  final AttendanceStatus from;
  final AttendanceStatus to;

  const _StatusChangeIndicator({
    required this.from,
    required this.to,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: from.name.attendanceColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            from.displayName,
            style: TextStyle(
              fontSize: 10,
              color: from.name.attendanceColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.arrow_forward, size: 12, color: AppColors.textHint),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: to.name.attendanceColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            to.displayName,
            style: TextStyle(
              fontSize: 10,
              color: to.name.attendanceColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _AttendanceChange {
  final String studentId;
  final String studentName;
  final AttendanceStatus originalStatus;
  final AttendanceStatus newStatus;

  _AttendanceChange({
    required this.studentId,
    required this.studentName,
    required this.originalStatus,
    required this.newStatus,
  });
}
