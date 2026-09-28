import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/streams.dart';
import '../models/reel_docs.dart';
import 'auth_service.dart';
import 'image_upload_service.dart';

/// Result of a Cloudinary video upload: the hosted file plus a derived
/// poster frame (first second) used as the feed thumbnail.
class ReelUpload {
  const ReelUpload({required this.videoUrl, required this.thumbnailUrl});

  final String videoUrl;
  final String thumbnailUrl;
}

/// A failed reel operation carrying a message safe to show a person.
/// [technical] is for logs only.
class ReelException implements Exception {
  const ReelException(this.message, {this.technical});

  final String message;
  final String? technical;

  @override
  String toString() => technical == null ? message : '$message [$technical]';
}

/// Community reels: Cloudinary-hosted videos with Firestore metadata,
/// likes and comments. Mirrors the [PostService] patterns (per-user like
/// docs, counter increments, timestamp-ordered feeds).
class ReelService {
  ReelService._();

  static final ReelService instance = ReelService._();

  static const Duration _uploadTimeout = Duration(seconds: 180);

  bool get _ready => AuthService.firebaseReady;

  String? get _uid => AuthService.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('reels');

  DocumentReference<Map<String, dynamic>> _doc(String reelId) =>
      _col.doc(reelId);

  CollectionReference<Map<String, dynamic>> _likes(String reelId) =>
      _doc(reelId).collection('likes');

  CollectionReference<Map<String, dynamic>> _comments(String reelId) =>
      _doc(reelId).collection('comments');

  /* --------------------------------- Feed --------------------------------- */

