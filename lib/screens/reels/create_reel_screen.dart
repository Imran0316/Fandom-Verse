import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/community_docs.dart';
import '../../services/auth_service.dart';
import '../../services/community_service.dart';
import '../../services/reel_service.dart';
import '../../services/stream_cache.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/liquid_glass.dart';

/// Pick a short video → upload to Cloudinary → post to a community.
///
/// [initialCommunity] preselects the community (opened from a community's
/// page). [joinedCommunities] is a test seam.
class CreateReelScreen extends StatefulWidget {
  const CreateReelScreen({
    super.key,
    this.initialCommunity,
    this.joinedCommunities,
  });

  final CommunityDoc? initialCommunity;
  final Stream<List<CommunityDoc>>? joinedCommunities;

  @override
  State<CreateReelScreen> createState() => _CreateReelScreenState();
}

class _CreateReelScreenState extends State<CreateReelScreen> {
  static const int _maxBytes = 100 * 1024 * 1024;

  final _captionController = TextEditingController();
  final _picker = ImagePicker();

  CommunityDoc? _community;
  XFile? _video;
  int? _videoBytes;
  bool _picking = false;
  bool _busy = false;
  String _busyMsg = '';

  late final StreamCache<List<CommunityDoc>> _joined = StreamCache(
    () =>
        widget.joinedCommunities ??
        CommunityService.instance.watchJoined(),
  );

