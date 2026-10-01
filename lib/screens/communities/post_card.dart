import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth_gate.dart';
import '../../core/theme/app_colors.dart';
import '../../models/post_docs.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/image_upload_service.dart';
import '../../services/post_service.dart';
import '../../services/stream_cache.dart';
import '../../services/user_service.dart';
import '../../widgets/cached_image.dart';
import '../../widgets/expandable_text.dart';
import '../../widgets/gif_picker.dart';
import '../../widgets/image_viewer.dart';
import '../../widgets/liquid_glass.dart';

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onChanged,
    this.showCommunityChip = true,
  });

  final PostDoc post;
  final VoidCallback? onChanged;
  final bool showCommunityChip;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _liked = false;
  bool _reposted = false;
  bool _showComments = false;
  Stream<List<PostCommentDoc>>? _commentsStream;
  final _commentController = TextEditingController();
  bool _sendingComment = false;
  String? _commentImageUrl;
  bool _uploadingCommentMedia = false;
  StreamSubscription<bool>? _likeSub;
  StreamSubscription<bool>? _repostSub;

  @override
  void initState() {
    super.initState();
    final pid = widget.post.id;
    _likeSub = PostService.instance.watchLiked(pid).listen((v) {
      if (mounted && _liked != v) setState(() => _liked = v);
    });
    _repostSub = PostService.instance.watchReposted(pid).listen((v) {
      if (mounted && _reposted != v) setState(() => _reposted = v);
    });
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _showComments = false;
      _commentsStream = null;
    }
  }

  /// Opens/closes the comment thread with a stream cached for the lifetime of
  /// the open state, so local rebuilds (like/repost taps, parent route
  /// animations) never resubscribe — and closing frees the subscription.
  void _toggleComments() {
    setState(() {
      _showComments = !_showComments;
      _commentsStream = _showComments
          ? PostService.instance.watchComments(widget.post.id)
          : null;
    });
  }

  @override
  void dispose() {
    _likeSub?.cancel();
    _repostSub?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty && _commentImageUrl == null) return;
    // Explore mode: commenting requires an account.
    if (!requireSignIn(context, reason: 'Sign in to join the conversation.')) {
      return;
    }
    setState(() => _sendingComment = true);
    try {
      await PostService.instance.addComment(
        widget.post.id,
        text,
        imageUrl: _commentImageUrl,
        authorName: AuthService.instance.greetingName,
        authorAvatarUrl: AuthService.instance.currentUser?.photoURL,
      );
      _commentController.clear();
      _commentImageUrl = null;
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Comment failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  Future<void> _pickCommentImage() async {
    if (_uploadingCommentMedia) return;
    setState(() => _uploadingCommentMedia = true);
    try {
      final url = await ImageUploadService.instance.pickAndUpload(
        name: 'comment',
      );
      if (url != null && mounted) setState(() => _commentImageUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ImageUploadService.friendlyMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingCommentMedia = false);
    }
  }

  Future<void> _pickCommentGif() async {
    if (_uploadingCommentMedia) return;
    setState(() => _uploadingCommentMedia = true);
    try {
      final url = await GifPicker.show(context);
      if (url != null && mounted) setState(() => _commentImageUrl = url);
    } finally {
      if (mounted) setState(() => _uploadingCommentMedia = false);
    }
  }

  void _share() {
    final post = widget.post;
    final text = post.body.trim().isNotEmpty
        ? post.body.trim()
        : (post.imageUrl ?? '');
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post copied to clipboard')),
      );
    }
  }

  /// Edit dialog for own posts: same multiline field and empty-body rule as
  /// the composers (an image-only post may keep an empty body).
  Future<void> _editPost() async {
    final post = widget.post;
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _EditPostDialog(
        initialBody: post.body,
        hasImage: post.imageUrl?.isNotEmpty == true,
      ),
    );
    if (text == null || !mounted) return;
    try {
      await PostService.instance.updatePost(post.id, text);
      widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isSelf =
        post.authorUid == AuthService.instance.currentUser?.uid;
    final isAdminSelf = isSelf; // delete own post; admin delete via panel

    return LiquidGlass(
      radius: 18,
      blur: 0,
      gradient: LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0.04),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (post.authorUid.isEmpty) return;
                  Navigator.pushNamed(
                    context,
                    '/user-profile',
                    arguments: post.authorUid,
                  );
                },
                child: Hero(
                  tag: 'avatar-${post.authorUid}-${post.id}',
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFC1121F), Color(0xFF7F1D1D)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: post.authorAvatarUrl?.isNotEmpty == true
                        ? CachedImage(url: post.authorAvatarUrl)
                        : _AuthorAvatarImage(
                            uid: post.authorUid,
                            name: post.authorName,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName.isEmpty ? 'Fan' : post.authorName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _timeLabel(post.createdAt),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.showCommunityChip &&
                  post.communityName != null &&
                  post.communityName!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: AppColors.primary.withValues(alpha: 0.25),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    post.communityName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (isAdminSelf)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                  color: const Color(0xFF1A1A22),
                  onSelected: (v) async {
                    if (v == 'edit') {
                      await _editPost();
                    }
                    if (v == 'delete') {
                      if (!context.mounted) return;
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF1A1A22),
                          title: const Text(
                            'Delete post?',
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
                      if (ok == true) {
                        await PostService.instance.deletePost(post.id);
                        widget.onChanged?.call();
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(
                        'Edit post',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Color(0xFFFF6B6B)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (post.body.isNotEmpty) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleComments,
              child: ExpandableText(
                text: post.body,
                maxLines: 2,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            GestureDetector(
              onTap: () => openImageViewer(context, post.imageUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: double.infinity,
                  height: 260,
                  child: CachedImage(url: post.imageUrl),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              _ActionChip(
                icon: _liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: '${post.likeCount}',
                active: _liked,
                activeColor: AppColors.primary,
                onTap: () async {
                  // Explore mode: likes belong to an account.
                  if (!requireSignIn(
                    context,
                    reason: 'Sign in to like posts.',
                  )) {
                    return;
                  }
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await PostService.instance.toggleLike(post.id);
                    widget.onChanged?.call();
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
              _ActionChip(
                icon: Icons.mode_comment_outlined,
                label: '${post.commentCount}',
                onTap: _toggleComments,
              ),
              const SizedBox(width: 8),
              _ActionChip(
                icon: Icons.repeat_rounded,
                label: '${post.repostCount}',
                active: _reposted,
                activeColor: const Color(0xFF10B981),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await PostService.instance.toggleRepost(post.id);
                    widget.onChanged?.call();
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
              _ActionChip(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: _share,
              ),
            ],
          ),
          if (_showComments) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 10),
            StreamBuilder<List<PostCommentDoc>>(
              stream: _commentsStream,
              builder: (context, snap) {
                final comments = snap.data ?? const <PostCommentDoc>[];
                if (comments.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'No comments yet',
                      style: TextStyle(color: Colors.white38, fontSize: 12.5),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final c in comments)
                      _CommentTile(
                        key: ValueKey(c.id),
                        postId: widget.post.id,
                        comment: c,
                        onChanged: widget.onChanged,
                      ),
                  ],
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                children: [
                  if (_commentImageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: CachedImage(
                                url: _commentImageUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Attachment ready',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _commentImageUrl = null),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Add a comment…',
                            hintStyle: const TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.14),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.14),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: AppColors.accent),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          onSubmitted: (_) => _sendComment(),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap:
                            _uploadingCommentMedia ? null : _pickCommentGif,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.14),
                            border: Border.all(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Text(
                            'GIF',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _uploadingCommentMedia
                            ? null
                            : _pickCommentImage,
                        child: LiquidGlassPill(
                          radius: 999,
                          blur: 12,
                          padding: const EdgeInsets.all(8),
                          child: _uploadingCommentMedia
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.accent,
                                  ),
                                )
                              : const Icon(
                                  Icons.image_outlined,
                                  size: 17,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _sendingComment ? null : _sendComment,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF5C4D), Color(0xFFC1121F)],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Center(
                            child: _sendingComment
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _timeLabel(DateTime? at) {
  if (at == null) return 'now';
  final diff = DateTime.now().difference(at);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${at.month}/${at.day}/${at.year}';
}

/// Body editor used by the post's overflow menu. Owns its controller so it
/// outlives the dialog's exit animation, and pops the edited text on save.
class _EditPostDialog extends StatefulWidget {
  const _EditPostDialog({
    required this.initialBody,
    required this.hasImage,
  });

  final String initialBody;
  final bool hasImage;

  @override
  State<_EditPostDialog> createState() => _EditPostDialogState();
}

class _EditPostDialogState extends State<_EditPostDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialBody);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A22),
      title: const Text(
        'Edit post',
        style: TextStyle(color: Colors.white),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 1,
        maxLines: 4,
        style: const TextStyle(color: Colors.white, fontSize: 14.5),
        decoration: const InputDecoration(
          hintText: "What's hype in your fandom?",
          hintStyle: TextStyle(color: Colors.white38),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isEmpty && !widget.hasImage) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Post cannot be empty.')),
              );
              return;
            }
            Navigator.pop(context, _controller.text);
          },
          child: const Text(
            'Save',
            style: TextStyle(color: AppColors.accent),
          ),
        ),
      ],
    );
  }
}

