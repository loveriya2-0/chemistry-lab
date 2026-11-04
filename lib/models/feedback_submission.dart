import 'package:cloud_firestore/cloud_firestore.dart';

enum FeedbackCategory {
  bugReport,
  suggestion,
  contentIssue,
  general;

  String get label => switch (this) {
        bugReport => 'Bug Report',
        suggestion => 'Suggestion',
        contentIssue => 'Content Issue',
        general => 'General Feedback',
      };

  String get value => switch (this) {
        bugReport => 'bug_report',
        suggestion => 'suggestion',
        contentIssue => 'content_issue',
        general => 'general',
      };

  static FeedbackCategory fromValue(String value) => switch (value) {
        'bug_report' => bugReport,
        'suggestion' => suggestion,
        'content_issue' => contentIssue,
        _ => general,
      };
}

enum FeedbackStatus {
  pending,
  reviewed,
  resolved;

  String get label => switch (this) {
        pending => 'Pending',
        reviewed => 'Reviewed',
        resolved => 'Resolved',
      };

  String get value => switch (this) {
        pending => 'pending',
        reviewed => 'reviewed',
        resolved => 'resolved',
      };

  static FeedbackStatus fromValue(String value) => switch (value) {
        'reviewed' => reviewed,
        'resolved' => resolved,
        _ => pending,
      };
}

class FeedbackSubmission {
  FeedbackSubmission({
    this.id,
    required this.userId,
    this.userEmail,
    required this.timestamp,
    required this.rating,
    required this.category,
    required this.message,
    this.screenshotUrl,
    this.status = FeedbackStatus.pending,
    this.deviceInfo = const {},
    this.boardId,
    this.classLevel,
  });

  final String? id;
  final String userId;
  final String? userEmail;
  final DateTime timestamp;
  final int rating;
  final FeedbackCategory category;
  final String message;
  final String? screenshotUrl;
  final FeedbackStatus status;
  final Map<String, dynamic> deviceInfo;
  final String? boardId;
  final int? classLevel;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'userEmail': userEmail,
        'timestamp': Timestamp.fromDate(timestamp),
        'rating': rating,
        'category': category.value,
        'message': message,
        'screenshotUrl': screenshotUrl,
        'status': status.value,
        'deviceInfo': deviceInfo,
        'boardId': boardId,
        'classLevel': classLevel,
      };

  factory FeedbackSubmission.fromJson(Map<String, dynamic> json, {String? id}) => FeedbackSubmission(
        id: id,
        userId: json['userId'] as String? ?? '',
        userEmail: json['userEmail'] as String?,
        timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        rating: json['rating'] as int? ?? 0,
        category: FeedbackCategory.fromValue(json['category'] as String? ?? 'general'),
        message: json['message'] as String? ?? '',
        screenshotUrl: json['screenshotUrl'] as String?,
        status: FeedbackStatus.fromValue(json['status'] as String? ?? 'pending'),
        deviceInfo: json['deviceInfo'] as Map<String, dynamic>? ?? {},
        boardId: json['boardId'] as String?,
        classLevel: json['classLevel'] as int?,
      );

  FeedbackSubmission copyWith({
    String? id,
    String? userId,
    String? userEmail,
    DateTime? timestamp,
    int? rating,
    FeedbackCategory? category,
    String? message,
    String? screenshotUrl,
    FeedbackStatus? status,
    Map<String, dynamic>? deviceInfo,
    String? boardId,
    int? classLevel,
  }) =>
      FeedbackSubmission(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        userEmail: userEmail ?? this.userEmail,
        timestamp: timestamp ?? this.timestamp,
        rating: rating ?? this.rating,
        category: category ?? this.category,
        message: message ?? this.message,
        screenshotUrl: screenshotUrl ?? this.screenshotUrl,
        status: status ?? this.status,
        deviceInfo: deviceInfo ?? this.deviceInfo,
        boardId: boardId ?? this.boardId,
        classLevel: classLevel ?? this.classLevel,
      );
}
