import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../services/services.dart';
import '../../models/models.dart';

class EditInstituteScreen extends ConsumerStatefulWidget {
  final Institute institute;

  const EditInstituteScreen({super.key, required this.institute});

  @override
  ConsumerState<EditInstituteScreen> createState() => _EditInstituteScreenState();
}

class _EditInstituteScreenState extends ConsumerState<EditInstituteScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.institute.name);
    _emailController = TextEditingController(text: widget.institute.email);
    _phoneController = TextEditingController(text: widget.institute.phone);
    _addressController = TextEditingController(text: widget.institute.address ?? '');

    // Track changes
    _nameController.addListener(_onChanged);
    _emailController.addListener(_onChanged);
    _phoneController.addListener(_onChanged);
    _addressController.addListener(_onChanged);
  }

  void _onChanged() {
    final hasChanges = _nameController.text != widget.institute.name ||
        _emailController.text != widget.institute.email ||
        _phoneController.text != widget.institute.phone ||
        _addressController.text != (widget.institute.address ?? '');

    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Institute'),
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Institute Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Institute Name',
                hintText: 'e.g., ABC Coaching Centre',
                prefixIcon: Icon(Icons.school),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Institute name is required';
                }
                if (value.trim().length < 3) {
                  return 'Name must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Email
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'institute@example.com',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required';
                }
                final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!emailRegex.hasMatch(value.trim())) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Phone (display only - linked to admin account)
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Contact Phone',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
                helperText: 'Contact number for parents',
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Phone number is required';
                }
                final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
                if (cleaned.length != 10) {
                  return 'Enter a valid 10-digit phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Address
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address (Optional)',
                hintText: 'e.g., 123 Main Street, City',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),

            // Info card
            Card(
              color: AppColors.primary.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Institute name and contact details appear in notification messages sent to parents.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final teacher = ref.read(currentTeacherProvider).value;
      if (teacher == null) throw Exception('Not logged in');

      await ref.read(firestoreServiceProvider).updateInstitute(
        widget.institute.id,
        {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
        },
      );

      // Log the action
      await ref.read(firestoreServiceProvider).addAuditLog(AuditLog.create(
        instituteId: widget.institute.id,
        userId: teacher.id,
        userName: teacher.name,
        action: AuditAction.settingsChange,
        metadata: {'type': 'institute_profile'},
      ));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Institute profile updated'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHelpers.getActionError('save changes', e)),
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
