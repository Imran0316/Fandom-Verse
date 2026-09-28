import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/content_docs.dart';
import '../../services/content_service.dart';
import '../../services/stream_cache.dart';
import '../../services/taxonomy_service.dart';
import '../../widgets/content_widgets.dart';
import '../../widgets/skeletons.dart';
import 'content_detail_screen.dart';

enum ContentSort {
  latest('Latest'),
  oldest('Oldest'),
  trending('Trending');

  const ContentSort(this.label);
  final String label;
}

/// Optional pre-applied filters when opening Explore from a fandom card.
class ExploreArgs {
  const ExploreArgs({this.fandomId, this.type});

  final String? fandomId;
  final ContentType? type;
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, this.initialFandomId, this.initialType});

  final String? initialFandomId;
  final ContentType? initialType;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _query = TextEditingController();

  final _fandoms = StreamCache<List<FandomDoc>>(
    () => TaxonomyService.instance.watchFandoms(),
  );
  final _categories = StreamCache<List<ContentCategoryDoc>>(
    () => TaxonomyService.instance.watchCategories(),
  );
  final _published = StreamCache<List<ContentDoc>>(
    () => ContentService.instance.watchPublished(),
  );

  ContentType? _type;
  String? _fandomId;
  String? _categoryId;
  ContentSort _sort = ContentSort.latest;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _fandomId = widget.initialFandomId;
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  int get _activeFilterCount => [
        _type != null,
        _fandomId != null,
        _categoryId != null,
      ].where((e) => e).length;

  List<ContentDoc> _apply(List<ContentDoc> source, List<FandomDoc> fandoms,
      List<ContentCategoryDoc> categories) {
    final q = _query.text.trim().toLowerCase();

    final items = source.where((c) {
      if (_type != null && c.type != _type) return false;
      if (_fandomId != null && c.fandomId != _fandomId) return false;
      if (_categoryId != null && c.categoryId != _categoryId) return false;
      if (q.isNotEmpty) {
        final haystack = [
          c.title,
          c.summary,
          c.body,
          c.question,
          c.answer,
          c.explanation,
          c.fandomName,
          c.categoryName,
          ...c.tags,
        ].join(' ').toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      return true;
    }).toList();

    switch (_sort) {
      case ContentSort.latest:
        items.sort((a, b) => _date(b).compareTo(_date(a)));
        break;
      case ContentSort.oldest:
        items.sort((a, b) => _date(a).compareTo(_date(b)));
        break;
      case ContentSort.trending:
        items.sort((a, b) {
          if (a.isTrending != b.isTrending) return a.isTrending ? -1 : 1;
          return _date(b).compareTo(_date(a));
        });
        break;
    }

    return items;
  }

  static DateTime _date(ContentDoc c) =>
      c.displayDate ?? DateTime.fromMillisecondsSinceEpoch(0);

  void _openContent(ContentDoc content) {
    Navigator.pushNamed(
      context,
      AppRoutes.contentDetail,
      arguments: ContentDetailArgs(contentId: content.id),
    );
  }

  Future<void> _openFilters(List<FandomDoc> fandoms,
      List<ContentCategoryDoc> categories) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        String? fandom = _fandomId;
        String? category = _categoryId;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
              ),
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
              decoration: BoxDecoration(
                color: const Color(0xF2101018),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Refine discoveries',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FilterLabel('Fandom'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ChoiceChip(
                                label: 'All',
                                selected: fandom == null,
                                onTap: () =>
                                    setSheetState(() => fandom = null),
                              ),
                              for (final f in fandoms)
                                _ChoiceChip(
                                  label: f.name,
                                  selected: fandom == f.id,
                                  onTap: () =>
                                      setSheetState(() => fandom = f.id),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const _FilterLabel('Category'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ChoiceChip(
                                label: 'All',
                                selected: category == null,
                                onTap: () =>
                                    setSheetState(() => category = null),
                              ),
                              for (final c in categories)
                                _ChoiceChip(
                                  label: c.name,
                                  selected: category == c.id,
                                  onTap: () =>
                                      setSheetState(() => category = c.id),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            setSheetState(() {
                              fandom = null;
                              category = null;
                            });
                          },
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
                                fontSize: 15,
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
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SafeArea(
            child: StreamBuilder<List<FandomDoc>>(
              stream: _fandoms(),
              builder: (context, fandomSnap) {
                final fandoms = fandomSnap.data ?? const <FandomDoc>[];
                return StreamBuilder<List<ContentCategoryDoc>>(
                  stream: _categories(),
                  builder: (context, catSnap) {
                    final categories =
                        catSnap.data ?? const <ContentCategoryDoc>[];
                    return _buildScaffold(fandoms, categories);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScaffold(
    List<FandomDoc> fandoms,
    List<ContentCategoryDoc> categories,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              const Expanded(
                child: Text(
                  'Explore',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.saved),
                icon: const Icon(
                  Icons.bookmark_border_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _query,
            style: const TextStyle(color: Colors.white),
            cursorColor: AppColors.accent,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search fandoms, stories and discoveries…',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: Colors.white54),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => setState(_query.clear),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white54,
                      ),
                    ),
              filled: true,
              fillColor: const Color(0x59000000),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.14)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: AppColors.accent, width: 1.6),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _FilterButton(
                count: _activeFilterCount,
                onTap: () => _openFilters(fandoms, categories),
              ),
              const SizedBox(width: 8),
              _ChoiceChip(
                label: 'All types',
                selected: _type == null,
                onTap: () => setState(() => _type = null),
              ),
              for (final t in ContentType.values) ...[
                const SizedBox(width: 8),
                _ChoiceChip(
                  label: t.label,
                  selected: _type == t,
                  onTap: () => setState(() => _type = t),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 10, top: 8),
                child: Text(
                  'SORT',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              for (final s in ContentSort.values) ...[
                _ChoiceChip(
                  label: s.label,
                  selected: _sort == s,
                  onTap: () => setState(() => _sort = s),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<List<ContentDoc>>(
            stream: _published(),
            builder: (context, snap) {
              if (snap.hasError) {
                return ContentErrorState(
                  onRetry: () => setState(() {}),
                );
              }
              if (!snap.hasData) {
                return const ContentListSkeleton();
              }
              final results = _apply(snap.data!, fandoms, categories);
              if (results.isEmpty) {
                return ContentEmptyState(
                  icon: Icons.travel_explore_rounded,
                  title: 'No discoveries found',
                  message:
                      'Try a different keyword or fandom to uncover something new.',
                  action: () => setState(() {
                    _query.clear();
                    _type = null;
                    _fandomId = null;
                    _categoryId = null;
                    _sort = ContentSort.latest;
                  }),
                  actionLabel: 'Reset filters',
                );
              }
              return ListView(
                key: const PageStorageKey<String>('explore_results'),
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${results.length} ${results.length == 1 ? 'discovery' : 'discoveries'} found',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  for (final c in results)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ContentRow(
                        content: c,
                        onTap: () => _openContent(c),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label.toUpperCase(),
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

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});

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
              size: 16,
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

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
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
                  colors: [Color(0xFFE50914), Color(0xFF8E0910)],
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
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
