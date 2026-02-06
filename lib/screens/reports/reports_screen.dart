import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../utils/theme.dart';
import '../../utils/launcher.dart';
import '../../services/services.dart';
import '../../models/models.dart';
import '../../providers/attendance_providers.dart';
import '../../widgets/common_widgets.dart';
import '../attendance/edit_attendance_screen.dart';
import '../attendance/notification_status_screen.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'Absent'),
            Tab(text: 'Monthly'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _DailyReportTab(),
          _AbsentListTab(),
          _MonthlyReportTab(),
        ],
      ),
    );
  }
}

class _DailyReportTab extends ConsumerWidget {
  const _DailyReportTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceListAsync = ref.watch(todayAttendanceListProvider);

    return attendanceListAsync.when(
      data: (attendanceList) {
        if (attendanceList.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.assessment_outlined,
            title: 'No Attendance Today',
            subtitle: 'Mark attendance for a batch to see the report',
          );
        }

        // Calculate totals
        int totalPresent = 0;
        int totalAbsent = 0;
        int totalLate = 0;

        for (final info in attendanceList) {
          totalPresent += info.summary.presentCount;
          totalAbsent += info.summary.absentCount;
          totalLate += info.summary.lateCount;
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(todayAttendanceListProvider.future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date header
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),

                // Overall summary cards
                Row(
                  children: [
                    Expanded(
                      child: SummaryCard(
                        title: 'Present',
                        value: totalPresent.toString(),
                        icon: Icons.check_circle,
                        color: AppColors.present,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SummaryCard(
                        title: 'Absent',
                        value: totalAbsent.toString(),
                        icon: Icons.cancel,
                        color: AppColors.absent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SummaryCard(
                        title: 'Late',
                        value: totalLate.toString(),
                        icon: Icons.access_time,
                        color: AppColors.late,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Per-batch breakdown
                Text(
                  'By Batch',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),

                // Batch cards with edit buttons
                ...attendanceList.map((info) => _BatchAttendanceCard(
                  info: info,
                  onEdit: info.canEdit
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditAttendanceScreen(
                                batch: info.batch,
                                attendanceRecord: info.record,
                                instituteId: info.record.instituteId,
                              ),
                            ),
                          );
                        }
                      : null,
                  onViewStatus: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NotificationStatusScreen(
                          instituteId: info.record.instituteId,
                          attendanceId: info.record.id,
                          batchName: info.batch.name,
                          date: info.record.date,
                        ),
                      ),
                    );
                  },
                )),
              ],
            ),
          ),
        );
      },
      loading: () => const ShimmerListLoading(type: ShimmerListType.simple, itemCount: 4),
      error: (error, stack) => ErrorStateWidget(
        error: error,
        onRetry: () => ref.invalidate(todayAttendanceListProvider),
      ),
    );
  }
}

/// Card showing batch attendance summary with optional edit button
class _BatchAttendanceCard extends StatelessWidget {
  final TodayAttendanceInfo info;
  final VoidCallback? onEdit;
  final VoidCallback? onViewStatus;

  const _BatchAttendanceCard({
    required this.info,
    this.onEdit,
    this.onViewStatus,
  });