class _CommentTile extends StatefulWidget {
  const _CommentTile({
    super.key,
    required this.postId,
    required this.comment,
    this.onChanged,
  });

  final String postId;
  final PostCommentDoc comment;
  final VoidCallback? onChanged;

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  late bool _liked;
  late int _likeCount;
  String? _myReaction;
  bool _busy = false;
  bool _showReactionPicker = false;
  bool _showReplies = false;
  bool _showReplyComposer = false;
  Stream<List<PostCommentDoc>>? _repliesStream;
  final _replyController = TextEditingController();
  bool _sendingReply = false;

  @override
  void initState() {
    super.initState();
    _liked = false;
    _likeCount = widget.comment.likeCount;
    _loadMyState();
  }

  @override
  void didUpdateWidget(covariant _CommentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comment.id != widget.comment.id) {
      _showReplies = false;
      _showReplyComposer = false;
      _repliesStream = null;
      _loadMyState();
    }
    if (oldWidget.comment.likeCount != widget.comment.likeCount) {
      _likeCount = widget.comment.likeCount;
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  /// One-shot reads (no listeners): my like flag and my chosen reaction.
  Future<void> _loadMyState() async {
    final c = widget.comment;
    final liked =
        await PostService.instance.hasLikedComment(widget.postId, c.id);
    final reaction =
        await PostService.instance.getCommentReaction(widget.postId, c.id);
    if (!mounted || c.id != widget.comment.id) return;
    setState(() {
      _liked = liked;
      _myReaction = reaction;
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleLike() async {
    if (_busy) return;
    // Explore mode: comment likes belong to an account.
    if (!requireSignIn(context, reason: 'Sign in to like comments.')) return;
    final wasLiked = _liked;
    setState(() {
      _busy = true;
      _liked = !wasLiked;
      _likeCount += wasLiked ? -1 : 1;
    });
    try {
      await PostService.instance.toggleCommentLike(
        widget.postId,
        widget.comment.id,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _liked = wasLiked;
          _likeCount += wasLiked ? 1 : -1;
        });
      }
      _snack('Like failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _react(String emoji) async {
    if (_busy) return;
    // Explore mode: reactions belong to an account.
    if (!requireSignIn(context, reason: 'Sign in to react.')) return;
    final previous = _myReaction;
    final next = previous == emoji ? null : emoji;
    setState(() {
      _busy = true;
      _myReaction = next;
      _showReactionPicker = false;
    });
    try {
      await PostService.instance.reactToComment(
        widget.postId,
        widget.comment.id,
        next,
      );
    } catch (e) {
      if (mounted) setState(() => _myReaction = previous);
      _snack('Reaction failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleReplies() {
    setState(() {
      _showReplies = !_showReplies;
      _repliesStream = _showReplies
          ? PostService.instance.watchReplies(
              widget.postId,
              widget.comment.id,
            )
          : null;
      if (!_showReplies) _showReplyComposer = false;
    });
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    // Explore mode: replies require an account.
    if (!requireSignIn(context, reason: 'Sign in to reply.')) return;
    setState(() => _sendingReply = true);
    try {
      await PostService.instance.addReply(
        widget.postId,
        widget.comment.id,
        text,
        authorName: AuthService.instance.greetingName,
        authorAvatarUrl: AuthService.instance.currentUser?.photoURL,
      );
      _replyController.clear();
    } catch (e) {
      _snack('Reply failed: $e');
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  void _openProfile(String uid) {
    if (uid.isEmpty) return;
    Navigator.pushNamed(context, '/user-profile', arguments: uid);
  }

  Future<bool> _confirmDelete(String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A22),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
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
    return ok == true;
  }

  Future<void> _deleteComment() async {
    if (!await _confirmDelete('Delete comment?')) return;
    if (!mounted) return;
    try {
      await PostService.instance.deleteComment(
        widget.postId,
        widget.comment.id,
      );
      widget.onChanged?.call();
    } catch (e) {
      _snack('Delete failed: $e');
    }
  }

  Future<void> _deleteReply(PostCommentDoc reply) async {
    if (!await _confirmDelete('Delete reply?')) return;
    if (!mounted) return;
    try {
      await PostService.instance.deleteReply(
        widget.postId,
        widget.comment.id,
        reply.id,
      );
      widget.onChanged?.call();
    } catch (e) {
      _snack('Delete failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    final myUid = AuthService.instance.currentUser?.uid;
    final isOwn = myUid != null && c.authorUid == myUid;
    final initial =
        (c.authorName.isNotEmpty ? c.authorName.characters.first : '?')
            .toUpperCase();
    final reactions = c.reactions;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _openProfile(c.authorUid),
                child: Container(
                  width: 26,
                  height: 26,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: c.authorAvatarUrl?.isNotEmpty == true
                      ? CachedImage(
                          url: c.authorAvatarUrl,
                          fit: BoxFit.cover,
                        )
                      : Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _openProfile(c.authorUid),
                      child: Text(
                        c.authorName.isEmpty ? 'Fan' : c.authorName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (c.body.isNotEmpty)
                      ExpandableText(
                        text: c.body,
                        maxLines: 2,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    if (c.imageUrl != null && c.imageUrl!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => openImageViewer(context, c.imageUrl!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 190,
                            height: 140,
                            child: CachedImage(
                              url: c.imageUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _CommentAction(
                          icon: _liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          label: '$_likeCount',
                          active: _liked,
                          activeColor: AppColors.primary,
                          onTap: _toggleLike,
                        ),
                        const SizedBox(width: 14),
                        _CommentAction(
                          icon: Icons.reply_rounded,
                          label: 'Reply',
                          onTap: () => setState(
                            () => _showReplyComposer = !_showReplyComposer,
                          ),
                        ),
                        const SizedBox(width: 14),
                        _CommentAction(
                          icon: Icons.sentiment_satisfied_alt_rounded,
                          label: 'React',
                          active: _showReactionPicker,
                          onTap: () => setState(
                            () => _showReactionPicker = !_showReactionPicker,
                          ),
                        ),
                        if (c.replyCount > 0) ...[
                          const SizedBox(width: 14),
                          _CommentAction(
                            icon: Icons.mode_comment_outlined,
                            label: '${c.replyCount} '
                                '${c.replyCount == 1 ? 'reply' : 'replies'}',
                            active: _showReplies,
                            onTap: _toggleReplies,
                          ),
                        ],
                      ],
                    ),
                    if (reactions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final entry in reactions.entries)
                            if (entry.value > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: _myReaction == entry.key
                                      ? AppColors.primary
                                          .withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.07),
                                  border: Border.all(
                                    color: _myReaction == entry.key
                                        ? AppColors.primary
                                            .withValues(alpha: 0.6)
                                        : Colors.white
                                            .withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Text(
                                  '${entry.key} ${entry.value}',
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                              ),
                        ],
                      ),
                    ],
                    if (_showReactionPicker) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: Colors.black.withValues(alpha: 0.45),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final emoji
                                in PostService.reactionEmojis)
                              GestureDetector(
                                onTap: () => _react(emoji),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    emoji,
                                    style: TextStyle(
                                      fontSize: 17,
                                      decoration: _myReaction == emoji
                                          ? TextDecoration.underline
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            if (_myReaction != null)
                              GestureDetector(
                                onTap: () => _react(_myReaction!),
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 15,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (_showReplies) ...[
                      const SizedBox(height: 8),
                      StreamBuilder<List<PostCommentDoc>>(
                        stream: _repliesStream,
                        builder: (context, snap) {
                          final replies =
                              snap.data ?? const <PostCommentDoc>[];
                          if (replies.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Text(
                                'No replies yet',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11.5,
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: [
                              for (final r in replies)
                                Padding(
                                  key: ValueKey(r.id),
                                  padding: const EdgeInsets.only(
                                    left: 4,
                                    bottom: 7,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        onTap: () =>
                                            _openProfile(r.authorUid),
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          clipBehavior: Clip.antiAlias,
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: r.authorAvatarUrl
                                                      ?.isNotEmpty ==
                                                  true
                                              ? CachedImage(
                                                  url: r.authorAvatarUrl,
                                                  fit: BoxFit.cover,
                                                )
                                              : const Icon(
                                                  Icons.person_rounded,
                                                  size: 12,
                                                  color: Colors.white54,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: GestureDetector(
                                                    onTap: () => _openProfile(
                                                        r.authorUid),
                                                    child: Text(
                                                      r.authorName.isEmpty
                                                          ? 'Fan'
                                                          : r.authorName,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  _timeLabel(r.createdAt),
                                                  style: const TextStyle(
                                                    color: Colors.white38,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (r.body.isNotEmpty)
                                              Text(
                                                r.body,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                  height: 1.3,
                                                ),
                                              ),
                                            if (r.imageUrl != null &&
                                                r.imageUrl!.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              GestureDetector(
                                                onTap: () => openImageViewer(
                                                    context, r.imageUrl!),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: SizedBox(
                                                    width: 150,
                                                    height: 110,
                                                    child: CachedImage(
                                                      url: r.imageUrl,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (myUid != null && r.authorUid == myUid)
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => _deleteReply(r),
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              minWidth: 40,
                                              minHeight: 40,
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                left: 6,
                                                top: 2,
                                              ),
                                              child: Icon(
                                                Icons.delete_outline_rounded,
                                                size: 13,
                                                color: Colors.white
                                                    .withValues(alpha: 0.45),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                    if (_showReplyComposer) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _replyController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Write a reply…',
                                hintStyle: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12.5,
                                ),
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color:
                                        Colors.white.withValues(alpha: 0.14),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color:
                                        Colors.white.withValues(alpha: 0.14),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppColors.accent,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              onSubmitted: (_) => _sendReply(),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _sendingReply ? null : _sendReply,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF5C4D),
                                    Color(0xFFC1121F),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.28),
                                ),
                              ),
                              child: Center(
                                child: _sendingReply
                                    ? const SizedBox(
                                        width: 13,
                                        height: 13,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.arrow_upward_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    Text(
                      _timeLabel(c.createdAt),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (isOwn)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _deleteComment,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6, top: 4),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 15,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentAction extends StatelessWidget {
  const _CommentAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final color =
        active ? (activeColor ?? AppColors.primary) : Colors.white54;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final color = active ? (activeColor ?? AppColors.primary) : Colors.white60;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: active
              ? color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: active
                ? color.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Author avatar used when the post doc has no stored `authorAvatarUrl`
/// (posts created before the avatar field was wired up): resolves the
/// author's profile once through a cached stream and falls back to the
/// initial letter while loading or unavailable.
class _AuthorAvatarImage extends StatefulWidget {
  const _AuthorAvatarImage({required this.uid, required this.name});

  final String uid;
  final String name;

  @override
  State<_AuthorAvatarImage> createState() => _AuthorAvatarImageState();
}

class _AuthorAvatarImageState extends State<_AuthorAvatarImage> {
  StreamCache<UserProfile?>? _profile;

  Widget _initial() {
    final initial = widget.name.isNotEmpty
        ? widget.name.characters.first
        : '?';
    return Center(
      child: Text(
        initial.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uid.isEmpty || !AuthService.firebaseReady) return _initial();
    final cache = _profile ??= StreamCache<UserProfile?>(
      () => UserService.instance.watch(widget.uid),
    );
    return StreamBuilder<UserProfile?>(
      stream: cache(),
      builder: (context, snap) {
        final avatar = snap.data?.avatarUrl;
        if (avatar == null || avatar.isEmpty) return _initial();
        return CachedImage(
          url: avatar,
          fit: BoxFit.cover,
        );
      },
    );
  }
}
