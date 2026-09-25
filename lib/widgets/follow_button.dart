import 'package:flutter/material.dart';

import '../services/user_service.dart';

/// Relationship of the signed-in viewer to [FollowButton.targetUid].
enum FollowRelation { loading, none, requested, incoming, following }

/// Instagram-style follow control with the four request-flow states:
/// Follow → Requested (tap to cancel), Accept/Decline for inbound
/// requests, and Following (tap to unfollow). Relationship checks are
/// one-shot reads; each action optimistically flips the state and
/// re-syncs from Firestore on failure.
class FollowButton extends StatefulWidget {
  const FollowButton({super.key, required this.targetUid});

  final String targetUid;

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  FollowRelation _relation = FollowRelation.loading;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final target = widget.targetUid;
    if (await UserService.instance.isFollowing(target)) {
      _set(FollowRelation.following);
      return;
    }
    if (await UserService.instance.hasPendingRequestTo(target)) {
      _set(FollowRelation.requested);
      return;
    }
    if (await UserService.instance.hasIncomingRequestFrom(target)) {
      _set(FollowRelation.incoming);
      return;
    }
    _set(FollowRelation.none);
  }

  void _set(FollowRelation relation) {
    if (!mounted) return;
    setState(() => _relation = relation);
  }

  Future<void> _run(
    FollowRelation optimistic,
    Future<void> Function() action,
  ) async {
    if (_busy) return;
    final previous = _relation;
    setState(() {
      _busy = true;
      _relation = optimistic;
    });
    try {
      await action();
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _relation = previous;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$e'.contains('permission')
                  ? 'Not allowed — publish updated firestore.rules and try again.'
                  : '$e',
            ),
          ),
        );
      }
      await _load();
    }
  }

  Future<void> _accept() => _run(
        FollowRelation.following,
        () => UserService.instance.acceptFollowRequest(widget.targetUid),
      );

  Future<void> _decline() => _run(
        FollowRelation.none,
        () => UserService.instance.declineFollowRequest(widget.targetUid),
      );

  @override
  Widget build(BuildContext context) {
    switch (_relation) {
      case FollowRelation.loading:
        return const SizedBox(
          height: 46,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white54,
              ),
            ),
          ),
        );
      case FollowRelation.incoming:
        return Row(
          children: [
            Expanded(child: _gradientButton(label: 'Accept', onTap: _runBusyGuard(_accept))),
            const SizedBox(width: 8),
            _ghostButton(
              icon: Icons.close_rounded,
              onTap: _runBusyGuard(_decline),
            ),
          ],
        );
      case FollowRelation.following:
        return _outlineButton(
          label: 'Following',
          icon: Icons.check_rounded,
          onTap: _runBusyGuard(
            () => _run(FollowRelation.none,
                () => UserService.instance.unfollow(widget.targetUid)),
          ),
        );
      case FollowRelation.requested:
        return _outlineButton(
          label: 'Requested',
          onTap: _runBusyGuard(
            () => _run(FollowRelation.none,
                () => UserService.instance.cancelFollowRequest(widget.targetUid)),
          ),
        );
      case FollowRelation.none:
        return _gradientButton(
          label: 'Follow',
          onTap: _runBusyGuard(
            () => _run(FollowRelation.requested,
                () => UserService.instance.sendFollowRequest(widget.targetUid)),
          ),
        );
    }
  }

  VoidCallback _runBusyGuard(Future<void> Function() action) {
    if (_busy) return () {};
    return () => action();
  }

  Widget _gradientButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF5C4D), Color(0xFFC1121F)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14.5,
          ),
        ),
      ),
    );
  }

  Widget _outlineButton({
    required String label,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
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

  Widget _ghostButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        width: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, size: 20, color: Colors.white70),
      ),
    );
  }
}
