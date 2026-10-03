import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/auth_popup.dart';
import 'auth_service.dart';

/// Tracks how long a signed-out user has been exploring and shows the auth
/// prompt after a configurable delay (default 5 minutes).
///
/// Real apps (Instagram, TikTok, etc.) use this pattern: let users browse
/// freely, then gently nudge them to sign in after they've had a chance to
/// experience the app.
class ExplorePromptService {
  ExplorePromptService._();

  static final ExplorePromptService instance = ExplorePromptService._();

  /// How long a signed-out user can explore before the auth prompt appears.
  static const Duration exploreDelay = Duration(minutes: 5);

  /// Cooldown after the user dismisses the prompt — don't show again for
  /// this long.
  static const Duration cooldown = Duration(minutes: 5);

  Timer? _exploreTimer;
  DateTime? _lastDismissed;
  bool _promptVisible = false;

  /// True if the user is currently signed out and exploring.
  bool get isExploring =>
      AuthService.instance.isReady &&
      AuthService.instance.currentUser == null;

  /// Start the explore timer. Called when the user lands on the dashboard
  /// signed-out. If the user signs in, call [stop].
  void start() {
    if (!isExploring) return;
    if (_exploreTimer?.isActive ?? false) return;

    // If the prompt was recently dismissed, start the cooldown instead.
    if (_lastDismissed != null) {
      final elapsed = DateTime.now().difference(_lastDismissed!);
      if (elapsed < cooldown) {
        final remaining = cooldown - elapsed;
        _exploreTimer = Timer(remaining, _showPrompt);
        return;
      }
    }

    _exploreTimer = Timer(exploreDelay, _showPrompt);
  }

  /// Stop the explore timer. Called when the user signs in or the app is
  /// disposed.
  void stop() {
    _exploreTimer?.cancel();
    _exploreTimer = null;
  }

  /// Mark the prompt as dismissed by the user. Starts the cooldown so the
  /// prompt doesn't immediately reappear.
  void markDismissed() {
    _lastDismissed = DateTime.now();
    _promptVisible = false;
  }

  void _showPrompt() {
    if (!isExploring) return;
    if (_promptVisible) return;
    if (!AuthService.instance.isReady) return;

    // Use a post-frame callback to avoid calling showModalBottomSheet during
    // a build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isExploring) return;
      _promptVisible = true;
      showAuthPopup(_navigatorContext!).then((success) {
        _promptVisible = false;
        if (success == true) {
          // User signed in — stop exploring.
          stop();
        } else {
          // User dismissed — start cooldown.
          markDismissed();
          start();
        }
      });
    });
  }

  /// The navigator context used to show the popup. Set by the dashboard
  /// when it mounts.
  static BuildContext? _navigatorContext;

  /// Set the context used to show the auth popup. Called by the dashboard.
  static void setContext(BuildContext context) {
    _navigatorContext = context;
  }

  /// Clear the context. Called by the dashboard when it disposes.
  static void clearContext() {
    _navigatorContext = null;
  }
}
