import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/content_docs.dart';
import '../../models/post_docs.dart';
import '../../services/entities/deep_dive_models.dart';
import '../../services/entities/deep_dive_registry.dart';
import '../../services/post_service.dart';
import '../../widgets/cached_image.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/skeletons.dart';

/// In-content Deep Dive: opens a live graph from a News / Article / Lore /
/// Trivia story and walks it hop by hop —
///
/// story → title → cast → voice actor / actor / studio / artist →
/// their other works → FanVerse posts.
///
/// The domain (anime, movies/TV, games, music) is detected from the
/// story's fandom / category / tags; each domain's provider fills the
/// same chain shape with its own data source. Each hop is a horizontal
/// rail; tapping a card re-focuses the chain below it. Renders nothing
/// when no entity matches the story.
class ContentDeepDive extends StatefulWidget {
  const ContentDeepDive({super.key, required this.content, this.providers});

  final ContentDoc content;

  /// Injectable for tests; defaults to the detected provider cascade.
  final List<DeepDiveProvider>? providers;

  /// Search candidates for the story's anchor entity: specific tags
  /// first, then the title. Generic editorial tags are skipped, capped
  /// at three.
  static const Set<String> genericTags = {
    'anime',
    'manga',
    'news',
    'season',
    'seasons',
    'world',
    'facts',
    'fact',
    'hidden',
    'lore',
    'guide',
    'list',
    'story',
    'update',
    'updates',
    'theory',
    'history',
    'fan',
    'fandom',
    'game',
    'games',
    'gaming',
    'music',
    'movie',
    'movies',
    'film',
    'films',
    'tv',
    'series',
    'show',
    'song',
    'songs',
    'album',
    'albums',
    'artist',
    'band',
    'concert',
    'episode',
    'episodes',
    'drama',
    'cinema',
    'esports',
    'kpop',
    'k-pop',
    'trailer',
    'review',
    'reviews',
  };

  static List<String> anchorQueries(ContentDoc content) {
    final out = <String>[];
    final seen = <String>{};
    void add(String raw) {
      final value = raw.trim();
      if (value.isEmpty) return;
      final key = value.toLowerCase();
      if (seen.contains(key)) return;
      seen.add(key);
      out.add(value);
    }

    for (final tag in content.tags) {
      if (!genericTags.contains(tag.trim().toLowerCase())) add(tag);
    }
    add(content.title);
    return out.take(3).toList();
  }

  @override
  State<ContentDeepDive> createState() => _ContentDeepDiveState();
}

class _ContentDeepDiveState extends State<ContentDeepDive> {
  late final List<DeepDiveProvider> _candidates;
  DeepDiveProvider? _provider;
  late final Stream<List<PostDoc>> _posts;
  final _worksCache = <String, List<DiveMedia>>{};

  String _personKey(DivePerson person) => '${person.kind ?? ''}:${person.id}';

  bool _loading = true;
  bool _hidden = false;
  List<DiveMedia> _anchors = const [];
  DiveMedia? _media;
  DiveCharacter? _character;
  DivePerson? _person;
  List<DiveMedia> _works = const [];
  bool _worksLoading = false;
  bool _castLoading = false;

  @override
  void initState() {
    super.initState();
    _candidates = (widget.providers ?? const <DeepDiveProvider>[])
        .isEmpty
        ? DeepDiveRegistry.forContent(widget.content)
        : widget.providers!.where((p) => p.isAvailable).toList();
    _posts = PostService.instance.watchFeed();
    _bootstrap();
  }

  /// Provider currently driving labels: the matched one, else the lead
  /// candidate while still loading.
  DeepDiveProvider? get _active =>
      _provider ?? (_candidates.isEmpty ? null : _candidates.first);

  Future<void> _bootstrap() async {
    final queries = ContentDeepDive.anchorQueries(widget.content);
    for (final provider in _candidates) {
      for (final query in queries) {
        List<DiveMedia> results;
        try {
          results = await provider.search(query);
        } catch (_) {
          continue;
        }
        final matched = [
          for (final media in results)
            if (_matches(query, media)) media,
        ];
        if (matched.isEmpty) continue;
        final media = matched.first;
        final character = _defaultCharacter(media);
        final person = _firstPerson(character, media);
        if (!mounted) return;
        setState(() {
          _loading = false;
          _provider = provider;
          _anchors = matched;
          _media = media;
          _character = character;
          _person = person;
          _works = person == null ? const [] : (_worksCache[_personKey(person)] ?? const []);
          _worksLoading = person != null && !_worksCache.containsKey(_personKey(person));
          _castLoading = media.cast.isEmpty;
        });
        if (person != null) _loadWorks(person);
        if (media.cast.isEmpty) _fetchCast(media);
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _hidden = true;
    });
  }

