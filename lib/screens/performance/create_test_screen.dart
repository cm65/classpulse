import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../utils/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../providers/providers.dart';

/// Screen to create or edit a test
class CreateTestScreen extends ConsumerStatefulWidget {
  final String instituteId;
  final String? batchId; // Pre-selected batch
  final Test? existingTest; // For editing

  const CreateTestScreen({
    super.key,
    required this.instituteId,
    this.batchId,
    this.existingTest,
  });

  @override
  ConsumerState<CreateTestScreen> createState() => _CreateTestScreenState();
}

class _CreateTestScreenState extends ConsumerState<CreateTestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _maxMarksController = TextEditingController();
  final _passingMarksController = TextEditingController();
  final _durationController = TextEditingController();

  String? _selectedBatchId;
  String? _selectedSubjectId;
  TestType _selectedType = TestType.unitTest;
  DateTime _testDate = DateTime.now();
  bool _isLoading = false;

  bool get isEditing => widget.existingTest != null;

  @override
  void initState() {
    super.initState();
    _selectedBatchId = widget.batchId;

    if (isEditing) {
      final test = widget.existingTest!;
      _nameController.text = test.name;
      _descriptionController.text = test.description ?? '';
      _maxMarksController.text = test.maxMarks.toStringAsFixed(0);
      if (test.passingMarks != null) {
        _passingMarksController.text = test.passingMarks!.toStringAsFixed(0);
      }
      if (test.durationMinutes != null) {
        _durationController.text = test.durationMinutes.toString();
      }
      _selectedBatchId = test.batchId;
      _selectedSubjectId = test.subjectId;
      _selectedType = test.type;
      _testDate = test.testDate;
    } else {
      _maxMarksController.text = '100'; // Default
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _maxMarksController.dispose();
    _passingMarksController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(batchesProvider(widget.instituteId));
    final subjectsAsync = ref.watch(subjectsProvider(widget.instituteId));

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Test' : 'Create Test'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Test name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Test Name *',
                hintText: 'e.g., Chapter 5 Quiz, Midterm Exam',
                prefixIcon: Icon(Icons.quiz),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Enter test name';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Batch selector
            batchesAsync.when(
              data: (batches) {
                return DropdownButtonFormField<String>(
                  value: _selectedBatchId,
                  decoration: const InputDecoration(
                    labelText: 'Batch *',
                    prefixIcon: Icon(Icons.group),
                  ),
                  items: batches.map((batch) {
                    return DropdownMenuItem(
                      value: batch.id,
                      child: Text(batch.name),
                    );
                  }).toList(),
                  onChanged: isEditing
                      ? null
                      : (value) => setState(() => _selectedBatchId = value),
                  validator: (value) => value == null ? 'Select a batch' : null,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, s) => Text('Error loading batches: $e'),
            ),
            const SizedBox(height: 16),

            // Subject selector (optional)
            subjectsAsync.when(
              data: (subjects) {
                if (subjects.isEmpty) {
                  return const SizedBox.shrink();
                }
                return DropdownButtonFormField<String?>(
                  value: _selectedSubjectId,
                  decoration: const InputDecoration(
                    labelText: 'Subject (Optional)',
                    prefixIcon: Icon(Icons.subject),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('No Subject'),
                    ),
                    ...subjects.map((subject) {
                      return DropdownMenuItem<String?>(
                        value: subject.id,
                        child: Text(subject.name),
                      );
                    }),
                  ],
                  onChanged: (value) => setState(() => _selectedSubjectId = value),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, s) => const SizedBox.shrink(),
            ),
            if (subjectsAsync.valueOrNull?.isNotEmpty ?? false)
              const SizedBox(height: 16),

            // Test type
            DropdownButtonFormField<TestType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Test Type *',
                prefixIcon: Icon(Icons.category),
              ),
              items: TestType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Test date
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Test Date'),
              subtitle: Text(DateFormat('EEEE, MMM d, yyyy').format(_testDate)),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _testDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  setState(() => _testDate = date);
                }
              },
            ),
            const Divider(),
            const SizedBox(height: 16),

            // Marks section
            Text(
              'Marks',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _maxMarksController,
                    decoration: const InputDecoration(
                      labelText: 'Maximum Marks *',
                      prefixIcon: Icon(Icons.star),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required';
                      final marks = double.tryParse(value!);
                      if (marks == null || marks <= 0) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _passingMarksController,
                    decoration: const InputDecoration(
                      labelText: 'Passing Marks',
                      prefixIcon: Icon(Icons.check),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value?.isEmpty ?? true) return null;
                      final passing = double.tryParse(value!);
                      final max = double.tryParse(_maxMarksController.text);
                      if (passing == null || passing < 0) return 'Invalid';
                      if (max != null && passing > max) return 'Too high';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Duration (optional)
            TextFormField(
              controller: _durationController,
              decoration: const InputDecoration(
                labelText: 'Duration (minutes)',
                hintText: 'Optional',
                prefixIcon: Icon(Icons.timer),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Add any notes about this test',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            // Submit button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveTest,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEditing ? 'Update Test' : 'Create Test'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBatchId == null) return;

    setState(() => _isLoading = true);

    try {
      final teacher = ref.read(currentTeacherProvider).value;
      final now = DateTime.now();

      final test = Test(
        id: widget.existingTest?.id ?? '',
        batchId: _selectedBatchId!,
        subjectId: _selectedSubjectId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        type: _selectedType,
        maxMarks: double.parse(_maxMarksController.text),
        passingMarks: _passingMarksController.text.isEmpty
            ? null
            : double.parse(_passingMarksController.text),
        testDate: _testDate,
        durationMinutes: _durationController.text.isEmpty
            ? null
            : int.parse(_durationController.text),
        isPublished: widget.existingTest?.isPublished ?? false,
        createdBy: widget.existingTest?.createdBy ?? teacher?.id,
        createdAt: widget.existingTest?.createdAt ?? now,
        updatedAt: now,
      );

      final firestoreService = ref.read(firestoreServiceProvider);

      if (isEditing) {
        await firestoreService.updateTest(
          widget.instituteId,
          widget.existingTest!.id,
          test.toFirestore(),
        );
      } else {
        await firestoreService.createTest(widget.instituteId, test);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Test updated' : 'Test created'),
            backgroundColor: AppColors.present,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.absent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
