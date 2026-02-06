import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../providers/parent_providers.dart';
import '../../utils/theme.dart';
import '../../services/firestore_service.dart';

/// Screen showing announcements for parents
class ParentAnnouncementsScreen extends ConsumerWidget {
  final Parent parent;

  const ParentAnnouncementsScreen({super.key, required this.parent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(activeAnnouncementsProvider((
      instituteId: parent.instituteId,
      batchId: null, // Show all announcements for parent's children
    )));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
      ),
      body: announcementsAsync.when(
        data: (announcements) {
          if (announcements.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No announcements',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check back later for updates from\nyour institute.',
                    style: TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: announcements.length,
            itemBuilder: (context, index) {
              return _AnnouncementCard(
                announcement: announcements[index],
                firestoreService: ref.read(firestoreServiceProvider),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: AppColors.absent),
              const SizedBox(height: 16),
              Text('Failed to load announcements'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(activeAnnouncementsProvider((
                  instituteId: parent.instituteId,
                  batchId: null,
                ))),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatefulWidget {
  final Announcement announcement;
  final FirestoreService firestoreService;

  const _AnnouncementCard({
    required this.announcement,
    required this.firestoreService,
  });

  @override
  State<_AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<_AnnouncementCard> {
  bool _isExpanded = false;

  Color get _priorityColor {
    switch (widget.announcement.priority) {
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

  IconData get _priorityIcon {
    switch (widget.announcement.priority) {
      case AnnouncementPriority.urgent:
        return Icons.warning_amber;
      case AnnouncementPriority.high:
        return Icons.priority_high;
      case AnnouncementPriority.normal:
        return Icons.campaign;
      case AnnouncementPriority.low:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final announcement = widget.announcement;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _priorityColor.withValues(alpha: 0.1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _priorityColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_priorityIcon, color: _priorityColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (announcement.isUrgent)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'URGENT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Text(
                        announcement.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        announcement.publishedAt != null
                            ? DateFormat('MMM d, yyyy • h:mm a')
                                .format(announcement.publishedAt!)
                            : 'Recently published',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          InkWell(
            onTap: () {
              setState(() => _isExpanded = !_isExpanded);
              if (_isExpanded) {
                widget.firestoreService.incrementAnnouncementViews(announcement.id);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    announcement.content,
                    style: const TextStyle(height: 1.5),
                    maxLines: _isExpanded ? null : 3,
                    overflow: _isExpanded ? null : TextOverflow.ellipsis,
                  ),
                  if (announcement.content.length > 150) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isExpanded ? 'Show less' : 'Read more',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Footer
          if (announcement.expiresAt != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Expires: ${DateFormat('MMM d, yyyy').format(announcement.expiresAt!)}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
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
