import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/content_docs.dart';
import '../../services/auth_service.dart';
import '../../services/bookmark_service.dart';
import '../../services/content_service.dart';
import '../../services/offline_bookmark_store.dart';
import '../../widgets/content_widgets.dart';
import '../../widgets/skeletons.dart';
import 'content_detail_screen.dart';

/// Saved discoveries shelf. Live data comes from Firestore; the last known
/// list is mirrored into [OfflineBookmarkStore] so the shelf still renders
/// (clearly badged) when the device is offline.
///
/// Test seams: [contentStream], [bookmarkStream] and [store].
class SavedScreen extends StatefulWidget {
  const SavedScreen({
    super.key,
    this.contentStream,
    this.bookmarkStream,
    this.store,
  });

  final Stream<List<ContentDoc>>? contentStream;
  final Stream<List<BookmarkDoc>>? bookmarkStream;
  final OfflineBookmarkStore? store;

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  late final Stream<List<ContentDoc>> _content;
  late final Stream<List<BookmarkDoc>> _bookmarks;
  late final OfflineBookmarkStore _store;

  StreamSubscription<List<ContentDoc>>? _contentSub;
  StreamSubscription<List<BookmarkDoc>>? _bookmarkSub;

  List<ContentDoc>? _contentData;
  List<BookmarkDoc>? _bookmarkData;
  bool _contentError = false;
  bool _bookmarkError = false;
  List<Map<String, dynamic>> _cached = const [];

  @override
  void initState() {
    super.initState();
    _content = widget.contentStream ?? ContentService.instance.watchPublished();
    _bookmarks = widget.bookmarkStream ?? BookmarkService.instance.watchMine();
    _store = widget.store ?? OfflineBookmarkStore();

    _store.readAll().then((entries) {
      if (mounted) setState(() => _cached = entries);
    });

    _contentSub = _content.listen(
      (data) {
        if (!mounted) return;
        setState(() {
          _contentData = data;
          _contentError = false;
        });
        _syncCache();
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _contentError = true);
      },
    );
    _bookmarkSub = _bookmarks.listen(
      (data) {
        if (!mounted) return;
        setState(() {
          _bookmarkData = data;
          _bookmarkError = false;
        });
        _syncCache();
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _bookmarkError = true);
      },
    );
  }

  @override
  void dispose() {
    _contentSub?.cancel();
    _bookmarkSub?.cancel();
    super.dispose();
  }

  List<(ContentDoc, BookmarkDoc)> get _liveSaved {
    final contentData = _contentData;
    final bookmarkData = _bookmarkData;
    if (contentData == null || bookmarkData == null) {
      return const <(ContentDoc, BookmarkDoc)>[];
    }
    final byId = {for (final c in contentData) c.id: c};
    return <(ContentDoc, BookmarkDoc)>[
      for (final b in bookmarkData)
        if (byId[b.contentId] != null) (byId[b.contentId]!, b),
    ];
  }

  /// Mirror the live intersection into local storage once both streams have
  /// spoken. Skipped when Firebase was never initialized (widget tests and
  /// pure-offline fallbacks) so service `[]` placeholders never wipe the
  /// cache.
  void _syncCache() {
    if (_contentData == null || _bookmarkData == null) return;
    if (!AuthService.firebaseReady) return;
    final entries = <Map<String, dynamic>>[
      for (final (content, bookmark) in _liveSaved)
        OfflineBookmarkStore.entryFor(
          id: content.id,
          title: content.title,
          summary: content.summary,
          coverImageUrl: content.coverImageUrl,
          fandomName: content.fandomName,
          categoryName: content.categoryName,
          type: content.type.name,
          savedAt: bookmark.savedAt,
        ),
    ];
    _cached = entries;
    _store.writeAll(entries);
  }

  void _removeCached(String contentId) {
    setState(() {
      _cached =
          _cached.where((entry) => entry['id'] != contentId).toList();
    });
    _store.remove(contentId);
    BookmarkService.instance.remove(contentId);
  }

  Widget _offlineRow(Map<String, dynamic> entry) {
    final title = (entry['title'] as String?) ?? 'Untitled discovery';
    final tag = switch ((
      (entry['fandomName'] as String?) ?? '',
      (entry['categoryName'] as String?) ?? '',
    )) {
      (final fandom, _) when fandom.isNotEmpty => fandom,
      (_, final category) => category,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: InkWell(
              onTap: () => ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Reconnect to open this discovery.'),
                    backgroundColor: Color(0xE616161F),
                  ),
                ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.bookmark_rounded,
                      color: AppColors.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'OFFLINE',
                                style: TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (tag.isNotEmpty)
                          Text(
                            tag,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove from saved',
                    onPressed: () =>
                        _removeCached((entry['id'] as String?) ?? ''),
                    icon: const Icon(
                      Icons.bookmark_remove_outlined,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cachedList({required bool offline}) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            offline
                ? '${_cached.length} saved '
                    '${_cached.length == 1 ? 'discovery' : 'discoveries'} (offline)'
                : '${_cached.length} saved '
                    '${_cached.length == 1 ? 'discovery' : 'discoveries'}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final entry in _cached) _offlineRow(entry),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Saved',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_contentError || _bookmarkError) {
      if (_cached.isNotEmpty) return _cachedList(offline: true);
      return const ContentErrorState(
        message:
            'We couldn’t reach your saved library. Check your connection and try again.',
      );
    }

    final loaded = _contentData != null && _bookmarkData != null;
    final saved = _liveSaved;

    if (!loaded) {
      if (_cached.isNotEmpty) return _cachedList(offline: true);
      return const ContentListSkeleton(count: 4);
    }

    if (saved.isEmpty) {
      if (_cached.isNotEmpty) return _cachedList(offline: false);
      return ContentEmptyState(
        icon: Icons.bookmark_border_rounded,
        title: 'Nothing saved yet',
        message: 'Bookmark discoveries to build your personal fandom library.',
        action: () => Navigator.pushNamed(context, AppRoutes.explore),
        actionLabel: 'Explore Fandoms',
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            '${saved.length} saved '
            '${saved.length == 1 ? 'discovery' : 'discoveries'}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final (content, bookmark) in saved)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ContentRow(
                  content: content,
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.contentDetail,
                    arguments: ContentDetailArgs(contentId: bookmark.contentId),
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove from saved',
                    onPressed: () =>
                        BookmarkService.instance.remove(bookmark.contentId),
                    icon: const Icon(
                      Icons.bookmark_remove_outlined,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 2),
                  child: Text(
                    'Saved ${contentDateLabel(bookmark.savedAt)}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
