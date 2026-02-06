import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../services/services.dart';
import '../../models/models.dart';
import '../../widgets/common_widgets.dart';

class TeacherManagementScreen extends ConsumerStatefulWidget {
  final String instituteId;
  final String instituteName;

  const TeacherManagementScreen({
    super.key,
    required this.instituteId,
    required this.instituteName,
  });

  @override
  ConsumerState<TeacherManagementScreen> createState() =>
      _TeacherManagementScreenState();
}

class _TeacherManagementScreenState
    extends ConsumerState<TeacherManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        title: const Text('Manage Teachers'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Teachers'),
            Tab(text: 'Pending Invites'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TeachersTab(instituteId: widget.instituteId),
          _PendingInvitesTab(instituteId: widget.instituteId),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInviteDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Invite Teacher'),
      ),
    );
  }

  void _showInviteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _InviteTeacherDialog(
        instituteId: widget.instituteId,
        instituteName: widget.instituteName,
      ),
    );
  }
}

class _TeachersTab extends ConsumerWidget {
  final String instituteId;

  const _TeachersTab({required this.instituteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTeacher = ref.watch(currentTeacherProvider).value;
    final teachersAsync = ref.watch(
      StreamProvider((ref) =>
          ref.watch(firestoreServiceProvider).teachersStream(instituteId)),
    );

    return teachersAsync.when(
      data: (teachers) {
        if (teachers.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.people_outline,
            title: 'No Teachers',
            subtitle: 'Invite teachers to help manage attendance',
          );
        }

        // Sort: admins first, then by name
        final sorted = List<Teacher>.from(teachers)
          ..sort((a, b) {
            if (a.role.isAdmin != b.role.isAdmin) {
              return a.role.isAdmin ? -1 : 1;
            }
            return a.name.compareTo(b.name);
          });

        return RefreshIndicator(
          onRefresh: () async {
            // StreamProvider auto-updates, but this provides visual feedback
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final teacher = sorted[index];
              final isCurrentUser = teacher.id == currentTeacher?.id;
              final canManage =
                  currentTeacher?.canManageTeachers == true && !isCurrentUser;

              return _TeacherListItem(
                teacher: teacher,
                isCurrentUser: isCurrentUser,
                canManage: canManage,
              );
            },
          ),
        );
      },
      loading: () => const ShimmerListLoading(type: ShimmerListType.student, itemCount: 3),
      error: (error, stack) => ErrorStateWidget(
        error: error,
        compact: true,
      ),
    );
  }
}

class _TeacherListItem extends ConsumerWidget {
  final Teacher teacher;
  final bool isCurrentUser;
  final bool canManage;

  const _TeacherListItem({
    required this.teacher,
    required this.isCurrentUser,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: teacher.role.isAdmin
            ? AppColors.primary.withOpacity(0.1)
            : AppColors.textHint.withOpacity(0.1),
        child: Text(
          teacher.name.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: teacher.role.isAdmin ? AppColors.primary : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      title: Row(
        children: [
          Text(teacher.name),
          if (isCurrentUser) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'You',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.success,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(teacher.phone),
          const SizedBox(height: 2),
          _RoleBadge(role: teacher.role),
        ],
      ),
      isThreeLine: true,
      trailing: canManage
          ? PopupMenuButton<String>(
              onSelected: (value) => _handleAction(context, ref, value),
              itemBuilder: (context) => [
                if (!teacher.role.isAdmin)
                  const PopupMenuItem(
                    value: 'promote',
                    child: ListTile(
                      leading: Icon(Icons.arrow_upward, color: AppColors.primary),
                      title: Text('Make Admin'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                if (teacher.role.isAdmin)
                  const PopupMenuItem(
                    value: 'demote',
                    child: ListTile(
                      leading: Icon(Icons.arrow_downward),
                      title: Text('Remove Admin'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                const PopupMenuItem(
                  value: 'remove',
                  child: ListTile(
                    leading: Icon(Icons.person_remove, color: AppColors.error),
                    title: Text('Remove', style: TextStyle(color: AppColors.error)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            )
          : null,
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) async {
    final firestoreService = ref.read(firestoreServiceProvider);

    switch (action) {
      case 'promote':
        final confirmed = await showConfirmationDialog(
          context: context,
          title: 'Make Admin',
          message: 'Make ${teacher.name} an admin? They will have full access to manage the institute.',
          confirmText: 'Make Admin',
        );
        if (confirmed) {
          await firestoreService.updateTeacherRole(teacher.id, TeacherRole.admin);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${teacher.name} is now an admin')),
            );
          }
        }
        break;

      case 'demote':
        final confirmed = await showConfirmationDialog(
          context: context,
          title: 'Remove Admin',
          message: 'Remove admin privileges from ${teacher.name}? They will only be able to mark attendance.',
          confirmText: 'Remove Admin',
        );
        if (confirmed) {
          await firestoreService.updateTeacherRole(teacher.id, TeacherRole.teacher);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${teacher.name} is no longer an admin')),
            );
          }
        }
        break;

      case 'remove':
        final confirmed = await showConfirmationDialog(
          context: context,
          title: 'Remove Teacher',
          message: 'Remove ${teacher.name} from the institute? They will no longer be able to access this institute.',
          confirmText: 'Remove',
          isDangerous: true,
        );
        if (confirmed) {
          await firestoreService.removeTeacher(teacher.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${teacher.name} has been removed')),
            );
          }
        }
        break;
    }
  }
}

class _RoleBadge extends StatelessWidget {
  final TeacherRole role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final isAdmin = role.isAdmin;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isAdmin
            ? AppColors.primary.withOpacity(0.1)
            : AppColors.textHint.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        role.displayName,
        style: TextStyle(
          fontSize: 11,
          color: isAdmin ? AppColors.primary : AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _PendingInvitesTab extends ConsumerWidget {
  final String instituteId;

  const _PendingInvitesTab({required this.instituteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitationsAsync = ref.watch(
      StreamProvider((ref) => ref
          .watch(firestoreServiceProvider)
          .pendingInvitationsStream(instituteId)),
    );

    return invitationsAsync.when(
      data: (invitations) {
        if (invitations.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.mail_outline,
            title: 'No Pending Invites',
            subtitle: 'Invited teachers will appear here until they register',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // StreamProvider auto-updates, but this provides visual feedback
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: invitations.length,
            itemBuilder: (context, index) {
              final invitation = invitations[index];
              return _InvitationListItem(invitation: invitation);
            },
          ),
        );
      },
      loading: () => const ShimmerListLoading(type: ShimmerListType.student, itemCount: 3),
      error: (error, stack) => ErrorStateWidget(
        error: error,
        compact: true,
      ),
    );
  }
}

class _InvitationListItem extends ConsumerWidget {
  final TeacherInvitation invitation;

  const _InvitationListItem({required this.invitation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remainingDays = invitation.expiresAt.difference(DateTime.now()).inDays;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.warning.withOpacity(0.1),
        child: const Icon(
          Icons.hourglass_top,
          color: AppColors.warning,
          size: 20,
        ),
      ),
      title: Text(invitation.phone),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RoleBadge(role: invitation.role),
          const SizedBox(height: 4),
          Text(
            'Expires in $remainingDays day${remainingDays == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 12,
              color: remainingDays <= 1 ? AppColors.error : AppColors.textSecondary,
            ),
          ),
        ],
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Resend SMS',
            onPressed: () => _resendInvitation(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.error),
            tooltip: 'Cancel',
            onPressed: () => _cancelInvitation(context, ref),
          ),
        ],
      ),
    );
  }

  void _resendInvitation(BuildContext context, WidgetRef ref) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
      final callable = functions.httpsCallable('resendTeacherInvitation');

      await callable.call({'invitationId': invitation.id});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation SMS resent'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHelpers.getActionError('resend invitation', e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _cancelInvitation(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Cancel Invitation',
      message: 'Cancel the invitation to ${invitation.phone}?',
      confirmText: 'Cancel Invitation',
      isDangerous: true,
    );

    if (confirmed) {
      await ref.read(firestoreServiceProvider).cancelInvitation(invitation.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation cancelled')),
        );
      }
    }
  }
}