  @override
  void initState() {
    super.initState();
    _community = widget.initialCommunity;
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickVideo() async {
    if (_picking || _busy) return;
    setState(() => _picking = true);
    try {
      final file = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );
      if (file == null || !mounted) return;
      final length = await file.length();
      if (length > _maxBytes) {
        _snack('That video is over 100 MB. Pick a shorter clip.');
        return;
      }
      setState(() {
        _video = file;
        _videoBytes = length;
      });
    } catch (error) {
      debugPrint('CreateReelScreen: video pick failed: $error');
      _snack('Could not open your videos. Try picking the file again.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _clearVideo() {
    setState(() {
      _video = null;
      _videoBytes = null;
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_video == null) {
      _snack('Pick a video first.');
      return;
    }
    final community = _community;
    if (community == null) {
      _snack('Choose a community for this reel.');
      return;
    }
    if (AuthService.instance.currentUser == null) {
      _snack('Sign in to post reels.');
      return;
    }

    setState(() {
      _busy = true;
      _busyMsg = 'Preparing video…';
    });
    try {
      final bytes = await _video!.readAsBytes();
      if (!mounted) return;
      setState(() => _busyMsg = 'Uploading to Cloudinary…');
      final upload = await ReelService.instance.uploadVideo(
        bytes,
        filename: _video!.name,
      );
      if (!mounted) return;
      setState(() => _busyMsg = 'Posting reel…');
      await ReelService.instance.create(
        videoUrl: upload.videoUrl,
        thumbnailUrl: upload.thumbnailUrl,
        caption: _captionController.text,
        communityId: community.id,
        communityName: community.name,
        authorName: AuthService.instance.greetingName,
        authorAvatarUrl: AuthService.instance.currentUser?.photoURL,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      _snack(ReelService.friendlyMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMsg = '';
        });
      }
    }
  }

  String _sizeLabel(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const LiquidGlassPill(
                    radius: 999,
                    blur: 12,
                    padding: EdgeInsets.all(9),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'New reel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Share a short video with your community. It plays on the '
              'Reels feed for everyone.',
              style: TextStyle(color: Colors.white54, fontSize: 13.5, height: 1.45),
            ),
            const SizedBox(height: 18),
            _videoCard(),
            const SizedBox(height: 16),
            _captionCard(),
            const SizedBox(height: 16),
            _communityCard(),
            if (_busy) ...[
              const SizedBox(height: 18),
              LiquidGlass(
                radius: 16,
                blur: 18,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _busyMsg,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: const LinearProgressIndicator(
                        minHeight: 5,
                        color: AppColors.accent,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            GlassButton(
              label: 'Post reel',
              onPressed: _busy ? null : _submit,
              icon: Icons.videocam_rounded,
              height: 52,
            ),
          ],
        ),
      ),
    );
  }

  Widget _videoCard() {
    final video = _video;
    return LiquidGlass(
      radius: 22,
      blur: 24,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.04),
        ],
      ),
      borderColor: Colors.white.withValues(alpha: 0.18),
      padding: const EdgeInsets.all(14),
      child: video == null
          ? GestureDetector(
              onTap: _pickVideo,
              child: Container(
                height: 168,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: _picking
                    ? const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppColors.accent,
                        ),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_to_photos_rounded,
                            color: AppColors.accent,
                            size: 34,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Pick a video',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'MP4 · MOV — up to 100 MB, 60 seconds',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
              ),
            )
          : Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5C4D), Color(0xFF7F1D1D)],
                    ),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.name.isEmpty ? 'Video' : video.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _videoBytes == null
                            ? 'Ready to upload'
                            : '${_sizeLabel(_videoBytes!)} · ready to upload',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _clearVideo,
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 22,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _captionCard() {
    return LiquidGlass(
      radius: 22,
      blur: 24,
      gradient: LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.09),
          Colors.white.withValues(alpha: 0.04),
        ],
      ),
      borderColor: Colors.white.withValues(alpha: 0.16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TextField(
        controller: _captionController,
        maxLength: 200,
        maxLines: 3,
        minLines: 1,
        style: const TextStyle(color: Colors.white, fontSize: 14.5),
        decoration: const InputDecoration(
          counterStyle: TextStyle(color: Colors.white38, fontSize: 11),
          hintText: 'Say what’s happening…',
          hintStyle: TextStyle(color: Colors.white38),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  Widget _communityCard() {
    final preset = widget.initialCommunity;
    if (preset != null) {
      return LiquidGlass(
        radius: 22,
        blur: 22,
        gradient: LinearGradient(
          colors: [
            preset.color.withValues(alpha: 0.30),
            preset.color.withValues(alpha: 0.10),
          ],
        ),
        borderColor: Colors.white.withValues(alpha: 0.18),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: preset.color.withValues(alpha: 0.45),
                border: Border.all(color: Colors.white24),
              ),
              child: Icon(preset.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Posting to',
                style: TextStyle(color: Colors.white54, fontSize: 12.5),
              ),
            ),
            Text(
              preset.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<List<CommunityDoc>>(
      stream: _joined(),
      builder: (context, snap) {
        final joined = snap.data ?? const <CommunityDoc>[];
        if (joined.isEmpty) {
          return LiquidGlass(
            radius: 22,
            blur: 22,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No community selected',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Reels live inside communities — join one first.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 12),
                GlassButton(
                  label: 'Browse communities',
                  variant: GlassButtonVariant.outline,
                  height: 44,
                  icon: Icons.diversity_3_rounded,
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.communities,
                  ),
                ),
              ],
            ),
          );
        }

        return LiquidGlass(
          radius: 22,
          blur: 22,
          gradient: LinearGradient(
            colors: [
              (_community ?? joined.first).color.withValues(alpha: 0.26),
              (_community ?? joined.first).color.withValues(alpha: 0.08),
            ],
          ),
          borderColor: Colors.white.withValues(alpha: 0.18),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<CommunityDoc>(
              value: _community,
              isExpanded: true,
              dropdownColor: AppColors.surface,
              iconEnabledColor: Colors.white,
              hint: const Text(
                'Choose a community',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              items: [
                for (final c in joined)
                  DropdownMenuItem<CommunityDoc>(
                    value: c,
                    child: Row(
                      children: [
                        Icon(c.icon, size: 18, color: c.color),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _community = value),
            ),
          ),
        );
      },
    );
  }
}
