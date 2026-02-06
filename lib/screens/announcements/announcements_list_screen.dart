import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../providers/parent_providers.dart';
import '../../utils/theme.dart';
import '../../widgets/common_widgets.dart';
import 'create_announcement_screen.dart';

/// Screen showing all announcements for teachers to manage
class AnnouncementsListScreen extends ConsumerWidget {
  final String instituteId;
  final String teacherId;

  const AnnouncementsListScreen({
    super.key,
    required this.instituteId,
    required this.teacherId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(announcementsProvider(instituteId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateAnnouncementScreen(
                  instituteId: instituteId,
                  teacherId: teacherId,
                ),
              ),
            ),
          ),
        ],
      ),
      body: announcementsAsync.when(
        data: (announcements) {
          if (announcements.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.campaign,
              title: 'No Announcements',
              subtitle: 'Create your first announcement to notify parents',
              action: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateAnnouncementScreen(
                      instituteId: instituteId,
                      teacherId: teacherId,
                    ),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Create Announcement'),
              ),
            );
          }

          // Separate draft and published
          final drafts = announcements.where((a) => !a.isPublished).toList();
          final published = announcements.where((a) => a.isPublished).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (drafts.isNotEmpty) ...[
                Text(
                  'Drafts',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                ...drafts.map((a) => _AnnouncementCard(
                      announcement: a,
                      instituteId: instituteId,
                      teacherId: teacherId,
                    )),
                const SizedBox(height: 24),
              ],
              if (published.isNotEmpty) ...[
                Text(
                  'Published',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                ...published.map((a) => _AnnouncementCard(
                      announcement: a,
                      instituteId: instituteId,
                      teacherId: teacherId,
                    )),
              ],
            ],
          );
        },
        loading: () => const ShimmerListLoading(type: ShimmerListType.batch),
        error: (error, stack) => ErrorStateWidget(
          error: error,
          onRetry: () => ref.invalidate(announcementsProvider(instituteId)),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateAnnouncementScreen(
              instituteId: instituteId,
              teacherId: teacherId,
            ),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AnnouncementCard extends ConsumerWidget {
  final Announcement announcement;
  final String instituteId;
  final String teacherId;

  const _AnnouncementCard({
    required this.announcement,
    required this.instituteId,
    required this.teacherId,
  });

  Color get _priorityColor {
    switch (announcement.priority) {
      case AnnouncementPriority.urgent:
        return Colors.red;
      case AnnouncementPriority.high:
        return Colors.orange;
      case AnnouncementPriority.normal:
        return AppColors.primary;
      case AnnouncementPriority.low:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateAnnouncementScreen(
              instituteId: instituteId,
              teacherId: teacherId,
              announcement: announcement,
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _priorityColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      announcement.priority.displayName,
                      style: TextStyle(
                        color: _priorityColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!announcement.isPublished)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'DRAFT',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (announcement.isPublished && announcement.viewCount > 0)
                    Row(
                      children: [
                        Icon(Icons.visibility, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${announcement.viewCount}',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                announcement.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),

              // Content preview
              Text(
                announcement.content,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Footer
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    announcement.isPublished && announcement.publishedAt != null
                        ? 'Published ${DateFormat('MMM d, h:mm a').format(announcement.publishedAt!)}'
                        : 'Created ${DateFormat('MMM d').format(announcement.createdAt)}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (announcement.targetBatchIds != null) ...[
                    const Spacer(),
                    Icon(Icons.group, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${announcement.targetBatchIds!.length} batch${announcement.targetBatchIds!.length > 1 ? 'es' : ''}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),

              // Action buttons
              if (!announcement.isPublished) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Announcement'),
                            content: const Text('Are you sure you want to delete this draft?'),
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
                              .deleteAnnouncement(announcement.id);
                        }
                      },
                      icon: Icon(Icons.delete, size: 18, color: AppColors.absent),
                      label: Text('Delete', style: TextStyle(color: AppColors.absent)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Publish Announcement'),
                            content: const Text('Once published, parents will be able to see this announcement. Continue?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Publish'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          final success = await ref
                              .read(announcementNotifierProvider.notifier)
                              .publishAnnouncement(announcement.id);
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Announcement published!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('Publish'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
