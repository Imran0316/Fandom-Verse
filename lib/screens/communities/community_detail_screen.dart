import 'package:flutter/material.dart';

import '../../core/animations/app_transitions.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/community_docs.dart';
import '../../models/post_docs.dart';
import '../../services/auth_service.dart';
import '../../services/community_service.dart';
import '../../services/image_upload_service.dart';
import '../../services/post_service.dart';
import '../../services/stream_cache.dart';
import '../../widgets/expandable_text.dart';
import '../../widgets/liquid_glass.dart';
import 'post_card.dart';

class CommunityDetailScreen extends StatefulWidget {
  const CommunityDetailScreen({super.key, required this.communityId});

  final String communityId;

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  final _postController = TextEditingController();
  bool _posting = false;
  String? _postImageUrl;
  bool _uploadingImage = false;
  late final _community = StreamCache<CommunityDoc?>(
    () => CommunityService.instance.watch(widget.communityId),
  );
  late final _membership = StreamCache<CommunityMemberDoc?>(
    () => CommunityService.instance.watchMembership(widget.communityId),
  );
  late final _posts = StreamCache<List<PostDoc>>(
    () => PostService.instance.watchCommunityFeed(widget.communityId),
  );

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  Future<void> _toggleJoin(
    CommunityDoc community, {
    required bool isMember,
  }) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to join communities.')),
      );
      return;
    }
    try {
      if (isMember) {
        await CommunityService.instance.leave(community.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Left ${community.name}')),
          );
        }
      } else {
        await CommunityService.instance.join(
          communityId: community.id,
          displayName: AuthService.instance.greetingName,
          avatarUrl: AuthService.instance.currentUser?.photoURL,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Joined ${community.name}')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      final text = e.toString();
      final friendly = text.contains('permission')
          ? 'Not allowed — publish updated firestore.rules and try again.'
          : text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendly)),
      );
    }
  }

  Future<void> _deleteCommunity(CommunityDoc community) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A22),
        title: const Text(
          'Delete community?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFFF6B6B)),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await CommunityService.instance.deleteCommunity(community.id);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final text = e.toString();
      final friendly = text.contains('permission')
          ? 'Not allowed — publish updated firestore.rules and try again.'
          : text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendly)),
      );
    }
  }

  Future<void> _pickPostImage() async {
    if (_uploadingImage) return;
    setState(() => _uploadingImage = true);
    try {
      final url = await ImageUploadService.instance.pickAndUpload(
        name: 'community-post',
      );
      if (url != null && mounted) setState(() => _postImageUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ImageUploadService.friendlyMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _submitPost(CommunityDoc community) async {
    final body = _postController.text.trim();
    if (body.isEmpty && _postImageUrl == null) return;
    setState(() => _posting = true);
    try {
      await PostService.instance.createPost(
        body: body,
        communityId: community.id,
        communityName: community.name,
        authorName: AuthService.instance.greetingName,
        authorAvatarUrl: AuthService.instance.currentUser?.photoURL,
        imageUrl: _postImageUrl,
      );
      _postController.clear();
      _postImageUrl = null;
      if (mounted) FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Post failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: StreamBuilder<CommunityDoc?>(
            stream: _community(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  snap.data == null) {
                return const Center(child: CircularProgressIndicator());
              }
              final community = snap.data;
              if (community == null) return _notFound(context);

              return StreamBuilder<CommunityMemberDoc?>(
                stream: _membership(),
                builder: (context, memberSnap) {
                  final membership = memberSnap.data;
                  final isMember = membership != null;
                  final isOwner = membership?.role == CommunityRole.owner;

                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: <Widget>[
                      SliverToBoxAdapter(
                        child: _header(community, isMember, isOwner),
                      ),
                      _postsSliver(community, isMember),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 24 + MediaQuery.paddingOf(context).bottom,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _notFound(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(height: 12),
            const Text(
              'Community not found',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  /* -------------------------------- Header -------------------------------- */

  Widget _header(CommunityDoc community, bool isMember, bool isOwner) {
    final uid = AuthService.instance.currentUser?.uid;
    final canDelete = uid != null &&
        community.ownerUid.isNotEmpty &&
        community.ownerUid == uid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _cover(community),
            Positioned(
              top: MediaQuery.of(context).padding.top + 6,
              left: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const LiquidGlassPill(
                  radius: 999,
                  blur: 16,
                  padding: EdgeInsets.all(9),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
            Positioned(left: 16, bottom: -42, child: _avatar(community)),
          ],
        ),
        const SizedBox(height: 54),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      community.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (isOwner) ...[
                    const SizedBox(width: 8),
                    const _OwnerBadge(),
                    const SizedBox(width: 6),
                    _EditButton(community: community),
                  ],
                  if (canDelete) ...[
                    const SizedBox(width: 6),
                    _DeleteButton(
                      onTap: () => _deleteCommunity(community),
                    ),
                  ],
                ],
              ),
              if (community.description.isNotEmpty) ...[
                const SizedBox(height: 7),
                ExpandableText(
                  text: community.description,
                  maxLines: 2,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 13),
              Row(
                children: [
                  Icon(
                    Icons.people_alt_rounded,
                    size: 15,
                    color: community.color,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${community.memberCount} '
                    'follower${community.memberCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.article_outlined,
                    size: 15,
                    color: community.color,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${community.postCount} '
                    'post${community.postCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (!isOwner) ...[
                const SizedBox(height: 15),
                _joinButton(community, isMember),
              ],
              const SizedBox(height: 16),
              if (isMember)
                _composer(community)
              else
                LiquidGlass(
                  radius: 16,
                  blur: 20,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.05),
                    ],
                  ),
                  borderColor: Colors.white.withValues(alpha: 0.2),
                  padding: const EdgeInsets.all(14),
                  child: const Text(
                    'Join this community to post, like and comment.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13.5),
                  ),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: community.color,
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
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cover(CommunityDoc community) {
    final coverUrl = community.coverImageUrl;
    return Container(
      height: 165,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            community.color.withValues(alpha: 0.6),
            community.color.withValues(alpha: 0.22),
            const Color(0xFF14141C),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Icon(
              community.icon,
              size: 76,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          if (coverUrl != null && coverUrl.isNotEmpty)
            Image.network(
              coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(CommunityDoc community) {
    final profileUrl = community.profileImageUrl;
    return Container(
      width: 86,
      height: 86,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            community.color,
            community.color.withValues(alpha: 0.55),
          ],
        ),
        border: Border.all(color: AppColors.backgroundDeep, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 14,
          ),
        ],
      ),
      child: profileUrl != null && profileUrl.isNotEmpty
          ? Image.network(
              profileUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Icon(community.icon, color: Colors.white, size: 34),
            )
          : Icon(community.icon, color: Colors.white, size: 34),
    );
  }

  Widget _joinButton(CommunityDoc community, bool isMember) {
    return GestureDetector(
      onTap: () => _toggleJoin(community, isMember: isMember),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: isMember
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x2EFFFFFF),
                    Color(0x12FFFFFF),
                  ],
                )
              : const LinearGradient(
                  colors: [Color(0xFFFF5C4D), Color(0xFFC1121F)],
                ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isMember ? Icons.check_rounded : Icons.add_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              isMember ? 'Joined' : 'Join community',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ------------------------------- Composer ------------------------------ */

  Widget _composer(CommunityDoc community) {
    return LiquidGlass(
      radius: 20,
      blur: 26,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.13),
          Colors.white.withValues(alpha: 0.05),
        ],
      ),
      borderColor: Colors.white.withValues(alpha: 0.22),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 30,
          offset: const Offset(0, 14),
        ),
      ],
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Column(
        children: [
          if (_postImageUrl != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: Image.network(
                        _postImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: Colors.white.withValues(alpha: 0.08),
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white38,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Image attached',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _postImageUrl = null),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _postController,
                  minLines: 1,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white, fontSize: 14.5),
                  decoration: InputDecoration(
                    hintText: 'Share with ${community.name}…',
                    hintStyle: const TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _uploadingImage ? null : _pickPostImage,
                child: LiquidGlassPill(
                  radius: 999,
                  blur: 14,
                  padding: const EdgeInsets.all(9),
                  child: _uploadingImage
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        )
                      : const Icon(
                          Icons.image_outlined,
                          size: 19,
                          color: Colors.white,
                        ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.createReel,
                  arguments: community,
                ),
                child: const LiquidGlassPill(
                  radius: 999,
                  blur: 14,
                  padding: EdgeInsets.all(9),
                  child: Icon(
                    Icons.video_call_outlined,
                    size: 19,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _posting ? null : () => _submitPost(community),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5C4D), Color(0xFFC1121F)],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.45),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: _posting
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /* --------------------------------- Feed --------------------------------- */

  Widget _postsSliver(CommunityDoc community, bool isMember) {
    return StreamBuilder<List<PostDoc>>(
      stream: _posts(),
      builder: (context, postSnap) {
        if (postSnap.connectionState == ConnectionState.waiting &&
            postSnap.data == null) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final posts = postSnap.data ?? const <PostDoc>[];
        if (posts.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _emptyFeed(isMember),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final p = posts[i];
              return Padding(
                key: ValueKey(p.id),
                padding: EdgeInsets.fromLTRB(16, i == 0 ? 4 : 0, 16, 12),
                child: FadeSlideIn(
                  delay: Duration(milliseconds: 35 * i.clamp(0, 8)),
                  child: PostCard(post: p, onChanged: () {}),
                ),
              );
            },
            childCount: posts.length,
          ),
        );
      },
    );
  }

  Widget _emptyFeed(bool isMember) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LiquidGlass(
              radius: 24,
              blur: 20,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.22),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: const Icon(
                Icons.forum_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No posts yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isMember
                  ? 'Start the conversation — drop the first post.'
                  : 'Join to post, like and comment.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerBadge extends StatelessWidget {
  const _OwnerBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.amber.withValues(alpha: 0.2),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
      ),
      child: const Text(
        'Owner',
        style: TextStyle(
          color: Colors.amber,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.community});

  final CommunityDoc community;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.editCommunity,
        arguments: community,
      ),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: const Icon(
          Icons.edit_rounded,
          size: 16,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.14),
          border: Border.all(
            color: const Color(0xFFFF6B6B).withValues(alpha: 0.5),
          ),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          size: 16,
          color: Color(0xFFFF6B6B),
        ),
      ),
    );
  }
}
