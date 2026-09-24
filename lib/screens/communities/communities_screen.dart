import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/community_docs.dart';
import '../../services/auth_service.dart';
import '../../services/community_service.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/liquid_glass.dart';
import '../../core/animations/app_transitions.dart';

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  bool _joinedOnly = false;

  Future<void> _openCreate() async {
    final created = await Navigator.pushNamed<bool>(
      context,
      AppRoutes.createCommunity,
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Community created')),
      );
    }
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
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Communities',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _openCreate,
                        tooltip: 'Create community',
                        style: IconButton.styleFrom(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.3),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: !_joinedOnly,
                        onTap: () => setState(() => _joinedOnly = false),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Joined',
                        selected: _joinedOnly,
                        onTap: () => setState(() => _joinedOnly = true),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<CommunityDoc>>(
                    stream: _joinedOnly
                        ? CommunityService.instance.watchJoined()
                        : CommunityService.instance.watchAll(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final items = snap.data ?? const <CommunityDoc>[];
                      if (items.isEmpty) {
                        return _EmptyCommunities(
                          joinedOnly: _joinedOnly,
                          onBrowseAll: _joinedOnly
                              ? () => setState(() => _joinedOnly = false)
                              : null,
                        );
                      }
                      return ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final c = items[i];
                          return FadeSlideIn(
                            delay: Duration(milliseconds: 40 * i.clamp(0, 8)),
                            child: _CommunityTile(community: c),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFC1121F), Color(0xFF7F1D1D)],
                )
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.08),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}

class _CommunityTile extends StatelessWidget {
  const _CommunityTile({required this.community});

  final CommunityDoc community;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: 18,
      blur: 22,
      gradient: LinearGradient(
        colors: [
          community.color.withValues(alpha: 0.2),
          Colors.white.withValues(alpha: 0.05),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.communityDetail,
            arguments: community.id,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      community.color,
                      community.color.withValues(alpha: 0.55),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Icon(community.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (community.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        community.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.people_alt_rounded,
                          size: 13,
                          color: community.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${community.memberCount} member${community.memberCount == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: community.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCommunities extends StatelessWidget {
  const _EmptyCommunities({
    required this.joinedOnly,
    this.onBrowseAll,
  });

  final bool joinedOnly;
  final VoidCallback? onBrowseAll;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LiquidGlass(
              radius: 28,
              blur: 20,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.28),
                  Colors.white.withValues(alpha: 0.06),
                ],
              ),
              padding: const EdgeInsets.all(22),
              child: const Icon(
                Icons.diversity_3_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              joinedOnly ? 'No communities yet' : 'No communities found',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              joinedOnly
                  ? 'Join a fandom crew or create your own.'
                  : 'Be the first — spin up a community for your fandom.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 220,
              child: GlassButton(
                label: joinedOnly ? 'Browse all' : 'Create community',
                icon: joinedOnly
                    ? Icons.explore_rounded
                    : Icons.add_rounded,
                onPressed: () {
                  if (joinedOnly) {
                    onBrowseAll?.call();
                  } else {
                    Navigator.pushNamed(context, AppRoutes.createCommunity);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Create-community form (full-screen route).
class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  String _iconName = 'anime';
  String _colorName = 'rose';
  bool _saving = false;

  static const _iconChoices = [
    ('anime', Icons.theaters_rounded),
    ('gaming', Icons.sports_esports_rounded),
    ('movies', Icons.movie_rounded),
    ('kpop', Icons.headphones_rounded),
    ('comics', Icons.auto_stories_rounded),
    ('music', Icons.music_note_rounded),
    ('sports', Icons.sports_soccer_rounded),
    ('tech', Icons.memory_rounded),
  ];

  static const _colorChoices = [
    ('rose', Color(0xFFE11D48)),
    ('purple', Color(0xFFA855F7)),
    ('blue', Color(0xFF3B82F6)),
    ('green', Color(0xFF10B981)),
    ('amber', Color(0xFFF59E0B)),
    ('cyan', Color(0xFF06B6D4)),
  ];

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name must be at least 3 characters')),
      );
      return;
    }
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await CommunityService.instance.create(
        name: name,
        description: _description.text.trim(),
        ownerUid: uid,
        iconName: _iconName,
        colorName: _colorName,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'New community',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                AppTextField(
                  controller: _name,
                  label: 'Community name',
                  prefixIcon: Icons.groups_rounded,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _description,
                  label: 'Description (optional)',
                  prefixIcon: Icons.notes_rounded,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Icon',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final (key, icon) in _iconChoices)
                      GestureDetector(
                        onTap: () => setState(() => _iconName = key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: _iconName == key
                                ? AppColors.primary.withValues(alpha: 0.35)
                                : Colors.white.withValues(alpha: 0.08),
                            border: Border.all(
                              color: _iconName == key
                                  ? AppColors.primary
                                  : Colors.white.withValues(alpha: 0.14),
                              width: _iconName == key ? 2 : 1,
                            ),
                          ),
                          child: Icon(
                            icon,
                            color: _iconName == key
                                ? Colors.white
                                : Colors.white70,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Color',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final (key, color) in _colorChoices)
                      GestureDetector(
                        onTap: () => setState(() => _colorName = key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            border: Border.all(
                              color: _colorName == key
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: _colorName == key
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.6),
                                      blurRadius: 14,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                GlassButton(
                  label: 'Create community',
                  isLoading: _saving,
                  onPressed: _saving ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
