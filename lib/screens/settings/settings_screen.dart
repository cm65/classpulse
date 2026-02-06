import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import '../../services/services.dart';
import '../../models/models.dart';
import '../../widgets/common_widgets.dart';
import '../dashboard/dashboard_screen.dart';
import 'teacher_management_screen.dart';
import 'edit_institute_screen.dart';
import 'notification_templates_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacher = ref.watch(currentTeacherProvider).value;
    final institute = ref.watch(currentInstituteProvider).value;

    if (teacher == null || institute == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final isAdmin = teacher.role.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          // Profile section
          _SectionHeader(title: 'Profile'),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(
                teacher.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            title: Text(teacher.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(teacher.phone),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAdmin ? AppColors.primary.withOpacity(0.1) : AppColors.textHint.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    teacher.role.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      color: isAdmin ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to profile edit
            },
          ),
          const Divider(),

          // Institute section (Admin only)
          if (isAdmin) ...[
            _SectionHeader(title: 'Institute'),
            ListTile(
              leading: const Icon(Icons.school),
              title: Text(institute.name),
              subtitle: Text(institute.email),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  PageTransitions.slideRight(
                    EditInstituteScreen(institute: institute),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Manage Teachers'),
              subtitle: const Text('Add or remove teachers'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  PageTransitions.slideRight(
                    TeacherManagementScreen(
                      instituteId: teacher.instituteId,
                      instituteName: institute.name,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active),
              title: const Text('Notification Templates'),
              subtitle: const Text('Customize message formats'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  PageTransitions.slideRight(
                    NotificationTemplatesScreen(institute: institute),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('Attendance Edit Window'),
              subtitle: Text('${institute.settings.attendanceEditWindow.inMinutes} minutes'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showEditWindowDialog(context, ref, institute);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Audit Log'),
              subtitle: const Text('View activity history'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  PageTransitions.slideRight(
                    _AuditLogScreen(instituteId: teacher.instituteId),
                  ),
                );
              },
            ),
            const Divider(),
          ],

          // App section
          _SectionHeader(title: 'App'),
          _ThemeModeTile(),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                PageTransitions.slideRight(const _HelpSupportScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            subtitle: const Text('Version 1.0.0'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'ClassPulse',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2025 ClassPulse\nKeep a pulse on every student',
              );
            },
          ),
          const Divider(),

          // Sign out
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text(
              'Sign Out',
              style: TextStyle(color: AppColors.error),
            ),
            onTap: () async {
              final confirmed = await showConfirmationDialog(
                context: context,
                title: 'Sign Out',
                message: 'Are you sure you want to sign out?',
                confirmText: 'Sign Out',
                isDangerous: true,
              );
              if (confirmed) {
                ref.read(authServiceProvider).signOut();
              }
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showEditWindowDialog(BuildContext context, WidgetRef ref, Institute institute) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attendance Edit Window'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How long can teachers edit attendance after submission?'),
            const SizedBox(height: 16),
            ...[30, 60, 120, 1440].map((minutes) {
              final label = minutes == 1440
                  ? 'Same day'
                  : minutes >= 60
                      ? '${minutes ~/ 60} hour${minutes >= 120 ? 's' : ''}'
                      : '$minutes minutes';
              final isSelected = institute.settings.attendanceEditWindow.inMinutes == minutes;

              return RadioListTile<int>(
                title: Text(label),
                value: minutes,
                groupValue: institute.settings.attendanceEditWindow.inMinutes,
                onChanged: (value) async {
                  if (value != null) {
                    await ref.read(firestoreServiceProvider).updateInstitute(
                      institute.id,
                      {
                        'settings.attendanceEditWindowMinutes': value,
                      },
                    );
                    Navigator.pop(context);
                  }
                },
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _AuditLogScreen extends ConsumerWidget {
  final String instituteId;

  const _AuditLogScreen({required this.instituteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditLogs = ref.watch(
      StreamProvider((ref) => ref.watch(firestoreServiceProvider).auditLogsStream(instituteId)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Log'),
      ),
      body: auditLogs.when(
        data: (logs) {
          if (logs.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.history,
              title: 'No Activity Yet',
              subtitle: 'Activity will appear here as you use the app',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Icon(
                    _getActionIcon(log.action),
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                title: Text(log.action.displayName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('by ${log.userName}'),
                    Text(
                      _formatTimestamp(log.timestamp),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const ShimmerListLoading(type: ShimmerListType.simple, itemCount: 5),
        error: (error, stack) => ErrorStateWidget(
          error: error,
          compact: true,
        ),
      ),
    );
  }

  IconData _getActionIcon(AuditAction action) {
    switch (action) {
      case AuditAction.attendanceMark:
      case AuditAction.attendanceSubmit:
      case AuditAction.attendanceEdit:
        return Icons.fact_check;
      case AuditAction.studentAdd:
      case AuditAction.studentEdit:
      case AuditAction.studentDelete:
        return Icons.person;
      case AuditAction.batchCreate:
      case AuditAction.batchEdit:
      case AuditAction.batchDelete:
        return Icons.groups;
      case AuditAction.teacherInvite:
      case AuditAction.teacherRemove:
        return Icons.person_add;
      case AuditAction.settingsChange:
        return Icons.settings;
      case AuditAction.login:
      case AuditAction.logout:
        return Icons.login;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}

class _HelpSupportScreen extends StatelessWidget {
  const _HelpSupportScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quick start section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.rocket_launch, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Quick Start Guide',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _QuickStartStep(
                    number: '1',
                    title: 'Create a Batch',
                    description: 'Go to Batches tab and tap the + button to create a new class batch.',
                  ),
                  _QuickStartStep(
                    number: '2',
                    title: 'Add Students',
                    description: 'Open a batch and add students manually or import from CSV.',
                  ),
                  _QuickStartStep(
                    number: '3',
                    title: 'Mark Attendance',
                    description: 'Tap on a batch from the Home screen to mark today\'s attendance.',
                  ),
                  _QuickStartStep(
                    number: '4',
                    title: 'View Reports',
                    description: 'Check the Reports tab for daily summaries and student history.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // FAQ section
          Text(
            'Frequently Asked Questions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          _FaqItem(
            question: 'How do I import students from CSV?',
            answer: 'Open a batch, tap the upload icon in the app bar, and select your CSV file. '
                'The CSV should have columns: Name, Phone Number, Student ID (optional). '
                'The first row should be headers.',
          ),
          _FaqItem(
            question: 'Can I edit attendance after submission?',
            answer: 'Yes, you can edit attendance within the time window set by your institute admin. '
                'Go to Reports > Daily Summary and tap on a batch to edit.',
          ),
          _FaqItem(
            question: 'How do parent notifications work?',
            answer: 'When attendance is submitted, parents of absent students receive WhatsApp/SMS notifications. '
                'You can customize message templates in Settings > Notification Templates.',
          ),
          _FaqItem(
            question: 'How do I add another teacher?',
            answer: 'Only admins can add teachers. Go to Settings > Manage Teachers and tap "Invite Teacher". '
                'The teacher will receive an invitation and can join your institute.',
          ),
          _FaqItem(
            question: 'What happens if I\'m offline?',
            answer: 'The app works offline! Your attendance will be saved locally and synced automatically '
                'when you\'re back online. You\'ll see a yellow banner when offline.',
          ),
          _FaqItem(
            question: 'How do I delete a student?',
            answer: 'Open the batch, find the student, tap the three-dot menu and select "Remove". '
                'The student\'s attendance history will be preserved for reports.',
          ),

          const SizedBox(height: 24),

          // Contact section
          Card(
            color: AppColors.primary.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.support_agent, size: 48, color: AppColors.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Need more help?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Contact your institute administrator or reach out to support.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _QuickStartStep extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _QuickStartStep({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqItem({
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Theme mode selection tile with three options
class _ThemeModeTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    IconData icon;
    String subtitle;

    switch (themeMode) {
      case ThemeMode.system:
        icon = Icons.brightness_auto;
        subtitle = 'System default';
        break;
      case ThemeMode.light:
        icon = Icons.light_mode;
        subtitle = 'Light mode';
        break;
      case ThemeMode.dark:
        icon = Icons.dark_mode;
        subtitle = 'Dark mode';
        break;
    }

    return ListTile(
      leading: Icon(icon),
      title: const Text('Theme'),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeDialog(context, ref, themeMode),
    );
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref, ThemeMode currentMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('System default'),
              subtitle: const Text('Follow device settings'),
              value: ThemeMode.system,
              groupValue: currentMode,
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeModeProvider.notifier).setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              subtitle: const Text('Always use light theme'),
              value: ThemeMode.light,
              groupValue: currentMode,
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeModeProvider.notifier).setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              subtitle: const Text('Always use dark theme'),
              value: ThemeMode.dark,
              groupValue: currentMode,
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeModeProvider.notifier).setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
