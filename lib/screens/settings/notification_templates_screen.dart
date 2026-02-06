import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../services/services.dart';
import '../../models/models.dart';

class NotificationTemplatesScreen extends ConsumerStatefulWidget {
  final Institute institute;

  const NotificationTemplatesScreen({super.key, required this.institute});

  @override
  ConsumerState<NotificationTemplatesScreen> createState() =>
      _NotificationTemplatesScreenState();
}

class _NotificationTemplatesScreenState
    extends ConsumerState<NotificationTemplatesScreen> {
  late TextEditingController _presentController;
  late TextEditingController _absentController;
  late TextEditingController _lateController;
  late TextEditingController _smsController;
  bool _isLoading = false;
  bool _hasChanges = false;
  String? _previewTemplate;

  @override
  void initState() {
    super.initState();
    final templates = widget.institute.settings.notificationTemplates;
    _presentController = TextEditingController(text: templates.presentTemplate);
    _absentController = TextEditingController(text: templates.absentTemplate);
    _lateController = TextEditingController(text: templates.lateTemplate);
    _smsController = TextEditingController(text: templates.smsTemplate);

    _presentController.addListener(_onChanged);
    _absentController.addListener(_onChanged);
    _lateController.addListener(_onChanged);
    _smsController.addListener(_onChanged);
  }

  void _onChanged() {
    final templates = widget.institute.settings.notificationTemplates;
    final hasChanges = _presentController.text != templates.presentTemplate ||
        _absentController.text != templates.absentTemplate ||
        _lateController.text != templates.lateTemplate ||
        _smsController.text != templates.smsTemplate;

    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  @override
  void dispose() {
    _presentController.dispose();
    _absentController.dispose();
    _lateController.dispose();
    _smsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Templates'),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isLoading ? null : _saveChanges,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Placeholders help card
          Card(
            color: AppColors.primary.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Available Placeholders',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PlaceholderChip(label: '{student}', description: 'Student name'),
                      _PlaceholderChip(label: '{batch}', description: 'Batch/class name'),
                      _PlaceholderChip(label: '{date}', description: 'Attendance date'),
                      _PlaceholderChip(label: '{time}', description: 'Class time'),
                      _PlaceholderChip(label: '{status}', description: 'Attendance status'),
                      _PlaceholderChip(label: '{institute}', description: 'Institute name'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // WhatsApp Templates section
          Text(
            'WhatsApp Messages',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // Present template
          _TemplateField(
            label: 'Present',
            icon: Icons.check_circle,
            iconColor: AppColors.success,
            controller: _presentController,
            onPreview: () => _showPreview(_presentController.text, 'present'),
          ),
          const SizedBox(height: 16),

          // Absent template
          _TemplateField(
            label: 'Absent',
            icon: Icons.cancel,
            iconColor: AppColors.error,
            controller: _absentController,
            onPreview: () => _showPreview(_absentController.text, 'absent'),
          ),
          const SizedBox(height: 16),

          // Late template
          _TemplateField(
            label: 'Late',
            icon: Icons.access_time,
            iconColor: AppColors.warning,
            controller: _lateController,
            onPreview: () => _showPreview(_lateController.text, 'late'),
          ),
          const SizedBox(height: 24),

          // SMS Template section
          Text(
            'SMS Message (Fallback)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Keep SMS short (160 characters recommended)',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 12),

          _TemplateField(
            label: 'SMS',
            icon: Icons.sms,
            iconColor: AppColors.primary,
            controller: _smsController,
            onPreview: () => _showPreview(_smsController.text, 'absent'),
            maxLines: 2,
            showCharCount: true,
          ),
          const SizedBox(height: 24),

          // Reset to defaults button
          OutlinedButton.icon(
            onPressed: _resetToDefaults,
            icon: const Icon(Icons.restore),
            label: const Text('Reset to Defaults'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showPreview(String template, String status) {
    final sampleData = {
      'student': 'Rahul Sharma',
      'batch': 'Class 10 Maths',
      'date': '21 Jan 2026',
      'time': '10:30 AM',
      'status': status.toUpperCase(),
      'institute': widget.institute.name,
    };

    String preview = template;
    sampleData.forEach((key, value) {
      preview = preview.replaceAll('{$key}', value);
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.visibility, size: 20),
            const SizedBox(width: 8),
            const Text('Preview'),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            preview,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Templates'),
        content: const Text(
          'Reset all notification templates to their default values?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final defaults = NotificationTemplates();
      setState(() {
        _presentController.text = defaults.presentTemplate;
        _absentController.text = defaults.absentTemplate;
        _lateController.text = defaults.lateTemplate;
        _smsController.text = defaults.smsTemplate;
      });
    }
  }

  void _saveChanges() async {
    setState(() => _isLoading = true);

    try {
      final teacher = ref.read(currentTeacherProvider).value;
      if (teacher == null) throw Exception('Not logged in');

      await ref.read(firestoreServiceProvider).updateInstitute(
        widget.institute.id,
        {
          'settings.notificationTemplates': {
            'presentTemplate': _presentController.text,
            'absentTemplate': _absentController.text,
            'lateTemplate': _lateController.text,
            'smsTemplate': _smsController.text,
          },
        },
      );

      // Log the action
      await ref.read(firestoreServiceProvider).addAuditLog(AuditLog.create(
        instituteId: widget.institute.id,
        userId: teacher.id,
        userName: teacher.name,
        action: AuditAction.settingsChange,
        metadata: {'type': 'notification_templates'},
      ));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification templates saved'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHelpers.getActionError('save template', e)),
            backgroundColor: AppColors.error,
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

class _PlaceholderChip extends StatelessWidget {
  final String label;
  final String description;

  const _PlaceholderChip({required this.label, required this.description});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: description,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: AppColors.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TemplateField extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final TextEditingController controller;
  final VoidCallback onPreview;
  final int maxLines;
  final bool showCharCount;

  const _TemplateField({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.controller,
    required this.onPreview,
    this.maxLines = 3,
    this.showCharCount = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onPreview,
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('Preview'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: 'Enter message template...',
            border: const OutlineInputBorder(),
            counterText: showCharCount ? null : '',
          ),
          maxLength: showCharCount ? 160 : null,
        ),
      ],
    );
  }
}
