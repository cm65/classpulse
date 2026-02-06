import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';

/// Screen for entering scores for a test
class ScoreEntryScreen extends ConsumerStatefulWidget {
  final String instituteId;
  final String testId;

  const ScoreEntryScreen({
    super.key,
    required this.instituteId,
    required this.testId,
  });

  @override
  ConsumerState<ScoreEntryScreen> createState() => _ScoreEntryScreenState();
}

class _ScoreEntryScreenState extends ConsumerState<ScoreEntryScreen> {
  final Map<String, _ScoreEntry> _scores = {};
  bool _isLoading = false;
  bool _isSaving = false;
  Test? _test;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);

      // Load test
      final test = await firestoreService.getTest(widget.instituteId, widget.testId);
      if (test == null) {
        throw Exception('Test not found');
      }

      // Load students
      final students = await firestoreService.getStudentsForBatch(
        widget.instituteId,
        test.batchId,
      );

      // Load existing scores
      final existingScores = await firestoreService.getTestScores(
        widget.instituteId,
        widget.testId,
      );
      final scoreMap = {for (var s in existingScores) s.studentId: s};

      // Initialize score entries
      for (final student in students) {
        final existingScore = scoreMap[student.id];
        _scores[student.id] = _ScoreEntry(
          studentId: student.id,
          studentName: student.name,
          controller: TextEditingController(
            text: existingScore?.marksObtained?.toStringAsFixed(1) ?? '',
          ),
          isAbsent: existingScore?.isAbsent ?? false,
          isExempt: existingScore?.isExempt ?? false,
          remarks: existingScore?.remarks,
        );
      }

      setState(() {
        _test = test;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.absent),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    for (final entry in _scores.values) {
      entry.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _test == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Enter Scores')),
        body: const ShimmerListLoading(type: ShimmerListType.simple),
      );
    }

    final sortedEntries = _scores.values.toList()
      ..sort((a, b) => a.studentName.compareTo(b.studentName));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_test!.name, style: const TextStyle(fontSize: 16)),
            Text(
              'Max: ${_test!.maxMarks.toStringAsFixed(0)} marks',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveScores,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Save'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats header
          _StatsHeader(
            test: _test!,
            scores: _scores,
          ),

          // Score list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedEntries.length,
              itemBuilder: (context, index) {
                final entry = sortedEntries[index];
                return _ScoreCard(
                  entry: entry,
                  maxMarks: _test!.maxMarks,
                  passingMarks: _test!.passingMarks,
                  onChanged: () => setState(() {}),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveScores,
            child: _isSaving
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Saving...'),
                    ],
                  )
                : const Text('Save All Scores'),
          ),
        ),
      ),
    );
  }

  Future<void> _saveScores() async {
    setState(() => _isSaving = true);

    try {
      final teacher = ref.read(currentTeacherProvider).value;
      final firestoreService = ref.read(firestoreServiceProvider);
      final now = DateTime.now();

      final scoresToSave = <Score>[];

      for (final entry in _scores.values) {
        double? marks;
        if (!entry.isAbsent && !entry.isExempt && entry.controller.text.isNotEmpty) {
          marks = double.tryParse(entry.controller.text);
          if (marks != null && marks > _test!.maxMarks) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${entry.studentName}: Marks cannot exceed ${_test!.maxMarks}'),
                backgroundColor: AppColors.absent,
              ),
            );
            setState(() => _isSaving = false);
            return;
          }
        }

        scoresToSave.add(Score(
          id: '',
          testId: widget.testId,
          studentId: entry.studentId,
          marksObtained: marks,
          isAbsent: entry.isAbsent,
          isExempt: entry.isExempt,
          remarks: entry.remarks,
          gradedBy: teacher?.id,
          createdAt: now,
          updatedAt: now,
        ));
      }

      await firestoreService.saveScoresBulk(widget.instituteId, scoresToSave);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scores saved successfully'),
            backgroundColor: AppColors.present,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.absent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _ScoreEntry {
  final String studentId;
  final String studentName;
  final TextEditingController controller;
  bool isAbsent;
  bool isExempt;
  String? remarks;

  _ScoreEntry({
    required this.studentId,
    required this.studentName,
    required this.controller,
    this.isAbsent = false,
    this.isExempt = false,
    this.remarks,
  });
}

