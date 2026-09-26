import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local mirror of the fan's saved discoveries so the Saved shelf can render
/// without a connection (Firestore is still the source of truth).
///
/// Uses `shared_preferences` because it works on web, mobile and tests alike
/// (sqflite — the other SRS candidate — does not run on Flutter Web).
class OfflineBookmarkStore {
  OfflineBookmarkStore({this.prefs});

  static const String prefsKey = 'offline_bookmarks_v1';

  /// Pre-loaded preferences; tests inject mock instances here.
  SharedPreferences? prefs;

  Future<SharedPreferences> _load() async {
    return prefs ??= await SharedPreferences.getInstance();
  }

  /// Cached entries, oldest storage order. Never throws.
  Future<List<Map<String, dynamic>>> readAll() async {
    try {
      final prefs = await _load();
      final raw = prefs.getStringList(prefsKey) ?? const <String>[];
      final out = <Map<String, dynamic>>[];
      for (final entry in raw) {
        try {
          final decoded = jsonDecode(entry);
          if (decoded is Map<String, dynamic>) out.add(decoded);
        } catch (_) {
          // Skip corrupt entries.
        }
      }
      return out;
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  /// Replaces the cache (fire-and-forget from the Saved screen).
  Future<void> writeAll(List<Map<String, dynamic>> entries) async {
    try {
      final prefs = await _load();
      await prefs.setStringList(
        prefsKey,
        <String>[for (final entry in entries) jsonEncode(entry)],
      );
    } catch (_) {
      // Local cache is best-effort; never surface storage failures.
    }
  }

  Future<void> remove(String contentId) async {
    try {
      final all = await readAll();
      all.removeWhere((entry) => entry['id'] == contentId);
      await writeAll(all);
    } catch (_) {
      // Best-effort.
    }
  }

  /// Snapshot of a ContentDoc for the cache (only the fields the shelf needs).
  static Map<String, dynamic> entryFor({
    required String id,
    required String title,
    required String summary,
    String? coverImageUrl,
    required String fandomName,
    required String categoryName,
    required String type,
    DateTime? savedAt,
  }) {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'summary': summary,
      'coverImageUrl': coverImageUrl,
      'fandomName': fandomName,
      'categoryName': categoryName,
      'type': type,
      'savedAtMs': savedAt?.millisecondsSinceEpoch,
    };
  }
}
