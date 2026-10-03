import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/content_docs.dart';
import '../../services/content_service.dart';
import '../../services/stream_cache.dart';
import '../../services/taxonomy_service.dart';
import '../../widgets/content_widgets.dart';
import '../../widgets/skeletons.dart';
import '../content/content_detail_screen.dart';
import 'admin_panels.dart';

/// CMS-style content management: create, search, filter, publish, feature,
/// trend, preview and delete fandom discoveries.
class ContentManagementPanel extends StatefulWidget {
  const ContentManagementPanel({super.key});

  @override
  State<ContentManagementPanel> createState() => _ContentManagementPanelState();
}

class _ContentManagementPanelState extends State<ContentManagementPanel> {
  final TextEditingController _search = TextEditingController();

  final _fandoms = StreamCache<List<FandomDoc>>(
    () => TaxonomyService.instance.watchFandoms(),
  );
  final _categories = StreamCache<List<ContentCategoryDoc>>(
    () => TaxonomyService.instance.watchCategories(),
  );
  final _allContent = StreamCache<List<ContentDoc>>(
    () => ContentService.instance.watchAll(),
  );

  ContentStatus? _status;
  ContentType? _type;
  String? _fandomId;
  String? _categoryId;

  bool _seeding = false;

  @override
  void initState() {
    super.initState();
    // Reference data must exist for the create form. Admin-only write.
    TaxonomyService.instance.seedDefaultsIfEmpty().catchError((_) {});
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int get _filterCount =>
      [_status != null, _type != null, _fandomId != null, _categoryId != null]
          .where((e) => e)
          .length;

  List<ContentDoc> _applyFilters(List<ContentDoc> source) {
    final q = _search.text.trim().toLowerCase();
    return source.where((c) {
      if (_status != null && c.status != _status) return false;
      if (_type != null && c.type != _type) return false;
      if (_fandomId != null && c.fandomId != _fandomId) return false;
      if (_categoryId != null && c.categoryId != _categoryId) return false;
      if (q.isNotEmpty) {
        final haystack =
            '${c.title} ${c.type.label} ${c.fandomName} ${c.categoryName}'
                .toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _confirmDelete(ContentDoc content) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xF2101018),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        title: const Text(
          'Delete Content?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          '“${content.title}”\n\nFans will no longer be able to access this content.',
          style: const TextStyle(color: Colors.white70, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Color(0xFFFF6B6B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ContentService.instance.deleteContent(content.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xE616161F),
            content: Text('Content deleted.'),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xE616161F),
            content: Text('Could not delete this content. Try again.'),
          ),
        );
    }
  }

  Future<void> _seedSample() async {
    if (_seeding) return;
    setState(() => _seeding = true);
    try {
      await ContentService.instance.seedSampleContent();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xE616161F),
            content: Text('Sample discoveries created.'),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xE616161F),
            content: Text('Could not create sample content.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  void _openEditor([ContentDoc? existing]) {
    Navigator.pushNamed(
      context,
      AppRoutes.contentEditor,
      arguments: existing,
    );
  }

  void _openPreview(ContentDoc content) {
    Navigator.pushNamed(
      context,
      AppRoutes.contentDetail,
      arguments: ContentDetailArgs(contentId: content.id, preview: true),
    );
  }

  Future<void> _openFilters(List<FandomDoc> fandoms) async {
    String? fandom = _fandomId;
    String? category = _categoryId;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
              ),
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              decoration: BoxDecoration(
                color: const Color(0xF2101018),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Filter content',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Flexible(
                    child: SingleChildScrollView(
                      child: StreamBuilder<List<ContentCategoryDoc>>(
                        stream: _categories(),
                        builder: (context, catSnap) {
                          final categories =
                              catSnap.data ?? const <ContentCategoryDoc>[];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _MiniLabel('FANDOM'),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _AdminChip(
                                    label: 'All',
                                    selected: fandom == null,
                                    onTap: () =>
                                        setSheetState(() => fandom = null),
                                  ),
                                  for (final f in fandoms)
                                    _AdminChip(
                                      label: f.name,
                                      selected: fandom == f.id,
                                      onTap: () =>
                                          setSheetState(() => fandom = f.id),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              const _MiniLabel('CATEGORY'),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _AdminChip(
                                    label: 'All',
                                    selected: category == null,
                                    onTap: () =>
                                        setSheetState(() => category = null),
                                  ),
                                  for (final c in categories)
                                    _AdminChip(
                                      label: c.name,
                                      selected: category == c.id,
                                      onTap: () => setSheetState(
                                        () => category = c.id,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => setSheetState(() {
                            fandom = null;
                            category = null;
                          }),
                          child: const Text(
                            'Clear',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _fandomId = fandom;
                              _categoryId = category;
                            });
                            Navigator.pop(sheetContext);
                          },
                          child: Container(
                            height: 50,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE50914), Color(0xFF8E0910)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              'Apply',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FandomDoc>>(
      stream: _fandoms(),
      builder: (context, fandomSnap) {
        final fandoms = fandomSnap.data ?? const <FandomDoc>[];
        return StreamBuilder<List<ContentDoc>>(
          stream: _allContent(),
          builder: (context, snap) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminSectionHeader(
                  title: 'Content management',
                  subtitle:
                      'Manage the fandom knowledge and discoveries available to fans.',
                  action: IconButton(
                    onPressed: () => _openEditor(),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.35),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ),
                if (snap.hasError)
                  Expanded(
                    child: ContentErrorState(
                      message:
                          'Content could not be loaded. Confirm Firestore rules include the contents collection.',
                    ),
                  )
                else if (!snap.hasData)
                  const Expanded(
                    child: SingleChildScrollView(
                      child: ContentListSkeleton(count: 4),
                    ),
                  )
                else
                  ..._buildLoaded(snap.data!, fandoms),
              ],
            );
          },
        );
      },
    );
  }

  List<Widget> _buildLoaded(List<ContentDoc> all, List<FandomDoc> fandoms) {
    final filtered = _applyFilters(all);

    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _StatsRow(all: all),
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: _search,
          style: const TextStyle(color: Colors.white),
          cursorColor: AppColors.accent,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search title, type, fandom, category…',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13.5),
            prefixIcon:
                const Icon(Icons.search_rounded, color: Colors.white54, size: 20),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () => setState(_search.clear),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white54,
                      size: 18,
                    ),
                  ),
            filled: true,
            fillColor: const Color(0x59000000),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.accent, width: 1.6),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _AdminFilterButton(
              count: _filterCount,
              onTap: () => _openFilters(fandoms),
            ),
            const SizedBox(width: 8),
            _AdminChip(
              label: 'All',
              selected: _status == null && _type == null,
              onTap: () => setState(() {
                _status = null;
                _type = null;
              }),
            ),
            const SizedBox(width: 8),
            for (final s in ContentStatus.values) ...[
              _AdminChip(
                label: s.label,
                selected: _status == s,
                onTap: () => setState(() => _status = s),
              ),
              const SizedBox(width: 8),
            ],
            for (final t in ContentType.values) ...[
              _AdminChip(
                label: t.label,
                selected: _type == t,
                onTap: () => setState(() => _type = t),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      Expanded(
        child: filtered.isEmpty
            ? _emptyState(all.isEmpty)
            : ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final c = filtered[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AdminContentTile(
                      content: c,
                      onOpen: () => _openPreview(c),
                      onEdit: () => _openEditor(c),
                      onDelete: () => _confirmDelete(c),
                      onToggleFeatured: () => ContentService.instance
                          .setFeatured(c.id, !c.isFeatured),
                      onToggleTrending: () => ContentService.instance
                          .setTrending(c.id, !c.isTrending),
                      onToggleStatus: () => ContentService.instance.setStatus(
                        c.id,
                        c.isPublished
                            ? ContentStatus.draft
                            : ContentStatus.published,
                      ),
                    ),
                  );
                },
              ),
      ),
    ];
  }

  Widget _emptyState(bool noContentAtAll) {
    if (noContentAtAll) {
      return Column(
        children: [
          const Expanded(
            child: ContentEmptyState(
              icon: Icons.auto_stories_outlined,
              title: 'No content created yet',
              message: 'Create your first fandom discovery.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: _SeedButton(seeding: _seeding, onTap: _seedSample),
          ),
        ],
      );
    }
    return const ContentEmptyState(
      icon: Icons.search_off_rounded,
      title: 'No matching content',
      message: 'Try a different search or clear your filters.',
    );
  }
}

