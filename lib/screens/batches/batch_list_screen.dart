import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/theme.dart';
import '../../utils/design_tokens.dart';
import '../../utils/helpers.dart';
import '../../services/services.dart';
import '../../models/models.dart';
import '../../widgets/common_widgets.dart';
import '../dashboard/dashboard_screen.dart';
import '../students/student_list_screen.dart';

class BatchListScreen extends ConsumerStatefulWidget {
  final bool showCreateDialog;

  const BatchListScreen({
    super.key,
    this.showCreateDialog = false,
  });

  @override
  ConsumerState<BatchListScreen> createState() => _BatchListScreenState();
}

class _BatchListScreenState extends ConsumerState<BatchListScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.showCreateDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCreateBatchDialog();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showCreateBatchDialog() async {
    final result = await showDialog<Batch>(
      context: context,
      builder: (context) => const _CreateBatchDialog(),
    );

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Batch "${result.name}" created successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final batches = ref.watch(dashboardBatchesProvider);
    final teacher = ref.watch(currentTeacherProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batches'),
        automaticallyImplyLeading: false,
      ),
      body: batches.when(
        data: (batchList) {
          if (batchList.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.groups_outlined,
              title: 'No Batches Yet',
              subtitle: 'Create your first batch to get started',
              action: ElevatedButton.icon(
                onPressed: _showCreateBatchDialog,
                icon: const Icon(Icons.add),
                label: const Text('Create Batch'),
              ),
            );
          }

          // Filter batches by search query
          final filteredBatches = _searchQuery.isEmpty
              ? batchList
              : batchList.where((batch) {
                  final query = _searchQuery.toLowerCase();
                  return batch.name.toLowerCase().contains(query) ||
                      (batch.subject?.toLowerCase().contains(query) ?? false);
                }).toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardBatchesProvider);
            },
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search batches...',
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
                // Batch count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        '${filteredBatches.length} batch${filteredBatches.length == 1 ? '' : 'es'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (_searchQuery.isNotEmpty) ...[
                        Text(
                          ' (filtered from ${batchList.length})',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Batch list
                Expanded(
                  child: filteredBatches.isEmpty
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
                                'No batches found',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: filteredBatches.length,
                          itemBuilder: (context, index) {
                            final batch = filteredBatches[index];
                            return _BatchListItem(
                              batch: batch,
                              instituteId: teacher!.instituteId,
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
        loading: () => const ShimmerListLoading(type: ShimmerListType.batch),
        error: (error, stack) => ErrorStateWidget(
          error: error,
          onRetry: () => ref.invalidate(dashboardBatchesProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateBatchDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Batch'),
      ),
    );
  }
}

class _BatchListItem extends StatelessWidget {
  final Batch batch;
  final String instituteId;

  const _BatchListItem({
    required this.batch,
    required this.instituteId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentListScreen(
                batch: batch,
                instituteId: instituteId,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.groups,
                  color: AppColors.primary,
                  size: 28,
                ),
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
                    if (batch.subject != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        batch.subject!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      batch.formattedSchedule,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateBatchDialog extends ConsumerStatefulWidget {
  const _CreateBatchDialog();

  @override
  ConsumerState<_CreateBatchDialog> createState() => _CreateBatchDialogState();
}

class _CreateBatchDialogState extends ConsumerState<_CreateBatchDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _subjectController = TextEditingController();

  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  final Set<String> _selectedDays = {};
  bool _isLoading = false;

  final _weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(bool isStart) async {
    final time = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (time != null) {
      setState(() {
        if (isStart) {
          _startTime = time;
        } else {
          _endTime = time;
        }
      });
    }
  }

  Future<void> _createBatch() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one day'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final teacher = ref.read(currentTeacherProvider).value;
      if (teacher == null) throw Exception('Not logged in');

      final firestoreService = ref.read(firestoreServiceProvider);

      final batch = Batch(
        id: '',
        instituteId: teacher.instituteId,
        name: _nameController.text.trim(),
        subject: _subjectController.text.trim().isEmpty
            ? null
            : _subjectController.text.trim(),
        scheduleDays: _selectedDays.toList()..sort((a, b) => _weekDays.indexOf(a).compareTo(_weekDays.indexOf(b))),
        startTime: ScheduleTime(hour: _startTime.hour, minute: _startTime.minute),
        endTime: ScheduleTime(hour: _endTime.hour, minute: _endTime.minute),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final batchId = await firestoreService.createBatch(teacher.instituteId, batch);

      // Add audit log
      await firestoreService.addAuditLog(AuditLog.create(
        instituteId: teacher.instituteId,
        userId: teacher.id,
        userName: teacher.name,
        action: AuditAction.batchCreate,
        metadata: {
          'batchId': batchId,
          'batchName': batch.name,
        },
      ));

      if (mounted) {
        Navigator.pop(context, batch.copyWith(id: batchId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHelpers.getActionError('create batch', e)),
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
      title: const Text('Create New Batch'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Batch name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Batch Name *',
                  hintText: 'e.g., Class 10 Maths - Morning',
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a batch name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Subject (optional)
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject (Optional)',
                  hintText: 'e.g., Mathematics',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Schedule days
              const Text(
                'Schedule Days *',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _weekDays.map((day) {
                  final isSelected = _selectedDays.contains(day.toLowerCase());
                  return FilterChip(
                    label: Text(day.substring(0, 3)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedDays.add(day.toLowerCase());
                        } else {
                          _selectedDays.remove(day.toLowerCase());
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Time selection
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Start Time',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: Text(
                          _startTime.format(context),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'End Time',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: Text(
                          _endTime.format(context),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        LoadingButton(
          isLoading: _isLoading,
          onPressed: _createBatch,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

extension TimeOfDayExtension on TimeOfDay {
  String format(BuildContext context) {
    final hour = this.hour % 12 == 0 ? 12 : this.hour % 12;
    final period = this.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }
}
