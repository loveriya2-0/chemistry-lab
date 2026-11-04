import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../core/theme.dart';
import '../data/feedback_store.dart';
import '../models/feedback_submission.dart';
import '../widgets/ui_kit.dart';

class FeedbackDetailScreen extends StatefulWidget {
  const FeedbackDetailScreen({super.key, required this.feedback});

  final FeedbackSubmission feedback;

  @override
  State<FeedbackDetailScreen> createState() => _FeedbackDetailScreenState();
}

class _FeedbackDetailScreenState extends State<FeedbackDetailScreen> {
  late FeedbackStatus _currentStatus;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.feedback.status;
  }

  Color _categoryColor(FeedbackCategory category) => switch (category) {
        FeedbackCategory.bugReport => LabColors.danger,
        FeedbackCategory.suggestion => LabColors.primary,
        FeedbackCategory.contentIssue => LabColors.warning,
        FeedbackCategory.general => LabColors.teal,
      };

  Future<void> _updateStatus(FeedbackStatus newStatus) async {
    setState(() => _updating = true);
    try {
      final feedbackStore = context.read<FeedbackStore>();
      await feedbackStore.updateStatus(widget.feedback.id!, newStatus);

      if (!mounted) return;
      setState(() => _currentStatus = newStatus);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to ${newStatus.label}'),
          backgroundColor: LabColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: LabColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }

  Future<void> _deleteFeedback() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Feedback?'),
        content: const Text(
          'This action cannot be undone. The feedback and any attached screenshot will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: LabColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final feedbackStore = context.read<FeedbackStore>();
      await feedbackStore.deleteFeedback(widget.feedback.id!);

      if (!mounted) return;

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback deleted'),
          backgroundColor: LabColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: LabColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedback = widget.feedback;
    final categoryColor = _categoryColor(feedback.category);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete',
            onPressed: _deleteFeedback,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Rating and Category
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rating',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: LabColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(
                      5,
                      (index) => Icon(
                        index < feedback.rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 32,
                        color: index < feedback.rating
                            ? LabColors.warning
                            : Colors.grey.shade300,
                      ),
                    ),
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Category',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: LabColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      feedback.category.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: categoryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Message
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Message',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: LabColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    feedback.message,
                    style: const TextStyle(
                      height: 1.5,
                      fontSize: 15,
                      color: LabColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Screenshot
          if (feedback.screenshotUrl != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Screenshot',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: LabColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _FullScreenImage(
                                imageUrl: feedback.screenshotUrl!,
                              ),
                            ),
                          );
                        },
                        child: CachedNetworkImage(
                          imageUrl: feedback.screenshotUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 200,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 200,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(Icons.error_outline_rounded),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: LabColors.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<FeedbackStatus>(
                    segments: FeedbackStatus.values
                        .map((status) => ButtonSegment(
                              value: status,
                              label: Text(status.label),
                            ))
                        .toList(),
                    selected: {_currentStatus},
                    onSelectionChanged: _updating
                        ? null
                        : (Set<FeedbackStatus> selection) {
                            _updateStatus(selection.first);
                          },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // User Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'User Information',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: LabColors.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.access_time_rounded,
                    label: 'Submitted',
                    value: timeago.format(feedback.timestamp),
                  ),
                  if (feedback.userEmail != null) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: feedback.userEmail!,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.person_outline_rounded,
                    label: 'User ID',
                    value: feedback.userId,
                  ),
                  if (feedback.boardId != null) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.school_outlined,
                      label: 'Board',
                      value: feedback.boardId!,
                    ),
                  ],
                  if (feedback.classLevel != null) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.class_outlined,
                      label: 'Class',
                      value: 'Class ${feedback.classLevel}',
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Device Info (collapsible)
          if (feedback.deviceInfo.isNotEmpty)
            Card(
              child: ExpansionTile(
                leading: const IconTile(
                  icon: Icons.phone_android_rounded,
                  color: LabColors.muted,
                  size: 36,
                ),
                title: const Text(
                  'Device Information',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                shape: const Border(),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: feedback.deviceInfo.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: LabColors.muted,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: SelectableText(
                                  entry.value.toString(),
                                  style: const TextStyle(color: LabColors.ink),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: LabColors.muted),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: LabColors.muted,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: SelectableText(
            value,
            style: const TextStyle(color: LabColors.ink),
          ),
        ),
      ],
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (context, url, error) => const Center(
              child: Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
