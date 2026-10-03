import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/auth_popup.dart';

/// Explore-mode auth gate.
///
/// The app opens straight into the dashboard signed-out; anything that
/// writes (like, comment, follow, cart, post…) must route through
/// [requireSignIn], which shows the auth popup and reports `false` so the
/// caller skips the action.
bool requireSignIn(BuildContext context, {String? reason}) {
  if (AuthService.instance.currentUser != null) return true;

  showAuthPopup(context, message: reason);
  return false;
}