class _StatsHeader extends StatelessWidget {
  final Test test;
  final Map<String, _ScoreEntry> scores;

  const _StatsHeader({required this.test, required this.scores});

  @override
  Widget build(BuildContext context) {
    int graded = 0;
    int absent = 0;
    int exempt = 0;
    int pending = 0;

    for (final entry in scores.values) {
      if (entry.isAbsent) {
        absent++;
      } else if (entry.isExempt) {
        exempt++;
      } else if (entry.controller.text.isNotEmpty) {
        graded++;
      } else {
        pending++;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(label: 'Graded', value: '$graded', color: AppColors.present),
          _StatChip(label: 'Absent', value: '$absent', color: AppColors.absent),
          _StatChip(label: 'Exempt', value: '$exempt', color: AppColors.late),
          _StatChip(label: 'Pending', value: '$pending', color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final _ScoreEntry entry;
  final double maxMarks;
  final double? passingMarks;
  final VoidCallback onChanged;

  const _ScoreCard({
    required this.entry,
    required this.maxMarks,
    required this.passingMarks,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final marks = double.tryParse(entry.controller.text);
    final percentage = marks != null ? (marks / maxMarks) * 100 : null;
    final passed = passingMarks != null && marks != null ? marks >= passingMarks! : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student name and status
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: entry.isAbsent
                      ? AppColors.absent.withValues(alpha: 0.1)
                      : entry.isExempt
                          ? AppColors.late.withValues(alpha: 0.1)
                          : AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    entry.studentName[0].toUpperCase(),
                    style: TextStyle(
                      color: entry.isAbsent
                          ? AppColors.absent
                          : entry.isExempt
                              ? AppColors.late
                              : AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.studentName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                if (percentage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: passed == true
                          ? AppColors.present.withValues(alpha: 0.1)
                          : passed == false
                              ? AppColors.absent.withValues(alpha: 0.1)
                              : AppColors.border,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: passed == true
                            ? AppColors.present
                            : passed == false
                                ? AppColors.absent
                                : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Marks input or status
            if (entry.isAbsent || entry.isExempt) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: entry.isAbsent
                      ? AppColors.absent.withValues(alpha: 0.05)
                      : AppColors.late.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      entry.isAbsent ? Icons.person_off : Icons.block,
                      size: 18,
                      color: entry.isAbsent ? AppColors.absent : AppColors.late,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.isAbsent ? 'Marked as Absent' : 'Marked as Exempt',
                      style: TextStyle(
                        color: entry.isAbsent ? AppColors.absent : AppColors.late,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              TextFormField(
                controller: entry.controller,
                decoration: InputDecoration(
                  labelText: 'Marks (out of ${maxMarks.toStringAsFixed(0)})',
                  prefixIcon: const Icon(Icons.edit),
                  suffixText: '/ ${maxMarks.toStringAsFixed(0)}',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                onChanged: (_) => onChanged(),
              ),
            ],
            const SizedBox(height: 12),

            // Quick actions
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    label: 'Absent',
                    isActive: entry.isAbsent,
                    activeColor: AppColors.absent,
                    onTap: () {
                      entry.isAbsent = !entry.isAbsent;
                      if (entry.isAbsent) {
                        entry.isExempt = false;
                        entry.controller.clear();
                      }
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickActionButton(
                    label: 'Exempt',
                    isActive: entry.isExempt,
                    activeColor: AppColors.late,
                    onTap: () {
                      entry.isExempt = !entry.isExempt;
                      if (entry.isExempt) {
                        entry.isAbsent = false;
                        entry.controller.clear();
                      }
                      onChanged();
                    },
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

class _QuickActionButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? activeColor : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : AppColors.textSecondary,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
