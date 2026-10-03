import 'package:flutter/material.dart';

import '../../core/auth_gate.dart';
import '../../core/theme/app_colors.dart';
import '../../models/reel_docs.dart';
import '../../services/auth_service.dart';
import '../../services/reel_service.dart';
import '../../services/stream_cache.dart';
import '../../widgets/cached_image.dart';
import '../../widgets/liquid_glass.dart';

/// Modal comments list + composer for a reel.
Future<void> showReelCommentsSheet(BuildContext context, ReelDoc reel) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReelCommentsSheet(reel: reel),
  );
}

class _ReelCommentsSheet extends StatefulWidget {
  const _ReelCommentsSheet({required this.reel});

  final ReelDoc reel;

  @override
  State<_ReelCommentsSheet> createState() => _ReelCommentsSheetState();
}

class _ReelCommentsSheetState extends State<_ReelCommentsSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  late final _comments = StreamCache<List<ReelCommentDoc>>(
    () => ReelService.instance.watchComments(widget.reel.id),
  );

  /// Comments the user just removed — hidden locally until the stream
  /// catches up (same optimistic feel as the send flow).
  final Set<String> _removing = <String>{};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A22),
        title: const Text(
          'Delete comment?',
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
    return ok == true;
  }

  Future<void> _delete(ReelCommentDoc comment) async {
    if (!await _confirmDelete() || !mounted) return;
    setState(() => _removing.add(comment.id));
    try {
      await ReelService.instance.deleteComment(widget.reel.id, comment.id);
    } catch (error) {
      if (!mounted) return;
      setState(() => _removing.remove(comment.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ReelService.friendlyMessage(error))),
      );
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    // Explore mode: commenting requires an account.
    if (!requireSignIn(context, reason: 'Sign in to comment on reels.')) {
      return;
    }
    setState(() => _sending = true);
    try {
      await ReelService.instance.addComment(
        widget.reel.id,
        text,
        authorName: AuthService.instance.greetingName,
        authorAvatarUrl: AuthService.instance.currentUser?.photoURL,
      );
      _controller.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ReelService.friendlyMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final myUid = AuthService.instance.currentUser?.uid;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF12121A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: Colors.white24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.mode_comment_rounded,
                    color: AppColors.accent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Comments',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.reel.commentCount}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: StreamBuilder<List<ReelCommentDoc>>(
                stream: _comments(),
                builder: (context, snap) {
                  final comments = (snap.data ?? const <ReelCommentDoc>[])
                      .where((c) => !_removing.contains(c.id))
                      .toList();
                  if (comments.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 34),
                      child: Text(
                        'No comments yet — start the conversation.',
                        style: TextStyle(color: Colors.white54, fontSize: 13.5),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    itemCount: comments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, i) {
                      final c = comments[i];
                      final isOwn = myUid != null && c.authorUid == myUid;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _avatar(c.authorAvatarUrl, c.authorName),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.authorName.isEmpty ? 'Fan' : c.authorName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  c.body,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13.5,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isOwn)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _delete(c),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: LiquidGlass(
                  radius: 999,
                  blur: 16,
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.05),
                    ],
                  ),
                  borderColor: Colors.white.withValues(alpha: 0.22),
                  padding: const EdgeInsets.only(left: 16, right: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 3,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Add a comment…',
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _send,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF5C4D), Color(0xFFC1121F)],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                          child: _sending
                              ? const Padding(
                                  padding: EdgeInsets.all(9),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String? url, String name) {
    return Container(
      width: 32,
      height: 32,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: url != null && url.isNotEmpty
          ? CachedImage(url: url, fit: BoxFit.cover)
          : _initial(name),
    );
  }

  Widget _initial(String name) {
    final letter = name.isEmpty
        ? '?'
        : name.characters.first.toUpperCase();
    return Center(
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