  Stream<List<ReelDoc>> watchLatest({int limit = 30}) {
    if (!_ready) return onceStream(const <ReelDoc>[]);
    return _col
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(ReelDoc.fromDoc).toList());
  }

  /* -------------------------------- Upload -------------------------------- */

  /// Uploads raw video bytes to Cloudinary (`video/upload`, unsigned preset)
  /// and returns the hosted URL plus a poster-frame thumbnail URL.
  Future<ReelUpload> uploadVideo(
    List<int> bytes, {
    required String filename,
  }) async {
    if (!ImageUploadService.cloudinaryConfigured) {
      throw const ReelException(
        'Video uploads are not configured yet.',
        technical: 'cloudinary cloud name / preset missing',
      );
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/'
      '${ImageUploadService.cloudinaryCloudName}/video/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = ImageUploadService.cloudinaryUploadPreset
      ..fields['folder'] = '${ImageUploadService.cloudinaryFolder}/reels'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
          filename: filename,
          contentType: http.MediaType.parse(_mimeFromName(filename)),
        ),
      );

    http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(_uploadTimeout);
    } on TimeoutException {
      throw const ReelException(
        'The upload took too long. Check your connection and try again.',
        technical: 'Cloudinary video upload timed out after 180s',
      );
    } on http.ClientException catch (error) {
      throw ReelException(
        'Could not reach the video host. Check your internet connection.',
        technical: 'Cloudinary network failure: $error',
      );
    }

    final body = await streamed.stream.bytesToString();
    Map<String, dynamic>? json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      json = null;
    }

    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      final videoUrl =
          json?['secure_url'] as String? ?? json?['url'] as String?;
      final publicId = json?['public_id'] as String?;
      if (videoUrl != null && videoUrl.isNotEmpty && publicId != null) {
        return ReelUpload(
          videoUrl: videoUrl,
          thumbnailUrl: thumbnailUrlFor(publicId),
        );
      }
      throw const ReelException(
        'The video host did not return a link. Try again in a moment.',
        technical: 'Cloudinary returned success without secure_url',
      );
    }

    throw _uploadFailure(
      statusCode: streamed.statusCode,
      hostMessage: json?['error']?['message'] as String?,
    );
  }

  /// Derived Cloudinary URL for the first frame of the video (poster).
  static String thumbnailUrlFor(String publicId) =>
      'https://res.cloudinary.com/'
      '${ImageUploadService.cloudinaryCloudName}'
      '/video/upload/so_1/$publicId.jpg';

  static ReelException _uploadFailure({
    required int statusCode,
    String? hostMessage,
  }) {
    final technical = 'Cloudinary video HTTP $statusCode'
        '${hostMessage != null ? ': $hostMessage' : ''}';
    final lower = (hostMessage ?? '').toLowerCase();

    if (statusCode == 401 ||
        lower.contains('preset') ||
        lower.contains('unsigned') ||
        lower.contains('cloud name')) {
      return ReelException(
        'Video uploads are not configured correctly. Enable Video on the '
        'Cloudinary upload preset and try again.',
        technical: technical,
      );
    }
    if (statusCode == 413 || lower.contains('file size')) {
      return ReelException(
        'That video is too large. Try a shorter clip (under 100 MB).',
        technical: technical,
      );
    }
    if (statusCode == 420 || statusCode == 429) {
      return ReelException(
        'Too many uploads right now. Wait a moment and try again.',
        technical: technical,
      );
    }
    if (statusCode >= 500) {
      return ReelException(
        'The video host is having trouble. Try again in a moment.',
        technical: technical,
      );
    }
    return ReelException(
      'The video could not be uploaded. Try again in a moment.',
      technical: technical,
    );
  }

  static String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.m4v')) return 'video/x-m4v';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.3gp')) return 'video/3gpp';
    return 'video/mp4';
  }

  /* --------------------------------- Create -------------------------------- */

  Future<void> create({
    required String videoUrl,
    required String thumbnailUrl,
    required String caption,
    String? communityId,
    String? communityName,
    String? authorName,
    String? authorAvatarUrl,
  }) async {
    final uid = _uid;
    if (!_ready || uid == null) throw const ReelException('Sign in to post reels.');
    if (videoUrl.isEmpty) {
      throw const ReelException('The video is missing. Pick it again.');
    }
    await _doc(_col.doc().id).set(<String, dynamic>{
      'authorUid': uid,
      'authorName': authorName ?? AuthService.instance.greetingName,
      'authorAvatarUrl': authorAvatarUrl,
      'caption': caption.trim(),
      'communityId': communityId,
      'communityName': communityName,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'likeCount': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String reelId) async {
    final snap = await _doc(reelId).get();
    final authorUid = snap.data()?['authorUid'] as String?;
    if (authorUid != _uid) {
      throw const ReelException('You can only delete your own reels.');
    }
    await _doc(reelId).delete();
  }

  /* -------------------------------- Actions -------------------------------- */

  Stream<bool> watchLiked(String reelId) {
    final uid = _uid;
    if (!_ready || uid == null) return Stream.value(false);
    return _likes(reelId).doc(uid).snapshots().map((s) => s.exists);
  }

  Future<void> toggleLike(String reelId) async {
    final uid = _uid;
    if (!_ready || uid == null) {
      throw const ReelException('Sign in to like reels.');
    }
    final ref = _likes(reelId).doc(uid);
    final snap = await ref.get();
    final batch = FirebaseFirestore.instance.batch();
    if (snap.exists) {
      batch.delete(ref);
      batch.update(_doc(reelId), {'likeCount': FieldValue.increment(-1)});
    } else {
      batch.set(ref, {'uid': uid, 'at': FieldValue.serverTimestamp()});
      batch.update(_doc(reelId), {'likeCount': FieldValue.increment(1)});
    }
    await batch.commit();
  }

  /* ------------------------------- Comments ------------------------------- */

  Stream<List<ReelCommentDoc>> watchComments(String reelId, {int limit = 60}) {
    if (!_ready) return onceStream(const <ReelCommentDoc>[]);
    return _comments(reelId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(ReelCommentDoc.fromDoc).toList());
  }

  Future<void> addComment(
    String reelId,
    String body, {
    String? authorName,
    String? authorAvatarUrl,
  }) async {
    final uid = _uid;
    if (!_ready || uid == null) {
      throw const ReelException('Sign in to comment.');
    }
    final text = body.trim();
    if (text.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    batch.set(_comments(reelId).doc(), {
      'authorUid': uid,
      'authorName': authorName ?? AuthService.instance.greetingName,
      'authorAvatarUrl': authorAvatarUrl,
      'body': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_doc(reelId), {'commentCount': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> deleteComment(String reelId, String commentId) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(_comments(reelId).doc(commentId));
    batch.update(_doc(reelId), {'commentCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  /// Short, human message for any failure. Raw exception text is never
  /// shown to the user.
  static String friendlyMessage(Object error) {
    if (error is ReelException) return error.message;
    if (error.toString().contains('permission')) {
      return 'Not allowed — publish updated firestore.rules and try again.';
    }
    return 'Something went wrong. Check your connection and try again.';
  }
}
