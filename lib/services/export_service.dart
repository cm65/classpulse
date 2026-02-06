import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/analytics.dart';

/// Service for exporting analytics data to Excel/CSV files
class ExportService {
  /// Export analytics data to Excel file and share it
  Future<void> exportAnalyticsToExcel(
    DashboardAnalytics analytics,
    String instituteName,
  ) async {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Summary');

    // Summary sheet
    _addSummarySheet(excel, analytics, instituteName);

    // Trend data sheet
    if (analytics.trendData.isNotEmpty) {
      _addTrendSheet(excel, analytics);
    }

    // Batch comparison sheet
    if (analytics.batchComparison.isNotEmpty) {
      _addBatchComparisonSheet(excel, analytics);
    }

    // At-risk students sheet
    if (analytics.atRiskStudents.isNotEmpty) {
      _addAtRiskSheet(excel, analytics);
    }

    // Save and share
    final bytes = excel.encode();
    if (bytes == null) return;

    final directory = await getTemporaryDirectory();
    final fileName = 'ClassPulse_Analytics_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'ClassPulse Analytics Report - ${analytics.period.displayName}',
    );
  }

  void _addSummarySheet(Excel excel, DashboardAnalytics analytics, String instituteName) {
    final sheet = excel['Summary'];
    final summary = analytics.summary;
    final dateFormat = DateFormat('MMM d, yyyy');

    // Header
    sheet.appendRow([
      TextCellValue('ClassPulse Analytics Report'),
    ]);
    sheet.appendRow([
      TextCellValue('Institute: $instituteName'),
    ]);
    sheet.appendRow([
      TextCellValue('Period: ${analytics.period.displayName}'),
    ]);
    sheet.appendRow([
      TextCellValue('Generated: ${dateFormat.format(DateTime.now())}'),
    ]);
    sheet.appendRow([TextCellValue('')]);

    // Summary section
    sheet.appendRow([TextCellValue('SUMMARY')]);
    sheet.appendRow([
      TextCellValue('Overall Attendance'),
      TextCellValue('${summary.overallAttendance.toStringAsFixed(1)}%'),
    ]);
    sheet.appendRow([
      TextCellValue('Previous Period'),
      TextCellValue('${summary.previousPeriodAttendance.toStringAsFixed(1)}%'),
    ]);
    sheet.appendRow([
      TextCellValue('Change'),
      TextCellValue(summary.changeText),
    ]);
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue('Total Students'),
      IntCellValue(summary.totalStudents),
    ]);
    sheet.appendRow([
      TextCellValue('Total Batches'),
      IntCellValue(summary.totalBatches),
    ]);
    sheet.appendRow([
      TextCellValue('Classes This Period'),
      IntCellValue(summary.totalClassesThisMonth),
    ]);
    sheet.appendRow([
      TextCellValue('At-Risk Students'),
      IntCellValue(summary.atRiskCount),
    ]);
    sheet.appendRow([TextCellValue('')]);

    // Distribution
    final dist = analytics.distribution;
    sheet.appendRow([TextCellValue('ATTENDANCE BREAKDOWN')]);
    sheet.appendRow([
      TextCellValue('Status'),
      TextCellValue('Count'),
      TextCellValue('Percentage'),
    ]);
    sheet.appendRow([
      TextCellValue('Present'),
      IntCellValue(dist.presentCount),
      TextCellValue('${dist.presentPercentage.toStringAsFixed(1)}%'),
    ]);
    sheet.appendRow([
      TextCellValue('Late'),
      IntCellValue(dist.lateCount),
      TextCellValue('${dist.latePercentage.toStringAsFixed(1)}%'),
    ]);
    sheet.appendRow([
      TextCellValue('Absent'),
      IntCellValue(dist.absentCount),
      TextCellValue('${dist.absentPercentage.toStringAsFixed(1)}%'),
    ]);
  }

  void _addTrendSheet(Excel excel, DashboardAnalytics analytics) {
    final sheet = excel['Daily Trend'];
    final dateFormat = DateFormat('yyyy-MM-dd');

    // Header
    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Attendance %'),
      TextCellValue('Present'),
      TextCellValue('Late'),
      TextCellValue('Absent'),
      TextCellValue('Total'),
    ]);

    // Data rows
    for (final point in analytics.trendData) {
      sheet.appendRow([
        TextCellValue(dateFormat.format(point.date)),
        DoubleCellValue(point.attendancePercentage),
        IntCellValue(point.presentCount),
        IntCellValue(point.lateCount),
        IntCellValue(point.absentCount),
        IntCellValue(point.totalStudents),
      ]);
    }
  }

  void _addBatchComparisonSheet(Excel excel, DashboardAnalytics analytics) {
    final sheet = excel['Batch Comparison'];

    // Header
    sheet.appendRow([
      TextCellValue('Batch Name'),
      TextCellValue('Attendance %'),
      TextCellValue('Students'),
      TextCellValue('Classes'),
      TextCellValue('Present'),
      TextCellValue('Late'),
      TextCellValue('Absent'),
    ]);

    // Data rows
    for (final batch in analytics.batchComparison) {
      sheet.appendRow([
        TextCellValue(batch.batchName),
        DoubleCellValue(batch.attendancePercentage),
        IntCellValue(batch.totalStudents),
        IntCellValue(batch.totalClasses),
        IntCellValue(batch.presentCount),
        IntCellValue(batch.lateCount),
        IntCellValue(batch.absentCount),
      ]);
    }
  }

  void _addAtRiskSheet(Excel excel, DashboardAnalytics analytics) {
    final sheet = excel['At-Risk Students'];
    final dateFormat = DateFormat('yyyy-MM-dd');

    // Header
    sheet.appendRow([
      TextCellValue('Student Name'),
      TextCellValue('Batch'),
      TextCellValue('Attendance %'),
      TextCellValue('Total Absences'),
      TextCellValue('Consecutive Absences'),
      TextCellValue('Last Present'),
      TextCellValue('Risk Level'),
      TextCellValue('Reason'),
    ]);

    // Data rows
    for (final student in analytics.atRiskStudents) {
      sheet.appendRow([
        TextCellValue(student.studentName),
        TextCellValue(student.batchName),
        DoubleCellValue(student.attendancePercentage),
        IntCellValue(student.totalAbsences),
        IntCellValue(student.consecutiveAbsences),
        TextCellValue(student.lastPresent != null
            ? dateFormat.format(student.lastPresent!)
            : 'Never'),
        TextCellValue(student.riskLevel.name.toUpperCase()),
        TextCellValue(student.reason.displayName),
      ]);
    }
  }

  /// Export analytics data to CSV format
  Future<void> exportAnalyticsToCsv(
    DashboardAnalytics analytics,
    String instituteName,
  ) async {
    final buffer = StringBuffer();
    final dateFormat = DateFormat('yyyy-MM-dd');

    // Summary section
    buffer.writeln('ClassPulse Analytics Report');
    buffer.writeln('Institute,$instituteName');
    buffer.writeln('Period,${analytics.period.displayName}');
    buffer.writeln('Generated,${dateFormat.format(DateTime.now())}');
    buffer.writeln();

    buffer.writeln('SUMMARY');
    buffer.writeln('Overall Attendance,${analytics.summary.overallAttendance.toStringAsFixed(1)}%');
    buffer.writeln('Previous Period,${analytics.summary.previousPeriodAttendance.toStringAsFixed(1)}%');
    buffer.writeln('Total Students,${analytics.summary.totalStudents}');
    buffer.writeln('Total Batches,${analytics.summary.totalBatches}');
    buffer.writeln('At-Risk Students,${analytics.summary.atRiskCount}');
    buffer.writeln();

    // Daily trend
    if (analytics.trendData.isNotEmpty) {
      buffer.writeln('DAILY TREND');
      buffer.writeln('Date,Attendance %,Present,Late,Absent,Total');
      for (final point in analytics.trendData) {
        buffer.writeln(
          '${dateFormat.format(point.date)},${point.attendancePercentage.toStringAsFixed(1)},'
          '${point.presentCount},${point.lateCount},${point.absentCount},${point.totalStudents}',
        );
      }
      buffer.writeln();
    }

    // Batch comparison
    if (analytics.batchComparison.isNotEmpty) {
      buffer.writeln('BATCH COMPARISON');
      buffer.writeln('Batch,Attendance %,Students,Classes,Present,Late,Absent');
      for (final batch in analytics.batchComparison) {
        buffer.writeln(
          '${_escapeCsv(batch.batchName)},${batch.attendancePercentage.toStringAsFixed(1)},'
          '${batch.totalStudents},${batch.totalClasses},'
          '${batch.presentCount},${batch.lateCount},${batch.absentCount}',
        );
      }
      buffer.writeln();
    }

    // At-risk students
    if (analytics.atRiskStudents.isNotEmpty) {
      buffer.writeln('AT-RISK STUDENTS');
      buffer.writeln('Student,Batch,Attendance %,Total Absences,Consecutive Absences,Last Present,Risk Level,Reason');
      for (final student in analytics.atRiskStudents) {
        buffer.writeln(
          '${_escapeCsv(student.studentName)},${_escapeCsv(student.batchName)},'
          '${student.attendancePercentage.toStringAsFixed(1)},${student.totalAbsences},'
          '${student.consecutiveAbsences},'
          '${student.lastPresent != null ? dateFormat.format(student.lastPresent!) : "Never"},'
          '${student.riskLevel.name.toUpperCase()},${student.reason.displayName}',
        );
      }
    }

    // Save and share
    final directory = await getTemporaryDirectory();
    final fileName = 'ClassPulse_Analytics_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'ClassPulse Analytics Report - ${analytics.period.displayName}',
    );
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
