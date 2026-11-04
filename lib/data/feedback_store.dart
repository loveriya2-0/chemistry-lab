import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/feedback_submission.dart';

/// Manages feedback submissions to Firestore and screenshot uploads to
/// Firebase Storage.
class FeedbackStore {
  FeedbackStore(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const _collectionName = 'feedback';

  /// Submits feedback to Firestore. If [screenshotFile] is provided, uploads
  /// it to Firebase Storage first and includes the download URL.
  Future<String> submitFeedback({
    required String userId,
    String? userEmail,
    required int rating,
    required FeedbackCategory category,
    required String message,
    File? screenshotFile,
    String? boardId,
    int? classLevel,
  }) async {
    String? screenshotUrl;

    // Upload screenshot if provided
    if (screenshotFile != null) {
      try {
        final fileName = 'feedback_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = _storage.ref().child('feedback_screenshots').child(fileName);
        await ref.putFile(screenshotFile);
        screenshotUrl = await ref.getDownloadURL();
      } catch (e) {
        debugPrint('Failed to upload screenshot: $e');
        // Continue without screenshot rather than failing the entire submission
      }
    }

    // Gather device info
    final deviceInfo = await _getDeviceInfo();

    final feedback = FeedbackSubmission(
      userId: userId,
      userEmail: userEmail,
      timestamp: DateTime.now(),
      rating: rating,
      category: category,
      message: message,
      screenshotUrl: screenshotUrl,
      status: FeedbackStatus.pending,
      deviceInfo: deviceInfo,
      boardId: boardId,
      classLevel: classLevel,
    );

    final docRef = await _firestore.collection(_collectionName).add(feedback.toJson());
    return docRef.id;
  }

  /// Gets device information for debugging purposes
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final info = await deviceInfoPlugin.androidInfo;
        return {
          'platform': 'Android',
          'osVersion': info.version.release,
          'model': info.model,
          'manufacturer': info.manufacturer,
        };
      } else if (Platform.isIOS) {
        final info = await deviceInfoPlugin.iosInfo;
        return {
          'platform': 'iOS',
          'osVersion': info.systemVersion,
          'model': info.model,
        };
      }
    } catch (e) {
      debugPrint('Failed to get device info: $e');
    }
    return {'platform': 'Unknown'};
  }

  /// Returns a stream of feedback submissions, ordered by timestamp (newest first)
  Stream<List<FeedbackSubmission>> getFeedbackStream({
    FeedbackStatus? statusFilter,
    FeedbackCategory? categoryFilter,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(_collectionName)
        .orderBy('timestamp', descending: true);

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.value);
    }

    if (categoryFilter != null) {
      query = query.where('category', isEqualTo: categoryFilter.value);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => FeedbackSubmission.fromJson(doc.data(), id: doc.id))
        .toList());
  }

  /// Updates the status of a feedback submission
  Future<void> updateStatus(String feedbackId, FeedbackStatus status) async {
    await _firestore
        .collection(_collectionName)
        .doc(feedbackId)
        .update({'status': status.value});
  }

  /// Deletes a feedback submission
  Future<void> deleteFeedback(String feedbackId) async {
    final doc = await _firestore.collection(_collectionName).doc(feedbackId).get();
    final data = doc.data();

    // Delete screenshot from storage if it exists
    if (data != null && data['screenshotUrl'] != null) {
      try {
        final url = data['screenshotUrl'] as String;
        final ref = _storage.refFromURL(url);
        await ref.delete();
      } catch (e) {
        debugPrint('Failed to delete screenshot: $e');
      }
    }

    await _firestore.collection(_collectionName).doc(feedbackId).delete();
  }
}
