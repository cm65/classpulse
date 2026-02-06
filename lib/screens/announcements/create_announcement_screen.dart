import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../providers/parent_providers.dart';
import '../../providers/providers.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';

/// Screen for creating or editing announcements
class CreateAnnouncementScreen extends ConsumerStatefulWidget {
  final String instituteId;
  final String teacherId;
  final Announcement? announcement; // null for new, non-null for edit

  const CreateAnnouncementScreen({
    super.key,
    required this.instituteId,
    required this.teacherId,
    this.announcement,
  });

  @override
  ConsumerState<CreateAnnouncementScreen> createState() => _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends ConsumerState<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  AnnouncementPriority _priority = AnnouncementPriority.normal;
  List<String> _selectedBatchIds = [];
  bool _targetAllBatches = true;
  DateTime? _expiresAt;
  bool _isLoading = false;

  bool get _isEditing => widget.announcement != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.announcement!.title;
      _contentController.text = widget.announcement!.content;
      _priority = widget.announcement!.priority;
      _expiresAt = widget.announcement!.expiresAt;
      if (widget.announcement!.targetBatchIds != null) {
        _targetAllBatches = false;
        _selectedBatchIds = List.from(widget.announcement!.targetBatchIds!);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _selectExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _expiresAt = picked);
    }
  }

  Future<void> _save({bool publish = false}) async {
    if (!_formKey.currentState!.validate()) return;

    if (!_targetAllBatches && _selectedBatchIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one batch'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      bool success;

      if (_isEditing) {
        success = await ref.read(announcementNotifierProvider.notifier).updateAnnouncement(
          widget.announcement!.id,
          {
            'title': _titleController.text.trim(),
            'content': _contentController.text.trim(),
            'priority': _priority.name,
            'targetBatchIds': _targetAllBatches ? null : _selectedBatchIds,
            'expiresAt': _expiresAt,
            if (publish) 'isPublished': true,
            if (publish) 'publishedAt': DateTime.now(),
          },
        );
      } else {
        success = await ref.read(announcementNotifierProvider.notifier).createAnnouncement(
              instituteId: widget.instituteId,
              title: _titleController.text.trim(),
              content: _contentController.text.trim(),
              createdBy: widget.teacherId,
              priority: _priority,
              targetBatchIds: _targetAllBatches ? null : _selectedBatchIds,
              expiresAt: _expiresAt,
              publish: publish,
            );
      }

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(publish ? 'Announcement published!' : 'Announcement saved!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save announcement'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHelpers.getActionError('save announcement', e)),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(batchesProvider(widget.instituteId));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Announcement' : 'New Announcement'),
        actions: [
          if (_isEditing && !widget.announcement!.isPublished)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Announcement'),
                    content: const Text('Are you sure you want to delete this announcement?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.absent,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref
                      .read(announcementNotifierProvider.notifier)
                      .deleteAnnouncement(widget.announcement!.id);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter announcement title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Content
              TextFormField(
                controller: _contentController,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'Content',
                  hintText: 'Enter announcement content...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter content';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Priority
              Text(
                'Priority',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: AnnouncementPriority.values.map((priority) {
                  final isSelected = _priority == priority;
                  Color color;
                  switch (priority) {
                    case AnnouncementPriority.urgent:
                      color = Colors.red;
                      break;
                    case AnnouncementPriority.high:
                      color = Colors.orange;
                      break;
                    case AnnouncementPriority.normal:
                      color = AppColors.primary;
                      break;
                    case AnnouncementPriority.low:
                      color = AppColors.textSecondary;
                      break;
                  }
                  return ChoiceChip(
                    label: Text(priority.displayName),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _priority = priority);
                    },
                    selectedColor: color.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? color : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Target batches
              Text(
                'Target Audience',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Send to all batches'),
                value: _targetAllBatches,
                onChanged: (value) => setState(() => _targetAllBatches = value),
                contentPadding: EdgeInsets.zero,
              ),
              if (!_targetAllBatches)
                batchesAsync.when(
                  data: (batches) => Column(
                    children: batches.map((batch) {
                      final isSelected = _selectedBatchIds.contains(batch.id);
                      return CheckboxListTile(
                        title: Text(batch.name),
                        value: isSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedBatchIds.add(batch.id);
                            } else {
                              _selectedBatchIds.remove(batch.id);
                            }
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      );
                    }).toList(),
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (e, s) => const Text('Failed to load batches'),
                ),
              const SizedBox(height: 16),

              // Expiry date
              Text(
                'Expiry Date (Optional)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectExpiryDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _expiresAt != null
                              ? '${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}'
                              : 'No expiry date',
                          style: TextStyle(
                            color: _expiresAt != null ? null : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (_expiresAt != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _expiresAt = null),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Action buttons
              if (!_isEditing || !widget.announcement!.isPublished) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => _save(publish: false),
                        child: const Text('Save as Draft'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => _save(publish: true),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Publish Now'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _save(publish: false),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Update Announcement'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
