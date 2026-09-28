import 'package:flutter/material.dart';

import 'routes/app_routes.dart';
import '../services/auth_service.dart';

/// Explore-mode auth gate.
///
/// The app opens straight into the dashboard signed-out; anything that
/// writes (like, comment, follow, cart, post…) must route through
/// [requireSignIn], which bounces the user to the Get Started screen and
/// reports `false` so the caller skips the action.
bool requireSignIn(BuildContext context, {String? reason}) {
  if (AuthService.instance.currentUser != null) return true;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          reason ?? 'Sign in to do that.',
          style: const TextStyle(color: Colors.white),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  Navigator.of(context).pushNamed(AppRoutes.getStarted);
  return false;
}
