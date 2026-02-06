import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../services/services.dart';
import '../../models/models.dart';
import '../../widgets/common_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _instituteNameController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  TeacherInvitation? _pendingInvitation;
  bool _checkingInvitation = true;

  @override
  void initState() {
    super.initState();
    _checkForInvitation();
  }

  @override
  void dispose() {
    _instituteNameController.dispose();
    _adminNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _checkForInvitation() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final authService = ref.read(authServiceProvider);
    final invitation = await authService.getPendingInvitation(user.phoneNumber ?? '');

    setState(() {
      _pendingInvitation = invitation;
      _checkingInvitation = false;
    });
  }

  Future<void> _acceptInvitation() async {
    if (_pendingInvitation == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) throw Exception('Not logged in');

      final authService = ref.read(authServiceProvider);
      await authService.acceptInvitation(
        uid: user.uid,
        name: _adminNameController.text.trim(),
        invitation: _pendingInvitation!,
      );

      // Navigation handled by AuthWrapper
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorHelpers.getUserFriendlyMessage(e);
      });
    }
  }

  Future<void> _registerNewInstitute() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) throw Exception('Not logged in');

      final firestoreService = ref.read(firestoreServiceProvider);
      final authService = ref.read(authServiceProvider);

      // Create institute
      final institute = Institute(
        id: '', // Will be set by Firestore
        name: _instituteNameController.text.trim(),
        adminName: _adminNameController.text.trim(),
        phone: user.phoneNumber ?? '',
        email: _emailController.text.trim(),
        settings: InstituteSettings(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final instituteId = await firestoreService.createInstitute(institute);

      // Create teacher record with admin role
      final teacher = Teacher(
        id: user.uid,
        instituteId: instituteId,
        name: _adminNameController.text.trim(),
        phone: user.phoneNumber ?? '',
        role: TeacherRole.admin,
        createdAt: DateTime.now(),
      );

      await authService.createTeacher(teacher);

      // Add audit log
      await firestoreService.addAuditLog(AuditLog.create(
        instituteId: instituteId,
        userId: user.uid,
        userName: teacher.name,
        action: AuditAction.login,
        metadata: {'type': 'initial_registration'},
      ));

      // Navigation handled by AuthWrapper
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorHelpers.getUserFriendlyMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingInvitation) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_pendingInvitation != null
            ? 'Join Institute'
            : 'Register Institute'),
        actions: [
          TextButton(
            onPressed: () async {
              final confirmed = await showConfirmationDialog(
                context: context,
                title: 'Sign Out',
                message: 'Are you sure you want to sign out?',
                confirmText: 'Sign Out',
              );
              if (confirmed) {
                ref.read(authServiceProvider).signOut();
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_pendingInvitation != null) ...[
                  _buildInvitationCard(),
                  const SizedBox(height: 24),
                ],

                _buildNameField(),
                const SizedBox(height: 16),

                if (_pendingInvitation == null) ...[
                  _buildInstituteNameField(),
                  const SizedBox(height: 16),
                  _buildEmailField(),
                  const SizedBox(height: 16),
                ],

                if (_errorMessage != null) ...[
                  _buildErrorMessage(),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 8),

                LoadingButton(
                  isLoading: _isLoading,
                  onPressed: _pendingInvitation != null
                      ? _acceptInvitation
                      : _registerNewInstitute,
                  child: Text(_pendingInvitation != null
                      ? 'Join Institute'
                      : 'Register Institute'),
                ),

                if (_pendingInvitation != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _pendingInvitation = null;
                      });
                    },
                    child: const Text('Create New Institute Instead'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvitationCard() {
    return Card(
      color: AppColors.primaryLight.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.mail_outline,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'You have a pending invitation!',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'You have been invited to join:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              _pendingInvitation!.instituteName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Role: ${_pendingInvitation!.role.displayName}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Name',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _adminNameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Enter your full name',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your name';
            }
            if (value.trim().length < 2) {
              return 'Name must be at least 2 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildInstituteNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Institute Name',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _instituteNameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'e.g., ABC Coaching Centre',
            prefixIcon: Icon(Icons.school_outlined),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter institute name';
            }
            if (value.trim().length < 3) {
              return 'Institute name must be at least 3 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email (Optional)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'institute@example.com',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email address';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
