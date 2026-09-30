import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/catalog_service.dart';
import '../../services/stream_cache.dart';
import '../../services/user_service.dart';
import '../../widgets/cached_image.dart';
import '../../widgets/liquid_glass.dart';
import 'admin_panels.dart';
import 'content_management.dart';

/// Blocks non-admins and shows a lightweight admin console.
class AdminGate extends StatefulWidget {
  const AdminGate({super.key});

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  final _currentProfile = StreamCache<UserProfile?>(
    () => UserService.instance.watchCurrent(),
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: _currentProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const Scaffold(
            backgroundColor: AppColors.backgroundDeep,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final profile = snapshot.data;
        if (profile == null || !profile.isAdmin) {
          return const _AdminDenied();
        }
        return const AdminShell();
      },
    );
  }
}

class _AdminDenied extends StatelessWidget {
  const _AdminDenied();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LiquidGlass(
                radius: 24,
                blur: 20,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.3),
                    Colors.white.withValues(alpha: 0.06),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Admins only',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This console requires the admin role.\nYour account is a fan/seller.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, height: 1.4),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () =>
                    Navigator.pushReplacementNamed(context, AppRoutes.dashboard),
                child: LiquidGlass(
                  radius: 999,
                  blur: 16,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.16),
                      Colors.white.withValues(alpha: 0.07),
                    ],
                  ),
                  child: const Text(
                    'Back to FandomVerse',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _section = 0;

  final _profile = StreamCache<UserProfile?>(
    () => UserService.instance.watchCurrent(),
  );

  static const _sections = [
    (label: 'Overview', icon: Icons.insights_rounded),
    (label: 'Content', icon: Icons.auto_stories_rounded),
    (label: 'Users', icon: Icons.groups_rounded),
    (label: 'Fandoms', icon: Icons.category_rounded),
    (label: 'Posts', icon: Icons.forum_rounded),
    (label: 'Events', icon: Icons.event_rounded),
    (label: 'Merch', icon: Icons.storefront_rounded),
    (label: 'Reports', icon: Icons.flag_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final profileAsync = _profile();

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: StreamBuilder<UserProfile?>(
            stream: profileAsync,
            builder: (context, snap) {
              final profile = snap.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pushReplacementNamed(
                              context,
                              AppRoutes.dashboard,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.08,
                              ),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Admin Console',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          LiquidGlass(
                            radius: 999,
                            blur: 14,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withValues(alpha: 0.45),
                                AppColors.primary.withValues(alpha: 0.2),
                              ],
                            ),
                            borderColor: AppColors.primary.withValues(
                              alpha: 0.5,
                            ),
                            child: Text(
                              profile?.name.isNotEmpty == true
                                  ? profile!.name
                                  : 'Admin',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _sections.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final selected = _section == i;
                        return GestureDetector(
                          onTap: () => setState(() => _section = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: selected
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFC1121F),
                                        Color(0xFF7F1D1D),
                                      ],
                                    )
                                  : null,
                              color: selected
                                  ? null
                                  : Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: selected
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _sections[i].icon,
                                  size: 16,
                                  color: selected
                                      ? Colors.white
                                      : Colors.white70,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _sections[i].label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? Colors.white
                                        : Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _AdminSection(index: _section),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AdminSection extends StatelessWidget {
  const _AdminSection({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    switch (index) {
      case 0:
        return const _OverviewPanel();
      case 1:
        return const ContentManagementPanel();
      case 2:
        return const _UsersPanel();
      case 3:
        return const CategoriesPanel();
      case 4:
        return const ContentModerationPanel();
      case 5:
        return const EventsPanel();
      case 6:
        return const MerchAdminPanel();
      case 7:
        return const ReportsPanel();
      default:
        return const SizedBox.shrink();
    }
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.onTap,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final card = LiquidGlass(
      radius: 18,
      blur: 22,
      gradient: LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.05),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
    final wrapped =
        onTap == null ? card : GestureDetector(onTap: onTap, child: card);
    if (margin == EdgeInsets.zero) return wrapped;
    return Padding(padding: margin, child: wrapped);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _OverviewPanel extends StatefulWidget {
  const _OverviewPanel();

  @override
  State<_OverviewPanel> createState() => _OverviewPanelState();
}

class _OverviewPanelState extends State<_OverviewPanel> {
  int? _users;
  int? _posts;
  int? _communities;
  int? _merch;
  int? _categories;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await CatalogService.instance.seedCategoriesIfEmpty();
      final users = await UserService.instance.countCollection('users');
      final posts = await UserService.instance.countCollection('posts');
      final communities =
          await UserService.instance.countCollection('communities');
      final merch = await UserService.instance.countCollection('merch');
      final categories =
          await UserService.instance.countCollection('categories');
      if (!mounted) return;
      setState(() {
        _users = users;
        _posts = posts;
        _communities = communities;
        _merch = merch;
        _categories = categories;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('Users', _users, Icons.groups_rounded),
      ('Categories', _categories, Icons.category_rounded),
      ('Communities', _communities, Icons.diversity_3_rounded),
      ('Posts', _posts, Icons.forum_rounded),
      ('Merch', _merch, Icons.storefront_rounded),
    ];

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        const _SectionHeader(
          title: 'Platform overview',
          subtitle: 'Live counts from Firestore. Pull the section again after seeding data.',
        ),
        if (_error != null)
          _GlassCard(
            child: Text(
              'Could not load counts: $_error\n'
              'Enable Firestore and deploy rules first.',
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          )
        else
          ...tiles.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GlassCard(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFC1121F), Color(0xFF7F1D1D)],
                        ),
                      ),
                      child: Icon(t.$3, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        t.$1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      t.$2?.toString() ?? '…',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_users != null) ...[
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
          ),
        ],
      ],
    );
  }
}

class _UsersPanel extends StatefulWidget {
  const _UsersPanel();

  @override
  State<_UsersPanel> createState() => _UsersPanelState();
}

class _UsersPanelState extends State<_UsersPanel> {
  final _users = StreamCache<List<UserProfile>>(
    () => UserService.instance.watchAll(),
  );

  String _query = '';
  UserRole? _filter;
  bool _busy = false;

  Future<void> _changeRole(UserProfile target, UserRole next) async {
    final me = AuthService.instance.currentUser?.uid;
    if (target.uid == me && next != UserRole.admin) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xF2101018),
          title: const Text(
            'Demote yourself?',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'You will lose access to the Admin Console immediately.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Demote',
                style: TextStyle(color: AppColors.accent),
              ),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _busy = true);
    try {
      await UserService.instance.setRole(target.uid, next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${target.name} is now ${next.value}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Role change failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openRoleSheet(UserProfile target) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
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
              const SizedBox(height: 16),
              Text(
                target.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                target.email,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ...UserRole.values.map((role) {
                final selected = target.role == role;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: selected || _busy
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            _changeRole(target, role);
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: selected
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFFC1121F),
                                  Color(0xFF7F1D1D),
                                ],
                              )
                            : null,
                        color: selected
                            ? null
                            : Colors.white.withValues(alpha: 0.07),
                        border: Border.all(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            switch (role) {
                              UserRole.fan => Icons.favorite_outline_rounded,
                              UserRole.seller => Icons.storefront_rounded,
                              UserRole.admin =>
                                Icons.admin_panel_settings_rounded,
                            },
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              role.value.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (selected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = AuthService.instance.currentUser?.uid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: _SectionHeader(
            title: 'User management',
            subtitle:
                'Search accounts and change roles. Only admins can write — Firestore rules enforce.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            style: const TextStyle(color: Colors.white),
            cursorColor: AppColors.accent,
            decoration: InputDecoration(
              hintText: 'Search name or email…',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => setState(() => _query = ''),
                      icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    ),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _FilterChip(
                label: 'All',
                selected: _filter == null,
                onTap: () => setState(() => _filter = null),
              ),
              const SizedBox(width: 8),
              ...UserRole.values.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: r.value,
                    selected: _filter == r,
                    onTap: () => setState(() => _filter = r),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<List<UserProfile>>(
            stream: _users(),
            builder: (context, snap) {
              if (snap.hasError) {
                return _GlassCard(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Could not load users:\n${snap.error}\n\n'
                    'Enable Firestore + deploy firestore.rules, then seed an admin.',
                    style: const TextStyle(color: Colors.white70, height: 1.45),
                  ),
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var users = snap.data!;
              if (_filter != null) {
                users = users.where((u) => u.role == _filter).toList();
              }
              if (_query.isNotEmpty) {
                users = users
                    .where(
                      (u) =>
                          u.name.toLowerCase().contains(_query) ||
                          u.email.toLowerCase().contains(_query),
                    )
                    .toList();
              }

              if (users.isEmpty) {
                return const Center(
                  child: Text(
                    'No users match.',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: users.length,
                itemBuilder: (context, i) {
                  final u = users[i];
                  final isSelf = u.uid == me;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _GlassCard(
                      onTap: _busy
                          ? null
                          : () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.userProfile,
                                arguments: u.uid,
                              );
                            },
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF7F1D1D),
                            child: u.avatarUrl?.isNotEmpty == true
                                ? CachedImage(
                                    url: u.avatarUrl,
                                    width: 40,
                                    height: 40,
                                    circular: true,
                                  )
                                : Text(
                                    u.name.isNotEmpty
                                        ? u.name.characters.first
                                            .toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
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
                                        u.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                    ),
                                    if (isSelf) ...[
                                      const SizedBox(width: 6),
                                      const Text(
                                        '(you)',
                                        style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  u.email,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _RolePill(role: u.role),
                          IconButton(
                            tooltip: 'Change role',
                            onPressed: _busy
                                ? null
                                : () => _openRoleSheet(u),
                            icon: const Icon(
                              Icons.swap_horiz_rounded,
                              color: Colors.white54,
                              size: 20,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white38,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ),
          ),
      ],
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
            color: Colors.white.withValues(alpha: selected ? 0.25 : 0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (role) {
      UserRole.admin => ('ADMIN', const Color(0xFFC1121F)),
      UserRole.seller => ('SELLER', const Color(0xFF7C3AED)),
      UserRole.fan => ('FAN', Colors.white24),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: role == UserRole.fan ? 1 : 0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: role == UserRole.fan
              ? Colors.white24
              : color.withValues(alpha: 0.6),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: role == UserRole.fan ? Colors.white70 : Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
