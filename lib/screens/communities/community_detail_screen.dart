import 'package:flutter/material.dart';

import '../../core/animations/app_transitions.dart';
import '../../core/theme/app_colors.dart';
import '../../models/community_docs.dart';
import '../../models/post_docs.dart';
import '../../services/auth_service.dart';
import '../../services/community_service.dart';
import '../../services/post_service.dart';
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

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  Future<void> _toggleJoin(CommunityDoc? community) async {
    if (community == null) return;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    final profileName = AuthService.instance.greetingName;
    final avatar = AuthService.instance.currentUser?.photoURL;
    try {
      final memberSnap = await CommunityService.instance
          .watchMembership(community.id)
          .first;
      if (memberSnap != null) {
        await CommunityService.instance.leave(community.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Left ${community.name}')),
          );
        }
      } else {
        await CommunityService.instance.join(
          communityId: community.id,
          displayName: profileName,
          avatarUrl: avatar,
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

  Future<void> _submitPost(CommunityDoc community) async {
    final body = _postController.text.trim();
    if (body.isEmpty) return;
    setState(() => _posting = true);
    try {
      await PostService.instance.createPost(
        body: body,
        communityId: community.id,
        communityName: community.name,
        authorName: AuthService.instance.greetingName,
        authorAvatarUrl: AuthService.instance.currentUser?.photoURL,
      );
      _postController.clear();
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
            stream: CommunityService.instance.watch(widget.communityId),
            builder: (context, snap) {
              final community = snap.data;
              if (snap.connectionState == ConnectionState.waiting &&
                  community == null) {
                return const Scaffold(
                  backgroundColor: AppColors.backgroundDeep,
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (community == null) {
                return Scaffold(
                  backgroundColor: AppColors.backgroundDeep,
                  body: SafeArea(
                    child: Center(
                      child: Text(
                        'Community not found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                );
              }

              return StreamBuilder<CommunityMemberDoc?>(
                stream:
                    CommunityService.instance.watchMembership(community.id),
                builder: (context, memberSnap) {
                  final membership = memberSnap.data;
                  final isMember = membership != null;
                  final isOwner = membership?.role == CommunityRole.owner;

                  return SafeArea(
                    child: Column(
                      children: [
                        _header(community, isMember, isOwner),
                        Expanded(
                          child: StreamBuilder<List<PostDoc>>(
                            stream: PostService.instance
                                .watchCommunityFeed(community.id),
                            builder: (context, postSnap) {
                              if (postSnap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final posts = postSnap.data ?? const <PostDoc>[];
                              if (posts.isEmpty) {
                                return _emptyFeed(isMember);
                              }
                              return ListView.separated(
                                physics: const BouncingScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 20),
                                itemCount: posts.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, i) {
                                  final p = posts[i];
                                  return FadeSlideIn(
                                    delay:
                                        Duration(milliseconds: 35 * (i.clamp(0, 8))),
                                    child: PostCard(
                                      post: p,
                                      onChanged: () {},
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        if (isMember)
                          _composer(community)
                        else
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                            child: LiquidGlass(
                              radius: 16,
                              blur: 18,
                              padding: const EdgeInsets.all(14),
                              child: const Text(
                                'Join this community to post and comment.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13.5,
                                ),
                              ),
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

  Widget _header(CommunityDoc community, bool isMember, bool isOwner) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            community.color.withValues(alpha: 0.28),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 6),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  community.color,
                  community.color.withValues(alpha: 0.55),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Icon(community.icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
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
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${community.memberCount} members',
                  style: TextStyle(
                    color: community.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (!isOwner)
            GestureDetector(
              onTap: () => _toggleJoin(community),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: isMember
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFFC1121F), Color(0xFF7F1D1D)],
                        ),
                  color: isMember ? Colors.white.withValues(alpha: 0.12) : null,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  isMember ? 'Joined' : 'Join',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: _OwnerBadge(),
            ),
        ],
      ),
    );
  }

  Widget _composer(CommunityDoc community) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: LiquidGlass(
        radius: 18,
        blur: 22,
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
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
            const SizedBox(width: 8),
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
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
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
              child: const Icon(Icons.forum_rounded,
                  color: Colors.white, size: 32),
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
