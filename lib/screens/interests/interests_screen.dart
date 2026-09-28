import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/liquid_glass.dart';

class InterestsScreen extends StatefulWidget {
  const InterestsScreen({super.key});

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  static const _interests = <_Interest>[
    _Interest('Gaming', Icons.sports_esports_rounded),
    _Interest('Movies & TV', Icons.movie_outlined),
    _Interest('Music', Icons.music_note_rounded),
    _Interest('Sports', Icons.sports_soccer_rounded),
    _Interest('Tech', Icons.memory_rounded),
    _Interest('Anime', Icons.auto_awesome_rounded),
    _Interest('Manga', Icons.menu_book_rounded),
  ];

  final Set<String> _selected = <String>{};
  bool _saving = false;

  void _toggleInterest(String interest) {
    setState(() {
      if (!_selected.add(interest)) _selected.remove(interest);
    });
  }

  Future<void> _continue() async {
    if (_selected.isEmpty || _saving) return;

    setState(() => _saving = true);
    try {
      final user = AuthService.instance.currentUser;
      if (user != null) {
        await UserService.instance.updateProfile(
          user.uid,
          selectedFandoms: _selected.toList(),
        );
      }
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.dashboard, (route) => false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save interests. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: LiquidGlass(
                radius: 28,
                blur: 28,
                tint: const Color(0x66080810),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.14),
                    Colors.white.withValues(alpha: 0.05),
                    AppColors.primary.withValues(alpha: 0.12),
                  ],
                ),
                borderColor: Colors.white.withValues(alpha: 0.28),
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.favorite_outline_rounded,
                      color: AppColors.accent,
                      size: 34,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'What are you interested in?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose one or more to personalize your experience.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _interests.map(_buildInterest).toList(),
                    ),
                    const SizedBox(height: 28),
                    GlassButton(
                      label: 'Continue',
                      variant: GlassButtonVariant.sleek,
                      isLoading: _saving,
                      onPressed: _selected.isEmpty ? null : _continue,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInterest(_Interest interest) {
    final selected = _selected.contains(interest.label);
    return Semantics(
      button: true,
      selected: selected,
      label: interest.label,
      child: InkWell(
        onTap: () => _toggleInterest(interest.label),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.24)
                : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                interest.icon,
                size: 19,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 9),
              Text(
                interest.label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Interest {
  const _Interest(this.label, this.icon);

  final String label;
  final IconData icon;
}