class _SeedButton extends StatelessWidget {
  const _SeedButton({required this.seeding, required this.onTap});

  final bool seeding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: seeding ? null : onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (seeding)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            else
              const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: Colors.white,
              ),
            const SizedBox(width: 10),
            Text(
              seeding ? 'Creating samples…' : 'Create sample content',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.all});

  final List<ContentDoc> all;

  @override
  Widget build(BuildContext context) {
    final stats = <(String, int)>[
      ('Total', all.length),
      ('Published', all.where((c) => c.isPublished).length),
      ('Drafts', all.where((c) => !c.isPublished).length),
      ('Featured', all.where((c) => c.isFeatured).length),
      ('Trending', all.where((c) => c.isTrending).length),
    ];
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: stats.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final (label, value) = stats[i];
          final highlight = i == 0;
          return Container(
            width: 104,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: highlight
                    ? [
                        AppColors.primary.withValues(alpha: 0.4),
                        AppColors.primary.withValues(alpha: 0.12),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.09),
                        Colors.white.withValues(alpha: 0.035),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdminContentTile extends StatelessWidget {
  const _AdminContentTile({
    required this.content,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFeatured,
    required this.onToggleTrending,
    required this.onToggleStatus,
  });

  final ContentDoc content;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFeatured;
  final VoidCallback onToggleTrending;
  final VoidCallback onToggleStatus;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 62,
              child: ContentCover(
                content: content,
                aspectRatio: 1,
                radius: 12,
                iconSize: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ContentTypePill(type: content.type, compact: true),
                      const Spacer(),
                      StatusPill(status: content.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (content.fandomName.isNotEmpty) content.fandomName,
                      if (content.categoryName.isNotEmpty) content.categoryName,
                      contentDateLabel(content.displayDate),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (content.isFeatured || content.isTrending) ...[
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (content.isFeatured)
                          const FlagChip(
                            icon: Icons.star_rounded,
                            label: 'FEATURED',
                            color: Color(0xFFF59E0B),
                          ),
                        if (content.isTrending)
                          const FlagChip(
                            icon: Icons.trending_up_rounded,
                            label: 'TRENDING',
                            color: Color(0xFF10B981),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: Colors.white54,
                size: 20,
              ),
              color: const Color(0xF21A1A24),
              onSelected: (value) {
                switch (value) {
                  case 'view':
                    onOpen();
                    break;
                  case 'edit':
                    onEdit();
                    break;
                  case 'status':
                    onToggleStatus();
                    break;
                  case 'featured':
                    onToggleFeatured();
                    break;
                  case 'trending':
                    onToggleTrending();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'view', child: Text('View')),
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'status',
                  child: Text(
                    content.isPublished ? 'Unpublish' : 'Publish',
                  ),
                ),
                PopupMenuItem(
                  value: 'featured',
                  child: Text(
                    content.isFeatured ? 'Remove Featured' : 'Mark Featured',
                  ),
                ),
                PopupMenuItem(
                  value: 'trending',
                  child: Text(
                    content.isTrending ? 'Remove Trending' : 'Mark Trending',
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete',
                    style: TextStyle(color: Color(0xFFFF6B6B)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminFilterButton extends StatelessWidget {
  const _AdminFilterButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? AppColors.primary.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 15,
              color: active ? AppColors.accent : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              active ? 'Filters ($count)' : 'Filters',
              style: TextStyle(
                color: active ? Colors.white : Colors.white70,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminChip extends StatelessWidget {
  const _AdminChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFC1121F), Color(0xFF7F1D1D)],
                )
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withValues(alpha: selected ? 0.3 : 0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _MiniLabel extends StatelessWidget {
  const _MiniLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
