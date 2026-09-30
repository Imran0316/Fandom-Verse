import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/community_docs.dart';
import '../../services/community_service.dart';
import '../../services/image_upload_service.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/cached_image.dart';
import '../../widgets/glass_button.dart';

/// Owner-only form to update a community's name, description, cover image
/// and profile image. Prefilled from the [CommunityDoc] passed as the route
/// argument; saves through [CommunityService.updateCommunity] (merge write,
/// so counts and createdAt are untouched).
class EditCommunityScreen extends StatefulWidget {
  const EditCommunityScreen({super.key, required this.community});

  final CommunityDoc community;

  @override
  State<EditCommunityScreen> createState() => _EditCommunityScreenState();
}

class _EditCommunityScreenState extends State<EditCommunityScreen> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late String _iconName;
  late String _colorName;
  late String? _coverUrl;
  late String? _profileUrl;
  bool _saving = false;
  bool _uploadingCover = false;
  bool _uploadingProfile = false;

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
  void initState() {
    super.initState();
    final community = widget.community;
    _name = TextEditingController(text: community.name);
    _description = TextEditingController(text: community.description);
    _iconName = community.iconName;
    _colorName = community.colorName;
    _coverUrl = community.coverImageUrl;
    _profileUrl = community.profileImageUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    if (_uploadingCover) return;
    setState(() => _uploadingCover = true);
    try {
      final url = await ImageUploadService.instance.pickAndUpload(
        name: 'community-cover',
      );
      if (url != null) setState(() => _coverUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ImageUploadService.friendlyMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  Future<void> _pickProfile() async {
    if (_uploadingProfile) return;
    setState(() => _uploadingProfile = true);
    try {
      final url = await ImageUploadService.instance.pickAndUpload(
        name: 'community-profile',
      );
      if (url != null) setState(() => _profileUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ImageUploadService.friendlyMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingProfile = false);
    }
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name must be at least 3 characters')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await CommunityService.instance.updateCommunity(widget.community.id, {
        'name': name,
        'description': _description.text.trim(),
        'iconName': _iconName,
        'colorName': _colorName,
        'profileImageUrl': _profileUrl,
        'coverImageUrl': _coverUrl,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Community updated')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final text = e.toString();
      final friendly = text.contains('permission')
          ? 'Not allowed — publish updated firestore.rules and try again.'
          : 'Save failed: $text';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendly)),
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
                      'Edit community',
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
                  'Cover image',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Shown at the top of your community page',
                  style: TextStyle(color: Colors.white38, fontSize: 11.5),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _uploadingCover ? null : _pickCover,
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF23233A), Color(0xFF14141C)],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: _uploadingCover
                        ? const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: AppColors.accent,
                            ),
                          )
                        : _coverUrl != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedImage(
                                    url: _coverUrl,
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        color: Colors.black.withValues(
                                            alpha: 0.6),
                                      ),
                                      child: const Text(
                                        'Change',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_outlined,
                                      color: Colors.white.withValues(alpha: 0.5),
                                      size: 30,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Tap to add a cover',
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.55),
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Profile image',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'The icon shown for your community',
                  style: TextStyle(color: Colors.white38, fontSize: 11.5),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _uploadingProfile ? null : _pickProfile,
                  child: Row(
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF23233A), Color(0xFF14141C)],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                        child: _uploadingProfile
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(22),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: AppColors.accent,
                                  ),
                                ),
                              )
                            : _profileUrl != null
                                ? CachedImage(
                                    url: _profileUrl,
                                    fit: BoxFit.cover,
                                  )
                                : Icon(
                                    Icons.add_a_photo_outlined,
                                    color:
                                        Colors.white.withValues(alpha: 0.5),
                                    size: 24,
                                  ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _profileUrl != null
                              ? 'Looks good! Tap to change.'
                              : 'Tap to upload a profile picture',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                  label: 'Save changes',
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