class _InviteTeacherDialog extends ConsumerStatefulWidget {
  final String instituteId;
  final String instituteName;

  const _InviteTeacherDialog({
    required this.instituteId,
    required this.instituteName,
  });

  @override
  ConsumerState<_InviteTeacherDialog> createState() =>
      _InviteTeacherDialogState();
}

class _InviteTeacherDialogState extends ConsumerState<_InviteTeacherDialog> {
  final _phoneController = TextEditingController();
  TeacherRole _selectedRole = TeacherRole.teacher;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite Teacher'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the teacher\'s phone number. They will receive an SMS with a link to download the app and join your institute.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: '9876543210',
                prefixText: '+91 ',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              maxLength: 10,
            ),
            const SizedBox(height: 16),
            const Text(
              'Role',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            RadioListTile<TeacherRole>(
              title: const Text('Teacher'),
              subtitle: const Text('Can only mark attendance'),
              value: TeacherRole.teacher,
              groupValue: _selectedRole,
              onChanged: (value) {
                setState(() => _selectedRole = value!);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            RadioListTile<TeacherRole>(
              title: const Text('Admin'),
              subtitle: const Text('Full access to manage institute'),
              value: TeacherRole.admin,
              groupValue: _selectedRole,
              onChanged: (value) {
                setState(() => _selectedRole = value!);
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _sendInvitation,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send Invitation'),
        ),
      ],
    );
  }

  void _sendInvitation() async {
    final phone = _phoneController.text.trim();

    // Validate phone
    if (phone.isEmpty) {
      setState(() => _error = 'Please enter a phone number');
      return;
    }

    if (phone.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      setState(() => _error = 'Enter a valid 10-digit Indian phone number');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final teacher = ref.read(currentTeacherProvider).value;
      if (teacher == null) throw Exception('Not logged in');

      final invitation = TeacherInvitation(
        id: '', // Will be assigned by Firestore
        instituteId: widget.instituteId,
        instituteName: widget.instituteName,
        phone: phone,
        role: _selectedRole,
        invitedBy: teacher.id,
        invitedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );

      await ref.read(firestoreServiceProvider).createTeacherInvitation(invitation);

      // Log the action
      await ref.read(firestoreServiceProvider).addAuditLog(AuditLog(
        id: '',
        instituteId: widget.instituteId,
        userId: teacher.id,
        userName: teacher.name,
        action: AuditAction.teacherInvite,
        timestamp: DateTime.now(),
        metadata: {'phone': phone, 'role': _selectedRole.name},
      ));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invitation sent to +91 $phone'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = ErrorHelpers.getUserFriendlyMessage(e);
      });
    }
  }
}
