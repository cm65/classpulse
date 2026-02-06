import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';

import '../../utils/theme.dart';
import '../../utils/design_tokens.dart';
import '../../utils/helpers.dart';
import '../../services/services.dart';
import '../../models/models.dart';
import '../../widgets/common_widgets.dart';
import '../../providers/attendance_providers.dart';
import '../attendance/attendance_screen.dart';
import 'student_history_screen.dart';

class StudentListScreen extends ConsumerStatefulWidget {
  final Batch batch;
  final String instituteId;

  const StudentListScreen({
    super.key,
    required this.batch,
    required this.instituteId,
  });

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showAddStudentDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _AddStudentDialog(
        instituteId: widget.instituteId,
        batchId: widget.batch.id,
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student added successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _importFromCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null) return;

    try {
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) throw Exception('Could not read file');

      final csvString = utf8.decode(bytes);
      final rows = const CsvToListConverter().convert(csvString);

      if (rows.isEmpty) throw Exception('CSV file is empty');

      // Skip header row
      final dataRows = rows.skip(1).toList();

      // Preview dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _CsvPreviewDialog(
          rows: dataRows,
          instituteId: widget.instituteId,
          batchId: widget.batch.id,
        ),
      );

      if (confirmed == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Students imported successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing CSV: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(studentsProvider((
      instituteId: widget.instituteId,
      batchId: widget.batch.id,
    )));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.batch.name),
            Text(
              'Students',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import CSV',
            onPressed: _importFromCsv,
          ),
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Mark Attendance',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AttendanceScreen(
                    batch: widget.batch,
                    instituteId: widget.instituteId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: students.when(
        data: (studentList) {
          if (studentList.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.person_add_alt_1,
              title: 'No Students Yet',
              subtitle: 'Add students manually or import from CSV',
              action: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _showAddStudentDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Student'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _importFromCsv,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import from CSV'),
                  ),
                ],
              ),
            );
          }

          // Filter students by search query
          final filteredStudents = _searchQuery.isEmpty
              ? studentList
              : studentList.where((student) {
                  final query = _searchQuery.toLowerCase();
                  return student.name.toLowerCase().contains(query) ||
                      student.parentPhone.contains(query) ||
                      (student.studentId?.toLowerCase().contains(query) ?? false);
                }).toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(studentsProvider((
                instituteId: widget.instituteId,
                batchId: widget.batch.id,
              )));
            },
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search students...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                // Student count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        '${filteredStudents.length} student${filteredStudents.length == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (_searchQuery.isNotEmpty) ...[
                        Text(
                          ' (filtered from ${studentList.length})',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Student list
                Expanded(
                  child: filteredStudents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 48,
                                color: AppColors.textHint,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No students found',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: filteredStudents.length,
                          itemBuilder: (context, index) {
                            final student = filteredStudents[index];
                            return _StudentListItem(
                              student: student,
                              instituteId: widget.instituteId,
                              batchId: widget.batch.id,
                              batchName: widget.batch.name,
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
        loading: () => const ShimmerListLoading(type: ShimmerListType.student),
        error: (error, stack) => ErrorStateWidget(
          error: error,
          onRetry: () => ref.invalidate(studentsProvider((
            instituteId: widget.instituteId,
            batchId: widget.batch.id,
          ))),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStudentDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _StudentListItem extends ConsumerWidget {
  final Student student;
  final String instituteId;
  final String batchId;
  final String batchName;

  const _StudentListItem({
    required this.student,
    required this.instituteId,
    required this.batchId,
    required this.batchName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentHistoryScreen(
                student: student,
                batchId: batchId,
                batchName: batchName,
                instituteId: instituteId,
              ),
            ),
          );
        },
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Text(
            student.name.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(student.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(student.formattedPhone),
            if (student.studentId != null)
              Text(
                'ID: ${student.studentId}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'history',
              child: Row(
                children: [
                  Icon(Icons.history),
                  SizedBox(width: 8),
                  Text('View History'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: AppColors.error),
                  SizedBox(width: 8),
                  Text('Remove', style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
          ],
          onSelected: (value) async {
            switch (value) {
              case 'edit':
                final result = await showDialog<bool>(
                  context: context,
                  builder: (context) => _EditStudentDialog(
                    student: student,
                    instituteId: instituteId,
                    batchId: batchId,
                  ),
                );
                if (result == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Student updated successfully!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
                break;
              case 'history':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentHistoryScreen(
                      student: student,
                      batchId: batchId,
                      batchName: batchName,
                      instituteId: instituteId,
                    ),
                  ),
                );
                break;
              case 'delete':
                final confirmed = await showConfirmationDialog(
                  context: context,
                  title: 'Remove Student',
                  message: 'Are you sure you want to remove ${student.name}? Attendance history will be preserved.',
                  confirmText: 'Remove',
                  isDangerous: true,
                );
                if (confirmed) {
                  await ref.read(firestoreServiceProvider).deleteStudent(
                    instituteId,
                    batchId,
                    student.id,
                  );
                }
                break;
            }
          },
        ),
      ),
    );
  }
}

class _AddStudentDialog extends ConsumerStatefulWidget {
  final String instituteId;
  final String batchId;

  const _AddStudentDialog({
    required this.instituteId,
    required this.batchId,
  });

  @override
  ConsumerState<_AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends ConsumerState<_AddStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _studentIdController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }

  Future<void> _addStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);

      // Check for duplicate phone
      final isDuplicate = await firestoreService.isPhoneDuplicate(
        widget.instituteId,
        widget.batchId,
        _phoneController.text.trim(),
      );

      if (isDuplicate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A student with this phone number already exists in this batch'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final student = Student(
        id: '',
        batchId: widget.batchId,
        name: _nameController.text.trim(),
        parentPhone: _phoneController.text.trim(),
        studentId: _studentIdController.text.trim().isEmpty
            ? null
            : _studentIdController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await firestoreService.addStudent(
        widget.instituteId,
        widget.batchId,
        student,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHelpers.getActionError('add student', e)),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Student'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Student Name *',
                hintText: 'Enter student name',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter student name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Parent Phone *',
                hintText: '10-digit mobile number',
                prefixText: '+91  ',
              ),
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter phone number';
                }
                if (!Student.isValidIndianPhone(value)) {
                  return 'Please enter a valid 10-digit number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _studentIdController,
              decoration: const InputDecoration(
                labelText: 'Student ID (Optional)',
                hintText: 'Roll number or ID',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        LoadingButton(
          isLoading: _isLoading,
          onPressed: _addStudent,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _CsvPreviewDialog extends ConsumerStatefulWidget {
  final List<List<dynamic>> rows;
  final String instituteId;
  final String batchId;

  const _CsvPreviewDialog({
    required this.rows,
    required this.instituteId,
    required this.batchId,
  });

  @override
  ConsumerState<_CsvPreviewDialog> createState() => _CsvPreviewDialogState();
}

class _CsvPreviewDialogState extends ConsumerState<_CsvPreviewDialog> {
  bool _isLoading = false;
  int _importedCount = 0;
  final List<Map<String, dynamic>> _validStudents = [];
  final List<String> _errors = [];

  @override
  void initState() {
    super.initState();
    _parseRows();
  }

  void _parseRows() {
    for (int i = 0; i < widget.rows.length; i++) {
      final row = widget.rows[i];
      if (row.isEmpty) continue;

      final name = row.isNotEmpty ? row[0].toString().trim() : '';
      final phone = row.length > 1 ? row[1].toString().trim() : '';
      final studentId = row.length > 2 ? row[2].toString().trim() : null;

      if (name.isEmpty) {
        _errors.add('Row ${i + 2}: Missing student name');
        continue;
      }

      if (!Student.isValidIndianPhone(phone)) {
        _errors.add('Row ${i + 2}: Invalid phone number for $name');
        continue;
      }

      _validStudents.add({
        'name': name,
        'phone': phone,
        'studentId': studentId,
      });
    }
  }

  Future<void> _importStudents() async {
    setState(() {
      _isLoading = true;
      _importedCount = 0;
    });

    try {
      final firestoreService = ref.read(firestoreServiceProvider);

      final students = _validStudents.map((data) => Student(
        id: '',
        batchId: widget.batchId,
        name: data['name'] as String,
        parentPhone: data['phone'] as String,
        studentId: data['studentId'] as String?,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      )).toList();

      // Bulk add with progress tracking (batches of 10)
      const batchSize = 10;
      for (var i = 0; i < students.length; i += batchSize) {
        final end = (i + batchSize < students.length) ? i + batchSize : students.length;
        final chunk = students.sublist(i, end);
        await firestoreService.bulkAddStudents(
          widget.instituteId,
          widget.batchId,
          chunk,
        );
        if (mounted) {
          setState(() => _importedCount = end);
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import Preview'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_validStudents.length} valid students found',
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_errors.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${_errors.length} rows skipped due to errors',
                style: const TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text('Preview:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _validStudents.take(5).length,
                itemBuilder: (context, index) {
                  final student = _validStudents[index];
                  return ListTile(
                    dense: true,
                    title: Text(student['name'] as String),
                    subtitle: Text(student['phone'] as String),
                  );
                },
              ),
            ),
            if (_validStudents.length > 5)
              Text(
                '... and ${_validStudents.length - 5} more',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            if (_isLoading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _validStudents.isNotEmpty
                    ? _importedCount / _validStudents.length
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                'Uploading $_importedCount of ${_validStudents.length} students...',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        LoadingButton(
          isLoading: _isLoading,
          onPressed: _validStudents.isEmpty ? null : _importStudents,
          child: Text('Import ${_validStudents.length}'),
        ),
      ],
    );
  }
}

class _EditStudentDialog extends ConsumerStatefulWidget {
  final Student student;
  final String instituteId;
  final String batchId;

  const _EditStudentDialog({
    required this.student,
    required this.instituteId,
    required this.batchId,
  });

  @override
  ConsumerState<_EditStudentDialog> createState() => _EditStudentDialogState();
}

class _EditStudentDialogState extends ConsumerState<_EditStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _studentIdController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.student.name);
    _phoneController = TextEditingController(
      text: widget.student.parentPhone.replaceAll(RegExp(r'^\+91'), ''),
    );
    _studentIdController = TextEditingController(text: widget.student.studentId ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }

  Future<void> _updateStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);

      final newPhone = _phoneController.text.trim();

      // Check for duplicate phone if it changed
      if (newPhone != widget.student.parentPhone.replaceAll(RegExp(r'^\+91'), '')) {
        final isDuplicate = await firestoreService.isPhoneDuplicate(
          widget.instituteId,
          widget.batchId,
          newPhone,
          excludeStudentId: widget.student.id,
        );

        if (isDuplicate) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('A student with this phone number already exists in this batch'),
                backgroundColor: AppColors.warning,
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      await firestoreService.updateStudent(
        widget.instituteId,
        widget.batchId,
        widget.student.id,
        {
          'name': _nameController.text.trim(),
          'parentPhone': newPhone,
          'studentId': _studentIdController.text.trim().isEmpty
              ? null
              : _studentIdController.text.trim(),
        },
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHelpers.getActionError('update student', e)),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Student'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Student Name *',
                hintText: 'Enter student name',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter student name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Parent Phone *',
                hintText: '10-digit mobile number',
                prefixText: '+91  ',
              ),
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter phone number';
                }
                if (!Student.isValidIndianPhone(value)) {
                  return 'Please enter a valid 10-digit number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _studentIdController,
              decoration: const InputDecoration(
                labelText: 'Student ID (Optional)',
                hintText: 'Roll number or ID',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        LoadingButton(
          isLoading: _isLoading,
          onPressed: _updateStudent,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