  String _formatRemainingTime(Duration duration) {
    if (duration.inMinutes < 1) return 'less than a minute';
    if (duration.inMinutes < 60) return '${duration.inMinutes} min';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (minutes == 0) return '$hours hr';
    return '$hours hr $minutes min';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with batch name and edit button
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.batch.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (info.batch.subject != null)
                        Text(
                          info.batch.subject!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (onEdit != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatRemainingTime(info.remainingEditTime)} left',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.warning,
                              fontSize: 10,
                            ),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.textHint.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Edit window closed',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textHint,
                            fontSize: 10,
                          ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Summary row
            Row(
              children: [
                _MiniSummaryChip(
                  label: 'Present',
                  count: info.summary.presentCount,
                  color: AppColors.present,
                ),
                const SizedBox(width: 8),
                _MiniSummaryChip(
                  label: 'Absent',
                  count: info.summary.absentCount,
                  color: AppColors.absent,
                ),
                const SizedBox(width: 8),
                _MiniSummaryChip(
                  label: 'Late',
                  count: info.summary.lateCount,
                  color: AppColors.late,
                ),
              ],
            ),

            // Submitted time and notification status
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Submitted at ${DateFormat('h:mm a').format(info.record.submittedAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
                // Show "View Status" button if there are notifications
                if (onViewStatus != null &&
                    (info.summary.absentCount > 0 || info.summary.lateCount > 0))
                  TextButton.icon(
                    onPressed: onViewStatus,
                    icon: const Icon(Icons.notifications, size: 16),
                    label: const Text('View Status'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniSummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _MiniSummaryChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AbsentListTab extends ConsumerWidget {
  const _AbsentListTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacher = ref.watch(currentTeacherProvider).value;

    if (teacher == null) {
      return const ShimmerListLoading(type: ShimmerListType.student, itemCount: 5);
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.read(firestoreServiceProvider).getTodaysAbsentStudents(teacher.instituteId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ShimmerListLoading(type: ShimmerListType.student, itemCount: 5);
        }

        if (snapshot.hasError) {
          return ErrorStateWidget(
            error: snapshot.error!,
            compact: true,
          );
        }

        final absentStudents = snapshot.data ?? [];

        if (absentStudents.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.check_circle_outline,
            title: 'No Absences Today',
            subtitle: 'All students marked present or no attendance marked yet',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: absentStudents.length,
          itemBuilder: (context, index) {
            final data = absentStudents[index];
            final student = data['student'] as StudentAttendance;
            final batchName = data['batchName'] as String;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.absentLight,
                  child: Icon(Icons.person_off, color: AppColors.absent),
                ),
                title: Text(student.studentName),
                subtitle: Text(batchName),
                trailing: IconButton(
                  icon: const Icon(Icons.phone),
                  color: AppColors.primary,
                  onPressed: () {
                    Launcher.showContactOptions(
                      context: context,
                      phoneNumber: student.parentPhone,
                      name: '${student.studentName}\'s parent',
                      message: 'Hi, this is regarding ${student.studentName}\'s absence today.',
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Provider for batches (reused from dashboard)
final _batchesForReportProvider = StreamProvider<List<Batch>>((ref) {
  final teacher = ref.watch(currentTeacherProvider).value;
  if (teacher == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).batchesStream(teacher.instituteId);
});

class _MonthlyReportTab extends ConsumerStatefulWidget {
  const _MonthlyReportTab();

  @override
  ConsumerState<_MonthlyReportTab> createState() => _MonthlyReportTabState();
}

class _MonthlyReportTabState extends ConsumerState<_MonthlyReportTab> {
  DateTime _selectedMonth = DateTime.now();
  Batch? _selectedBatch;

  @override
  Widget build(BuildContext context) {
    final batches = ref.watch(_batchesForReportProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month selector
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month - 1,
                    );
                  });
                },
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _selectedMonth.month < DateTime.now().month ||
                        _selectedMonth.year < DateTime.now().year
                    ? () {
                        setState(() {
                          _selectedMonth = DateTime(
                            _selectedMonth.year,
                            _selectedMonth.month + 1,
                          );
                        });
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Batch selector dropdown
          batches.when(
            data: (batchList) {
              if (batchList.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No batches available'),
                  ),
                );
              }

              return DropdownButtonFormField<Batch>(
                value: _selectedBatch,
                decoration: const InputDecoration(
                  labelText: 'Select Batch',
                  prefixIcon: Icon(Icons.groups),
                ),
                items: batchList.map((batch) {
                  return DropdownMenuItem(
                    value: batch,
                    child: Text(batch.name),
                  );
                }).toList(),
                onChanged: (batch) {
                  setState(() {
                    _selectedBatch = batch;
                  });
                },
              );
            },
            loading: () => const ShimmerListItem(showSubtitle: false),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 24),

          // Report content
          if (_selectedBatch == null)
            const EmptyStateWidget(
              icon: Icons.calendar_month,
              title: 'Select a Batch',
              subtitle: 'Choose a batch to view its monthly attendance report',
            )
          else
            _MonthlyReportContent(
              batch: _selectedBatch!,
              month: _selectedMonth,
            ),
        ],
      ),
    );
  }
}

class _MonthlyReportContent extends ConsumerWidget {
  final Batch batch;
  final DateTime month;

  const _MonthlyReportContent({
    required this.batch,
    required this.month,
  });

  Future<void> _exportPdf(
    BuildContext context,
    List<StudentMonthlyAttendance> students,
    String instituteName,
  ) async {
    final pdf = pw.Document();
    final monthName = DateFormat('MMMM yyyy').format(month);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              instituteName,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Monthly Attendance Report',
              style: const pw.TextStyle(fontSize: 16),
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Batch: ${batch.name}'),
                pw.Text('Month: $monthName'),
              ],
            ),
            pw.SizedBox(height: 16),
          ],
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellHeight: 30,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
            },
            headers: ['Student Name', 'Present', 'Absent', 'Late', 'Total', 'Attendance %'],
            data: students.map((s) => [
              s.studentName,
              s.presentCount.toString(),
              s.absentCount.toString(),
              s.lateCount.toString(),
              s.totalDays.toString(),
              '${s.attendancePercentage.toStringAsFixed(1)}%',
            ]).toList(),
          ),
          pw.SizedBox(height: 24),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Summary',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Text('Total Students: ${students.length}'),
                    pw.Text('Average Attendance: ${_calculateAverageAttendance(students).toStringAsFixed(1)}%'),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'Generated on ${DateFormat('MMM d, yyyy h:mm a').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: '${batch.name}_${monthName}_attendance.pdf',
    );
  }

  double _calculateAverageAttendance(List<StudentMonthlyAttendance> students) {
    if (students.isEmpty) return 0;
    final totalPercentage = students.fold<double>(
      0,
      (sum, s) => sum + s.attendancePercentage,
    );
    return totalPercentage / students.length;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacher = ref.watch(currentTeacherProvider).value;
    if (teacher == null) return const SizedBox.shrink();

    final monthlyDataAsync = ref.watch(monthlyAttendanceProvider((
      instituteId: teacher.instituteId,
      batchId: batch.id,
      month: month,
    )));

    // Calculate working days in month (excluding Sundays)
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    int workingDays = 0;
    for (int i = 1; i <= daysInMonth; i++) {
      final date = DateTime(month.year, month.month, i);
      if (date.weekday != DateTime.sunday) {
        workingDays++;
      }
    }

    return monthlyDataAsync.when(
      data: (students) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Batch info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.groups, color: AppColors.primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              batch.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            if (batch.subject != null)
                              Text(
                                batch.subject!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.calendar_today,
                        label: '$workingDays working days',
                      ),
                      const SizedBox(width: 8),
                      _InfoChip(
                        icon: Icons.person,
                        label: '${students.length} students',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Export button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: students.isNotEmpty
                  ? () => _exportPdf(context, students, teacher.name)
                  : null,
              icon: const Icon(Icons.download),
              label: const Text('Export PDF Report'),
            ),
          ),
          const SizedBox(height: 24),

          // Student breakdown section
          Text(
            'Student Attendance',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),

          if (students.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No attendance data for this month'),
              ),
            )
          else
            ...students.map((student) => _StudentAttendanceRow(student: student)),

          const SizedBox(height: 24),

          // Overall stats
          if (students.isNotEmpty)
            Card(
              color: AppColors.primary.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          '${students.length}',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                        ),
                        const Text('Students'),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '${_calculateAverageAttendance(students).toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.present,
                              ),
                        ),
                        const Text('Avg Attendance'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      loading: () => const ShimmerListLoading(type: ShimmerListType.simple, itemCount: 5),
      error: (e, _) => ErrorStateWidget(
        error: e,
        onRetry: () {
          final teacher = ref.read(currentTeacherProvider).value;
          if (teacher != null) {
            ref.invalidate(monthlyAttendanceProvider((
              instituteId: teacher.instituteId,
              batchId: batch.id,
              month: month,
            )));
          }
        },
      ),
    );
  }
}

