import 'package:flutter/material.dart';

import '../../core/animations/app_transitions.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../widgets/liquid_glass.dart';

/// Admin (or self) view of a user / seller / admin profile.
class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: StreamBuilder<UserProfile?>(
            stream: UserService.instance.watch(uid),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: AppColors.backgroundDeep,
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final profile = snap.data;
              if (profile == null) {
                return Scaffold(
                  backgroundColor: AppColors.backgroundDeep,
                  body: SafeArea(
                    child: Column(
                      children: [
                        _backBar(context),
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
                  ),
                );
              }

              return SafeArea(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  children: [
                    _backBar(context, profile: profile),
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      child: Center(
                        child: Hero(
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
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.25),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: profile.avatarUrl?.isNotEmpty == true
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(29),
                                    child: Image.network(
                                      profile.avatarUrl!,
                                      fit: BoxFit.cover,
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
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 60),
                      child: Center(
                        child: Text(
                          profile.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 90),
                        child: Center(
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
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 120),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: switch (profile.role) {
                              UserRole.admin =>
                                AppColors.primary.withValues(alpha: 0.3),
                              UserRole.seller => const Color(0xFF7C3AED)
                                  .withValues(alpha: 0.3),
                              UserRole.fan =>
                                Colors.white.withValues(alpha: 0.1),
                            },
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
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
                    ),
                    if (_isSelf(profile)) ...[
                      const SizedBox(height: 16),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 160),
                        child: GestureDetector(
                          onTap: () async {
                            final updated = await Navigator.pushNamed(
                              context,
                              AppRoutes.editProfile,
                              arguments: profile,
                            );
                            if (updated == true && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile refreshed'),
                                ),
                              );
                            }
                          },
                          child: LiquidGlass(
                            radius: 999,
                            blur: 16,
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFC1121F),
                                Color(0xFF7F1D1D),
                              ],
                            ),
                            borderColor:
                                Colors.white.withValues(alpha: 0.28),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.edit_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
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
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 200),
                      child: _infoCard(profile),
                    ),
                    if (profile.selectedFandoms.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 240),
                        child: LiquidGlass(
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
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          color: AppColors.primary
                                              .withValues(alpha: 0.2),
                                          border: Border.all(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.45),
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
                        ),
                      ),
                    ],
                    if (profile.isSeller && profile.role != UserRole.admin) ...[
                      const SizedBox(height: 14),
                      LiquidGlass(
                        radius: 18,
                        blur: 20,
                        gradient: const LinearGradient(
                          colors: [
                            Color(0x557C3AED),
                            Color(0x22FFFFFF),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.storefront_rounded,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Shop',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
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
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _initial(UserProfile p) =>
      p.name.isNotEmpty ? p.name.characters.first.toUpperCase() : '?';

  bool _isSelf(UserProfile p) =>
      AuthService.instance.currentUser?.uid == p.uid;

  Widget _backBar(BuildContext context, {UserProfile? profile}) {
    return Row(
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
        Expanded(
          child: Text(
            profile?.shopName?.isNotEmpty == true
                ? profile!.shopName!
                : 'Profile',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (profile != null && _isSelf(profile)) ...[
          IconButton(
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.editProfile,
              arguments: profile,
            ),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.3),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.edit_rounded, size: 20),
          ),
        ],
      ],
    );
  }

  Widget _infoCard(UserProfile profile) {
    final rows = <(IconData, String, String)>[
      (Icons.mail_outline_rounded, 'Email', profile.email),
      if (profile.bio != null && profile.bio!.isNotEmpty)
        (Icons.info_outline_rounded, 'Bio', profile.bio!),
      (
        Icons.people_outline_rounded,
        'Followers',
        profile.followerCount.toString(),
      ),
    ];

    return LiquidGlass(
      radius: 18,
      blur: 20,
      gradient: LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0.04),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: rows
            .map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(r.$1, size: 18, color: Colors.white54),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 72,
                      child: Text(
                        r.$2,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        r.$3,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
