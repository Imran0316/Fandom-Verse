import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/content_docs.dart';
import 'auth_service.dart';

/// Fan → Bookmark → Content. One deterministic doc per (user, content) pair so
/// duplicates are impossible and toggling is a single lookup.
class BookmarkService {
  BookmarkService._();

  static final BookmarkService instance = BookmarkService._();

  static const String collection = 'bookmarks';

  bool get _ready => AuthService.firebaseReady;

  String? get _uid => AuthService.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(collection);

  String _docId(String uid, String contentId) => '${uid}_$contentId';

  /// The current fan's bookmarks, newest first.
  Stream<List<BookmarkDoc>> watchMine() {
    final uid = _uid;
    if (!_ready || uid == null) return Stream.value(const []);
    return _col.where('userId', isEqualTo: uid).snapshots().map((s) {
      final items = s.docs.map(BookmarkDoc.fromDoc).toList();
      items.sort((a, b) {
        final l = a.savedAt;
        final r = b.savedAt;
        if (l == null && r == null) return 0;
        if (l == null) return 1;
        if (r == null) return -1;
        return r.compareTo(l);
      });
      return items;
    });
  }

  /// Content ids the current fan has bookmarked — for detail/bookmark toggles.
  Stream<Set<String>> watchMyContentIds() =>
      watchMine().map((list) => list.map((b) => b.contentId).toSet());

  /// Persists (or removes) a bookmark. Returns the new saved state.
  Future<bool> toggle(String contentId) async {
    final uid = _uid;
    if (!_ready || uid == null) {
      throw StateError('Sign in to save discoveries.');
    }
    final ref = _col.doc(_docId(uid, contentId));
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
      return false;
    }
    await ref.set({
      'userId': uid,
      'contentId': contentId,
      'savedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  Future<void> remove(String contentId) async {
    final uid = _uid;
    if (!_ready || uid == null) return;
    await _col.doc(_docId(uid, contentId)).delete();
  }
}