class _StudentAttendanceRow extends StatelessWidget {
  final StudentMonthlyAttendance student;

  const _StudentAttendanceRow({required this.student});

  @override
  Widget build(BuildContext context) {
    final percentage = student.attendancePercentage;
    final color = percentage >= 90
        ? AppColors.present
        : percentage >= 75
            ? AppColors.late
            : AppColors.absent;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.studentName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _MiniStat(label: 'P', count: student.presentCount, color: AppColors.present),
                      const SizedBox(width: 8),
                      _MiniStat(label: 'A', count: student.absentCount, color: AppColors.absent),
                      const SizedBox(width: 8),
                      _MiniStat(label: 'L', count: student.lateCount, color: AppColors.late),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: $count',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceCalendarPreview extends StatelessWidget {
  final DateTime month;
  final int daysInMonth;

  const _AttendanceCalendarPreview({
    required this.month,
    required this.daysInMonth,
  });

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final startingWeekday = firstDayOfMonth.weekday; // 1 = Monday, 7 = Sunday

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.2,
      ),
      itemCount: 7 + daysInMonth + (startingWeekday - 1),
      itemBuilder: (context, index) {
        // Weekday headers
        if (index < 7) {
          const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
          return Center(
            child: Text(
              weekdays[index],
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: index == 6 ? AppColors.absent : AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          );
        }

        // Empty cells before first day
        final adjustedIndex = index - 7;
        if (adjustedIndex < startingWeekday - 1) {
          return const SizedBox.shrink();
        }

        // Day cells
        final day = adjustedIndex - (startingWeekday - 1) + 1;
        if (day > daysInMonth) {
          return const SizedBox.shrink();
        }

        final date = DateTime(month.year, month.month, day);
        final isSunday = date.weekday == DateTime.sunday;
        final isPast = date.isBefore(DateTime.now());
        final isToday = date.year == DateTime.now().year &&
            date.month == DateTime.now().month &&
            date.day == DateTime.now().day;

        Color bgColor;
        Color textColor;
        if (isSunday) {
          bgColor = AppColors.absentLight;
          textColor = AppColors.absent;
        } else if (isPast) {
          bgColor = AppColors.presentLight;
          textColor = AppColors.present;
        } else {
          bgColor = AppColors.unmarkedLight;
          textColor = AppColors.textSecondary;
        }

        return Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: isToday
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
          ),
          child: Center(
            child: Text(
              day.toString(),
              style: TextStyle(
                color: textColor,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
