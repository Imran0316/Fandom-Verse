import 'package:flutter/material.dart';

import '../../core/animations/app_transitions.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/image_upload_service.dart';
import '../../services/user_service.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/lottie_view.dart';

const kAllFandomInterests = [
  'Anime',
  'Manga',
  'Gaming',
  'Movies & TV',
  'Music',
  'K-Pop',
  'Sports',
  'Tech',
  'Comics',
  'Cosplay',
  'Sci-Fi',
  'Fantasy',
];

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, this.profile});

  final UserProfile? profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _bio;
  late final TextEditingController _avatar;
  late final TextEditingController _shop;
  late Set<String> _fandoms;
  bool _saving = false;
  bool _uploadingAvatar = false;

  Future<void> _uploadAvatar() async {
    if (_uploadingAvatar) return;
    setState(() => _uploadingAvatar = true);
    try {
      final url = await ImageUploadService.instance.pickAndUpload(
        name: 'avatar',
      );
      if (url != null) {
        _avatar.text = url;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ImageUploadService.friendlyMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p?.name ?? '');
    _bio = TextEditingController(text: p?.bio ?? '');
    _avatar = TextEditingController(text: p?.avatarUrl ?? '');
    _shop = TextEditingController(text: p?.shopName ?? '');
    _fandoms = {...?p?.selectedFandoms};
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _avatar.dispose();
    _shop.dispose();
    super.dispose();
  }

  void _toggle(String f) {
    setState(() {
      if (!_fandoms.add(f)) _fandoms.remove(f);
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name must be at least 2 characters')),
      );
      return;
    }
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      await UserService.instance.updateProfile(
        uid,
        name: name,
        bio: _bio.text.trim(),
        avatarUrl: _avatar.text.trim(),
        selectedFandoms: _fandoms.toList(),
      );
      if (!mounted) return;
      await showSuccessSheet(
        context,
        title: 'Profile saved',
        message: 'Your public profile is up to date.',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSeller = widget.profile?.isSeller == true;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.08),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Edit profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      LottieView(
                        width: 40,
                        height: 40,
                        asset: 'assets/lottie/sparkle.json',
                        fallback: const PulseDot(size: 36),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    FadeSlideIn(
                      child: AppTextField(
                        controller: _name,
                        label: 'Display name',
                      prefixIcon: Icons.person_outline_rounded,
                      validator: (_) => null,
                    ),
                    ),
                    const SizedBox(height: 14),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 60),
                      child: AppTextField(
                        controller: _bio,
                        label: 'Bio',
                        prefixIcon: Icons.notes_rounded,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 120),
                      child: AppTextField(
                        controller: _avatar,
                        label: 'Avatar image URL',
                        prefixIcon: Icons.image_outlined,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 140),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: GlassButton(
                          label: _uploadingAvatar
                              ? 'Uploading…'
                              : 'Upload photo',
                          isLoading: _uploadingAvatar,
                          icon: Icons.upload_rounded,
                          variant: GlassButtonVariant.outline,
                          onPressed: _uploadingAvatar ? null : _uploadAvatar,
                        ),
                      ),
                    ),
                    if (isSeller) ...[
                      const SizedBox(height: 14),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 160),
                        child: AppTextField(
                          controller: _shop,
                          label: 'Shop name',
                          prefixIcon: Icons.storefront_outlined,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fandom interests',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tap to add or remove — used to personalize Home.',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: kAllFandomInterests.map((f) {
                              final selected = _fandoms.contains(f);
                              return GestureDetector(
                                onTap: () => _toggle(f),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
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
                                          ? Colors.white.withValues(alpha: 0.28)
                                          : Colors.white.withValues(alpha: 0.14),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (selected) ...[
                                        const Icon(
                                          Icons.check_rounded,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Text(
                                        f,
                                        style: TextStyle(
                                          color: selected
                                              ? Colors.white
                                              : Colors.white70,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 260),
                      child: GlassButton(
                        label: _saving ? 'Saving…' : 'Save changes',
                        isLoading: _saving,
                        icon: Icons.check_rounded,
                        onPressed: _saving ? null : _save,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Multi-select interests editor (reuses chips UI).
class InterestsEditorScreen extends StatefulWidget {
  const InterestsEditorScreen({super.key, this.initial});

  final List<String>? initial;

  @override
  State<InterestsEditorScreen> createState() => _InterestsEditorScreenState();
}

class _InterestsEditorScreenState extends State<InterestsEditorScreen> {
  late Set<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = {...?widget.initial};
  }

  Future<void> _save() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await UserService.instance.updateProfile(
        uid,
        selectedFandoms: _selected.toList(),
      );
      if (!mounted) return;
      await showSuccessSheet(
        context,
        title: 'Interests updated',
        message: 'Home will personalize around your picks.',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
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
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.08),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const Text(
                        'My fandom interests',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    for (var i = 0; i < kAllFandomInterests.length; i++)
                      FadeSlideIn(
                        delay: Duration(milliseconds: i * 40),
                        child: _InterestRow(
                          label: kAllFandomInterests[i],
                          selected: _selected.contains(kAllFandomInterests[i]),
                          onTap: () => setState(() {
                            final f = kAllFandomInterests[i];
                            if (!_selected.add(f)) _selected.remove(f);
                          }),
                        ),
                      ),
                    const SizedBox(height: 20),
                    GlassButton(
                      label: 'Save interests',
                      isLoading: _saving,
                      onPressed: _saving ? null : _save,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InterestRow extends StatelessWidget {
  const _InterestRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFFC1121F), Color(0xFF7F1D1D)],
                  )
                : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.category_rounded,
                size: 20,
                color: selected ? Colors.white : Colors.white54,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AnimatedScale(
                scale: selected ? 1 : 0.01,
                duration: const Duration(milliseconds: 180),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
