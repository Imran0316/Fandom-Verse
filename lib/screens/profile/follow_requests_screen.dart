import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/follow_docs.dart';
import '../../services/user_service.dart';

/// Inbox for pending inbound follow requests: accept writes both edge
/// mirrors + counters, decline just drops the request doc. The list is
/// live, so accepted/declined rows disappear on their own.
class FollowRequestsScreen extends StatefulWidget {
  const FollowRequestsScreen({super.key});

  @override
  State<FollowRequestsScreen> createState() => _FollowRequestsScreenState();
}

class _FollowRequestsScreenState extends State<FollowRequestsScreen> {
  final Set<String> _busyIds = {};

  Future<void> _accept(FollowDoc request) async {
    if (_busyIds.contains(request.uid)) return;
    setState(() => _busyIds.add(request.uid));
    try {
      await UserService.instance.acceptFollowRequest(request.uid);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(request.uid));
    }
  }

  Future<void> _decline(FollowDoc request) async {
    if (_busyIds.contains(request.uid)) return;
    setState(() => _busyIds.add(request.uid));
    try {
      await UserService.instance.declineFollowRequest(request.uid);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(request.uid));
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
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
                        'Follow requests',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<FollowDoc>>(
                    stream: UserService.instance.watchFollowRequests(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting &&
                          snap.data == null) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      final requests = snap.data ?? const <FollowDoc>[];
                      if (requests.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_add_alt_outlined,
                                color: Colors.white24,
                                size: 42,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No pending requests',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'When someone asks to follow you, they show up here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white30,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: requests.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final request = requests[i];
                          final busy = _busyIds.contains(request.uid);
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.white.withValues(alpha: 0.06),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Row(
                              children: [
                                _avatar(request),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        request.displayName.isEmpty
                                            ? 'Fan'
                                            : request.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (request.bio != null &&
                                          request.bio!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          request.bio!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                busy
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white54,
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          GestureDetector(
                                            onTap: () => _accept(request),
                                            child: Container(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 14,
                                                  vertical: 8),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                gradient:
                                                    const LinearGradient(
                                                  colors: [
                                                    Color(0xFFFF5C4D),
                                                    Color(0xFFC1121F),
                                                  ],
                                                ),
                                              ),
                                              child: const Text(
                                                'Accept',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () => _decline(request),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.all(7),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white
                                                    .withValues(alpha: 0.08),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.2),
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.close_rounded,
                                                size: 16,
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar(FollowDoc request) {
    final initial = request.displayName.isNotEmpty
        ? request.displayName.characters.first.toUpperCase()
        : '?';
    return Container(
      width: 44,
      height: 44,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1E3A5F)],
        ),
      ),
      child: request.avatarUrl?.isNotEmpty == true
          ? Image.network(
              request.avatarUrl!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
    );
  }
}