  bool _matches(String query, DiveMedia media) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return false;
    final titles = [media.title, media.romaji, media.english]
        .where((t) => t != null && t.isNotEmpty)
        .map((t) => t!.toLowerCase())
        .toList();
    if (titles.isEmpty) return false;
    for (final title in titles) {
      if (title.contains(q) || q.contains(title)) return true;
    }
    final tokens = q
        .split(RegExp('[^a-z0-9]+'))
        .where((w) => w.length >= 4);
    for (final token in tokens) {
      if (titles.any((title) => title.contains(token))) return true;
    }
    return false;
  }

  DiveCharacter? _defaultCharacter(DiveMedia media) {
    if (media.cast.isEmpty) return null;
    for (final member in media.cast) {
      if (member.role == 'MAIN') return member.character;
    }
    return media.cast.first.character;
  }

  DiveCastMember? _castMemberFor(DiveCharacter? character) {
    final media = _media;
    if (character == null || media == null) return null;
    for (final member in media.cast) {
      if (member.character.id == character.id) return member;
    }
    return null;
  }

  DivePerson? _firstPerson(DiveCharacter? character, DiveMedia media) {
    if (character == null) return null;
    for (final member in media.cast) {
      if (member.character.id == character.id &&
          member.voiceActors.isNotEmpty) {
        return member.voiceActors.first;
      }
    }
    return null;
  }

  Future<void> _focusMedia(DiveMedia media) async {
    if (media.id == _media?.id &&
        media.kind == _media?.kind &&
        !_castLoading) {
      return;
    }
    final character = _defaultCharacter(media);
    final person = _firstPerson(character, media);
    if (!mounted) return;
    setState(() {
      _media = media;
      _character = character;
      _person = person;
      _works = person == null ? const [] : (_worksCache[_personKey(person)] ?? const []);
      _worksLoading = person != null && !_worksCache.containsKey(_personKey(person));
      _castLoading = media.cast.isEmpty;
    });
    if (person != null) _loadWorks(person);
    if (media.cast.isEmpty) _fetchCast(media);
  }

  /// Loads cast for a media node that was found without one (TMDB, RAWG,
  /// AniList staff works), then re-focuses the defaults.
  Future<void> _fetchCast(DiveMedia media) async {
    final provider = _provider;
    if (provider == null) return;
    List<DiveCastMember> cast;
    try {
      cast = await provider.loadCast(media);
    } catch (_) {
      cast = const [];
    }
    if (!mounted) return;
    final current = _media;
    if (current == null || current.id != media.id || current.kind != media.kind) {
      return;
    }
    final updated = media.copyWith(cast: cast);
    final character = _defaultCharacter(updated);
    final person = _firstPerson(character, updated);
    setState(() {
      _media = updated;
      _anchors = [
        for (final a in _anchors)
          if (a.id != updated.id || a.kind != updated.kind) a else updated,
      ];
      _character = character;
      _person = person;
      _works = person == null ? const [] : (_worksCache[_personKey(person)] ?? const []);
      _worksLoading = person != null && !_worksCache.containsKey(_personKey(person));
      _castLoading = false;
    });
    if (person != null) _loadWorks(person);
  }

  void _focusCharacter(DiveCastMember member) {
    if (member.character.id == _character?.id) return;
    final person = member.voiceActors.isEmpty
        ? null
        : member.voiceActors.first;
    if (!mounted) return;
    setState(() {
      _character = member.character;
      _person = person;
      _works = person == null ? const [] : (_worksCache[_personKey(person)] ?? const []);
      _worksLoading = person != null && !_worksCache.containsKey(_personKey(person));
    });
    if (person != null) _loadWorks(person);
  }

  void _focusPerson(DivePerson person) {
    if (person.id == _person?.id) return;
    if (!mounted) return;
    setState(() {
      _person = person;
      _works = _worksCache[_personKey(person)] ?? const [];
      _worksLoading = !_worksCache.containsKey(_personKey(person));
    });
    _loadWorks(person);
  }

  Future<void> _loadWorks(DivePerson person) async {
    final cached = _worksCache[_personKey(person)];
    if (cached != null) {
      if (!mounted || _person?.id != person.id) return;
      setState(() {
        _works = cached;
        _worksLoading = false;
      });
      return;
    }
    final provider = _provider;
    if (provider == null) return;
    DivePerson? full;
    try {
      full = await provider.loadPerson(person);
    } catch (_) {
      full = null;
    }
    if (!mounted || _person?.id != person.id) return;
    final works = full?.works ?? const <DiveMedia>[];
    if (full != null) _worksCache[_personKey(person)] = works;
    setState(() {
      _works = works;
      _worksLoading = false;
    });
  }

  List<PostDoc> _matchingPosts(List<PostDoc> posts) {
    final media = _media;
    if (media == null) return const [];
    final phrases = <String>{};
    for (final raw in [media.title, media.romaji, media.english, _person?.name]) {
      final value = raw?.trim().toLowerCase();
      if (value != null && value.isNotEmpty) phrases.add(value);
    }
    final tokens = media.title
        .toLowerCase()
        .split(RegExp('[^a-z0-9]+'))
        .where((w) => w.length >= 4)
        .toSet();
    final matched = <PostDoc>[];
    for (final post in posts) {
      final body = post.body.toLowerCase();
      if (phrases.any(body.contains) || tokens.any(body.contains)) {
        matched.add(post);
        if (matched.length >= 6) break;
      }
    }
    return matched;
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    if (_hidden || active == null) return const SizedBox.shrink();
    final media = _media;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        if (_loading) ...[
          _label(active.mediaLabel(null)),
          const SizedBox(height: 10),
          _skeletonRail(256),
          const SizedBox(height: 16),
          _label(active.castLabel),
          const SizedBox(height: 10),
          _skeletonRail(216),
        ] else if (media != null) ...[
          _label(active.mediaLabel(media)),
          const SizedBox(height: 10),
          _mediaRail(),
          if (_castLoading) ...[
            const SizedBox(height: 16),
            _label(active.castLabel),
            const SizedBox(height: 10),
            _skeletonRail(216),
          ] else if (_showCastRail) ...[
            const SizedBox(height: 16),
            _label(active.castLabel),
            const SizedBox(height: 10),
            _characterRail(),
          ],
          if (!_castLoading &&
              _character != null &&
              _characterVoiceActors.isNotEmpty) ...[
            const SizedBox(height: 16),
            _label(active.personLabel),
            const SizedBox(height: 10),
            _personRail(),
            if (_person != null) ...[
              const SizedBox(height: 16),
              _label('MORE FROM ${_person!.name.toUpperCase()}'),
              const SizedBox(height: 10),
              if (_worksLoading)
                _skeletonRail(256)
              else if (_visibleWorks.isNotEmpty)
                _worksRail(),
            ],
          ],
          _postsRail(),
        ],
      ],
    );
  }

  /// Games/music cast slots describe the same face as their person
  /// (artist = artist, studio = studio); showing both rails would
  /// duplicate the card, so the cast rail collapses for those chains.
  bool get _showCastRail {
    final cast = _media?.cast ?? const [];
    if (cast.isEmpty) return false;
    for (final member in cast) {
      if (member.voiceActors.isEmpty) return true;
      final personName = member.voiceActors.first.name.trim().toLowerCase();
      if (personName != member.character.name.trim().toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  List<DivePerson> get _characterVoiceActors {
    final member = _castMemberFor(_character);
    return member?.voiceActors ?? const [];
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          ClipOval(
            child: Image.asset(
              'lib/assets/images/splash/splashScreenLogo.png',
              width: 40,
              height: 40,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.accent],
                  ),
                ),
                child: const Text(
                  'F',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Deep Dive',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _active?.subtitle ??
                      'Characters, cast and related FanVerse posts',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _skeletonRail(double height) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => SkeletonBox(
          width: 152,
          height: height,
          radius: 18,
        ),
      ),
    );
  }

  Widget _mediaRail() {
    final media = _media;
    if (media == null) return const SizedBox.shrink();
    final items = [
      media,
      for (final anchor in _anchors)
        if (anchor.id != media.id || anchor.kind != media.kind) anchor,
    ];
    return SizedBox(
      height: 268,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _MediaCard(
          media: items[i],
          selected: items[i].id == media.id,
          onTap: () => _focusMedia(items[i]),
        ),
      ),
    );
  }

  Widget _characterRail() {
    final media = _media;
    if (media == null) return const SizedBox.shrink();
    return SizedBox(
      height: 216,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: media.cast.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _CharacterCard(
          member: media.cast[i],
          selected: media.cast[i].character.id == _character?.id,
          onTap: () => _focusCharacter(media.cast[i]),
        ),
      ),
    );
  }

  Widget _personRail() {
    final member = _castMemberFor(_character);
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _characterVoiceActors.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _PersonCard(
          person: _characterVoiceActors[i],
          caption: member == null ? null : _active?.personCaption(member),
          selected: _characterVoiceActors[i].id == _person?.id,
          onTap: () => _focusPerson(_characterVoiceActors[i]),
        ),
      ),
    );
  }

  /// Other works, minus the media the chain is currently focused on
  /// (person credits usually include the current title itself).
  List<DiveMedia> get _visibleWorks {
    final media = _media;
    return [
      for (final work in _works)
        if (media == null || work.id != media.id || work.kind != media.kind)
          work,
    ];
  }

  Widget _worksRail() {
    final items = _visibleWorks;
    return SizedBox(
      height: 268,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _MediaCard(
          media: items[i],
          selected: items[i].id == _media?.id,
          onTap: () => _focusMedia(items[i]),
        ),
      ),
    );
  }

  Widget _postsRail() {
    return StreamBuilder<List<PostDoc>>(
      stream: _posts,
      builder: (context, snap) {
        final matched = _matchingPosts(snap.data ?? const []);
        if (matched.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _label('ON FANVERSE'),
            const SizedBox(height: 10),
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: matched.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => _PostMiniCard(
                  post: matched[i],
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.feed),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({
    required this.media,
    required this.selected,
    required this.onTap,
  });

  final DiveMedia media;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (media.format != null && media.format!.isNotEmpty) media.format!,
      if (media.year != null) '${media.year}',
    ].join(' · ');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 152,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? AppColors.accent.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: SizedBox(
                height: 190,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: Colors.white.withValues(alpha: 0.06),
                      child: const Center(
                        child: Icon(
                          Icons.auto_stories_outlined,
                          color: Colors.white24,
                          size: 30,
                        ),
                      ),
                    ),
                    if (media.imageUrl?.isNotEmpty == true)
                      CachedImage(
                        url: media.imageUrl,
                        fit: BoxFit.cover,
                      ),
                    if (media.score != null)
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.black.withValues(alpha: 0.7),
                          ),
                          child: Text(
                            '★ ${(media.score! / 10).toStringAsFixed(1)}',
                            style: const TextStyle(
                              color: Color(0xFFFFD166),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              media.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final DiveCastMember member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final role = member.role;
    final roleColor = role == 'MAIN'
        ? AppColors.accent
        : role == 'SUPPORTING'
            ? const Color(0xFF3B82F6)
            : Colors.white54;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 134,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? AppColors.accent.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: Colors.white.withValues(alpha: 0.06),
                      child: const Center(
                        child: Icon(
                          Icons.person_outline_rounded,
                          color: Colors.white24,
                          size: 30,
                        ),
                      ),
                    ),
                    if (member.character.imageUrl?.isNotEmpty == true)
                      CachedImage(
                        url: member.character.imageUrl,
                        fit: BoxFit.cover,
                      ),
                    if (role.isNotEmpty)
                      Positioned(
                        left: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.black.withValues(alpha: 0.65),
                            border: Border.all(
                              color: roleColor.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Text(
                            role,
                            style: TextStyle(
                              color: roleColor,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              member.character.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.selected,
    required this.onTap,
    this.caption,
  });

  final DivePerson person;
  final bool selected;
  final VoidCallback onTap;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 136,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? AppColors.accent.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? AppColors.accent.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.16),
                  width: selected ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: person.imageUrl?.isNotEmpty == true
                  ? CachedImage(
                      url: person.imageUrl,
                      fit: BoxFit.cover,
                    )
                  : const Icon(
                      Icons.person_outline_rounded,
                      color: Colors.white30,
                      size: 34,
                    ),
            ),
            const SizedBox(height: 9),
            Text(
              person.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (caption != null && caption!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PostMiniCard extends StatelessWidget {
  const _PostMiniCard({required this.post, required this.onTap});

  final PostDoc post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = post.authorName.trim().isNotEmpty
        ? post.authorName.trim()[0].toUpperCase()
        : '?';
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 244,
        child: LiquidGlass(
          radius: 18,
          blur: 18,
          padding: const EdgeInsets.all(12),
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.1),
              Colors.white.withValues(alpha: 0.04),
            ],
          ),
          borderColor: Colors.white.withValues(alpha: 0.14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: post.authorAvatarUrl?.isNotEmpty == true
                        ? CachedImage(
                            url: post.authorAvatarUrl,
                            fit: BoxFit.cover,
                          )
                        : Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      post.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.favorite_rounded,
                    size: 12,
                    color: Color(0xFFFF6B6B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.likeCount}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                post.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
