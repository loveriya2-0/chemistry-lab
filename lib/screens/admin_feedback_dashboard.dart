import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../core/theme.dart';
import '../data/feedback_store.dart';
import '../models/feedback_submission.dart';
import '../widgets/ui_kit.dart';
import 'feedback_detail_screen.dart';

class AdminFeedbackDashboard extends StatefulWidget {
  const AdminFeedbackDashboard({super.key});

  @override
  State<AdminFeedbackDashboard> createState() => _AdminFeedbackDashboardState();
}

class _AdminFeedbackDashboardState extends State<AdminFeedbackDashboard> {
  FeedbackStatus? _statusFilter;
  FeedbackCategory? _categoryFilter;

  Color _categoryColor(FeedbackCategory category) => switch (category) {
        FeedbackCategory.bugReport => LabColors.danger,
        FeedbackCategory.suggestion => LabColors.primary,
        FeedbackCategory.contentIssue => LabColors.warning,
        FeedbackCategory.general => LabColors.teal,
      };

  Color _statusColor(FeedbackStatus status) => switch (status) {
        FeedbackStatus.pending => LabColors.warning,
        FeedbackStatus.reviewed => LabColors.primary,
        FeedbackStatus.resolved => LabColors.success,
      };

  @override
  Widget build(BuildContext context) {
    final feedbackStore = context.read<FeedbackStore>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback Dashboard'),
        actions: [
          PopupMenuButton<FeedbackCategory?>(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: 'Filter by category',
            onSelected: (category) {
              setState(() => _categoryFilter = category);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Categories'),
              ),
              ...FeedbackCategory.values.map((category) => PopupMenuItem(
                    value: category,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _categoryColor(category),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(category.label),
                      ],
                    ),
                  )),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Status filter chips
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _statusFilter == null,
                  onSelected: (_) {
                    setState(() => _statusFilter = null);
                  },
                ),
                ...FeedbackStatus.values.map((status) => FilterChip(
                      label: Text(status.label),
                      selected: _statusFilter == status,
                      onSelected: (_) {
                        setState(() => _statusFilter = status);
                      },
                    )),
              ],
            ),
          ),
          const Divider(height: 1),

          // Feedback list
          Expanded(
            child: StreamBuilder<List<FeedbackSubmission>>(
              stream: feedbackStore.getFeedbackStream(
                statusFilter: _statusFilter,
                categoryFilter: _categoryFilter,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: LabColors.danger,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Error loading feedback',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: LabColors.muted),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final feedbackList = snapshot.data ?? [];

                if (feedbackList.isEmpty) {
                  return Center(
                    child: ComingSoonPanel(
                      icon: Icons.feedback_outlined,
                      title: 'No Feedback Yet',
                      body: _statusFilter != null || _categoryFilter != null
                          ? 'No feedback matches the selected filters.'
                          : 'Feedback submissions will appear here.',
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: feedbackList.length,
                  itemBuilder: (context, index) {
                    final feedback = feedbackList[index];
                    return _FeedbackCard(
                      feedback: feedback,
                      categoryColor: _categoryColor(feedback.category),
                      statusColor: _statusColor(feedback.status),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FeedbackDetailScreen(
                              feedback: feedback,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.feedback,
    required this.categoryColor,
    required this.statusColor,
    required this.onTap,
  });

  final FeedbackSubmission feedback;
  final Color categoryColor;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Rating, category, time
              Row(
                children: [
                  // Rating stars
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      5,
                      (index) => Icon(
                        index < feedback.rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 18,
                        color: index < feedback.rating
                            ? LabColors.warning
                            : Colors.grey.shade300,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Category badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      feedback.category.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: categoryColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Time ago
                  Text(
                    timeago.format(feedback.timestamp),
                    style: const TextStyle(
                      fontSize: 12,
                      color: LabColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Message preview
              Text(
                feedback.message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(height: 1.4, color: LabColors.ink),
              ),
              const SizedBox(height: 10),
              // Footer: Status, screenshot indicator
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          feedback.status.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (feedback.screenshotUrl != null) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.image_outlined,
                      size: 16,
                      color: LabColors.muted,
                    ),
                  ],
                  if (feedback.userEmail != null) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.email_outlined,
                      size: 16,
                      color: LabColors.muted,
                    ),
                  ],
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: LabColors.muted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
