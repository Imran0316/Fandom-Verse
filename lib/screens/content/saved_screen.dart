import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/content_docs.dart';
import '../../services/bookmark_service.dart';
import '../../services/content_service.dart';
import '../../widgets/content_widgets.dart';
import '../../widgets/skeletons.dart';
import 'content_detail_screen.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

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
                Expanded(
                  child: StreamBuilder<List<ContentDoc>>(
                    stream: ContentService.instance.watchPublished(),
                    builder: (context, contentSnap) {
                      return StreamBuilder<List<BookmarkDoc>>(
                        stream: BookmarkService.instance.watchMine(),
                        builder: (context, bookmarkSnap) {
                          if (contentSnap.hasError || bookmarkSnap.hasError) {
                            return const ContentErrorState(
                              message:
                                  'We couldn’t reach your saved library. Check your connection and try again.',
                            );
                          }
                          if (!contentSnap.hasData || !bookmarkSnap.hasData) {
                            return const ContentListSkeleton(count: 4);
                          }

                          final byId = {
                            for (final c in contentSnap.data!) c.id: c,
                          };
                          final saved = bookmarkSnap.data!
                              .where((b) => byId.containsKey(b.contentId))
                              .toList();

                          if (saved.isEmpty) {
                            return ContentEmptyState(
                              icon: Icons.bookmark_border_rounded,
                              title: 'Nothing saved yet',
                              message:
                                  'Bookmark discoveries to build your personal fandom library.',
                              action: () => Navigator.pushNamed(
                                context,
                                AppRoutes.explore,
                              ),
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
                              for (final bookmark in saved)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ContentRow(
                                        content: byId[bookmark.contentId]!,
                                        onTap: () => Navigator.pushNamed(
                                          context,
                                          AppRoutes.contentDetail,
                                          arguments: ContentDetailArgs(
                                            contentId: bookmark.contentId,
                                          ),
                                        ),
                                        trailing: IconButton(
                                          tooltip: 'Remove from saved',
                                          onPressed: () => BookmarkService
                                              .instance
                                              .remove(bookmark.contentId),
                                          icon: const Icon(
                                            Icons.bookmark_remove_outlined,
                                            color: Colors.white54,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 12, top: 2),
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
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
