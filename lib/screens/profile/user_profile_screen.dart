import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/follow_docs.dart';
import '../../models/post_docs.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/post_service.dart';
import '../../services/stream_cache.dart';
import '../../services/user_service.dart';
import '../../widgets/follow_button.dart';
import '../../widgets/liquid_glass.dart';
import '../communities/post_card.dart';

/// Social-style profile: gradient banner, overlapping avatar, follower
/// stats, Follow button (other users) / requests inbox + edit (yourself),
/// and the author's posts.
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.uid});

  final String uid;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late final _profile = StreamCache<UserProfile?>(
    () => UserService.instance.watch(widget.uid),
  );
  late final _posts = StreamCache<List<PostDoc>>(
    () => PostService.instance.watchAuthorPosts(widget.uid),
  );
  final _requests = StreamCache<List<FollowDoc>>(
    () => UserService.instance.watchFollowRequests(),
  );

  bool get _isSelf => AuthService.instance.currentUser?.uid == widget.uid;

  String _initial(UserProfile p) =>
      p.name.isNotEmpty ? p.name.characters.first.toUpperCase() : '?';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: StreamBuilder<UserProfile?>(
            stream: _profile(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  snap.data == null) {
                return const Scaffold(
                  backgroundColor: AppColors.backgroundDeep,
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final profile = snap.data;
              if (profile == null) {
                return SafeArea(
                  child: Column(
                    children: [
                      _backBar(),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Profile not found',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return StreamBuilder<List<PostDoc>>(
                stream: _posts(),
                builder: (context, postsSnap) {
                  final posts = postsSnap.data ?? const <PostDoc>[];
                  final postsWaiting = postsSnap.connectionState ==
                          ConnectionState.waiting &&
                      postsSnap.data == null;
                  return SafeArea(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 28),
                      children: [
                        _banner(profile),
                        const SizedBox(height: 58),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Text(
                                  profile.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (profile.bio != null &&
                                  profile.bio!.isNotEmpty) ...[
                                const SizedBox(height: 7),
                                Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                        maxWidth: 340),
                                    child: Text(
                                      profile.bio!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: switch (profile.role) {
                                      UserRole.admin => AppColors.primary
                                          .withValues(alpha: 0.3),
                                      UserRole.seller =>
                                        const Color(0xFF7C3AED)
                                            .withValues(alpha: 0.3),
                                      UserRole.fan => Colors.white
                                          .withValues(alpha: 0.1),
                                    },
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Text(
                                    profile.roleLabel.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              _statsRow(profile, posts.length),
                              const SizedBox(height: 18),
                              if (_isSelf) ...[
                                _EditProfileButton(profile: profile),
                              ] else ...[
                                FollowButton(targetUid: profile.uid),
                              ],
                              const SizedBox(height: 20),
                              if (profile.selectedFandoms.isNotEmpty) ...[
                                _interestsCard(profile),
                                const SizedBox(height: 14),
                              ],
                              if (profile.isSeller &&
                                  profile.role != UserRole.admin) ...[
                                _shopCard(profile),
                                const SizedBox(height: 14),
                              ],
                              _postsHeader(),
                              const SizedBox(height: 12),
                              postsWaiting
                                  ? const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 24),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                  : posts.isEmpty
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 22),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            color: Colors.white
                                                .withValues(alpha: 0.05),
                                            border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.1),
                                            ),
                                          ),
                                          child: const Text(
                                            'No posts yet',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white54,
                                              fontSize: 13,
                                            ),
                                          ),
                                        )
                                      : Column(
                                          children: [
                                            for (final p in posts)
                                              Padding(
                                                key: ValueKey(p.id),
                                                padding: const EdgeInsets.only(
                                                    bottom: 12),
                                                child: PostCard(
                                                  post: p,
                                                  onChanged: () {},
                                                ),
                                              ),
                                          ],
                                        ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /* --------------------------------- Banner -------------------------------- */

  Widget _banner(UserProfile profile) {
    final bannerColors = switch (profile.role) {
      UserRole.admin => const [Color(0xFFC1121F), Color(0xFF7F1D1D)],
      UserRole.seller => const [Color(0xFF7C3AED), Color(0xFF4C1D95)],
      UserRole.fan => const [Color(0xFF3B82F6), Color(0xFF14273F)],
    };
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 132,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                bannerColors[0].withValues(alpha: 0.85),
                bannerColors[1].withValues(alpha: 0.7),
                AppColors.backgroundDeep,
              ],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.4, -0.6),
                radius: 1.2,
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(top: 8, left: 8, child: _backBar(overlay: true)),
        if (_isSelf)
          Positioned(
            top: 8,
            right: 8,
            child: StreamBuilder<List<FollowDoc>>(
              stream: _requests(),
              builder: (context, reqSnap) {
                final count = reqSnap.data?.length ?? 0;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.followRequests,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.3),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                    ),
                    if (count > 0)
                      Positioned(
                        right: 5,
                        top: 5,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFC1121F),
                          ),
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: -46,
          child: Center(child: _avatar(profile)),
        ),
      ],
    );
  }

  Widget _avatar(UserProfile profile) {
    return Hero(
      tag: 'avatar-${profile.uid}',
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: switch (profile.role) {
              UserRole.admin => const [
                  Color(0xFFC1121F),
                  Color(0xFF7F1D1D),
                ],
              UserRole.seller => const [
                  Color(0xFF7C3AED),
                  Color(0xFF4C1D95),
                ],
              UserRole.fan => const [
                  Color(0xFF3B82F6),
                  Color(0xFF1E3A5F),
                ],
            },
          ),
          border: Border.all(color: AppColors.backgroundDeep, width: 4),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: profile.avatarUrl?.isNotEmpty == true
            ? ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Image.network(
                  profile.avatarUrl!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => Center(
                    child: Text(
                      _initial(profile),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  _initial(profile),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
      ),
    );
  }

  /* --------------------------------- Stats --------------------------------- */

  Widget _statsRow(UserProfile profile, int postCount) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatColumn(
              label: 'Posts',
              value: postCount,
            ),
          ),
          Container(width: 1, height: 30, color: Colors.white12),
          Expanded(
            child: _StatColumn(
              label: 'Followers',
              value: profile.followerCount,
            ),
          ),
          Container(width: 1, height: 30, color: Colors.white12),
          Expanded(
            child: _StatColumn(
              label: 'Following',
              value: profile.followingCount,
            ),
          ),
        ],
      ),
    );
  }

  /* ------------------------------- Sections -------------------------------- */

  Widget _interestsCard(UserProfile profile) {
    return LiquidGlass(
      radius: 18,
      blur: 20,
      gradient: LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0.04),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fandom interests',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: profile.selectedFandoms
                .map(
                  (f) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: AppColors.primary.withValues(alpha: 0.2),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      f,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _shopCard(UserProfile profile) {
    return LiquidGlass(
      radius: 18,
      blur: 20,
      gradient: const LinearGradient(
        colors: [Color(0x557C3AED), Color(0x22FFFFFF)],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.storefront_rounded, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Shop',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  profile.shopName?.isNotEmpty == true
                      ? profile.shopName!
                      : '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _postsHeader() {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Posts',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  /* ------------------------------- Back bar -------------------------------- */

  Widget _backBar({bool overlay = false}) {
    return IconButton(
      onPressed: () => Navigator.pop(context),
      style: IconButton.styleFrom(
        backgroundColor: overlay
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.08),
        foregroundColor: Colors.white,
      ),
      icon: const Icon(Icons.arrow_back_rounded),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}

class _EditProfileButton extends StatelessWidget {
  const _EditProfileButton({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.editProfile,
        arguments: profile,
      ),
      child: LiquidGlass(
        radius: 999,
        blur: 16,
        gradient: const LinearGradient(
          colors: [Color(0xFFC1121F), Color(0xFF7F1D1D)],
        ),
        borderColor: Colors.white.withValues(alpha: 0.28),
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Edit profile',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
