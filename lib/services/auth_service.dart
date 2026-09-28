import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'user_service.dart';

class AuthService with WidgetsBindingObserver {
  AuthService._();

  static final AuthService instance = AuthService._();

  /// Set to true in main() once Firebase.initializeApp() succeeds.
  static bool firebaseReady = false;

  bool get isReady => firebaseReady;

  bool get isSignedIn {
    if (!firebaseReady) return false;
    return FirebaseAuth.instance.currentUser != null;
  }

  User? get currentUser {
    if (!firebaseReady) return null;
    return FirebaseAuth.instance.currentUser;
  }

  String get greetingName {
    final user = currentUser;
    if (user == null) return 'Fan';
    final name = user.displayName;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    if (user.email != null && user.email!.contains('@')) {
      return user.email!.split('@').first;
    }
    return 'Fan';
  }

  // ---- Session keep-alive ----

  Timer? _tokenRefreshTimer;
  StreamSubscription<User?>? _idTokenSubscription;
  bool _sessionMonitorStarted = false;

  /// Start monitoring the auth session to keep it alive.
  ///
  /// Listens to token changes and periodically refreshes the ID token to
  /// prevent session expiration. The session persists until the user
  /// manually signs out.
  void startSessionMonitor() {
    if (_sessionMonitorStarted) return;
    if (!firebaseReady) return;
    _sessionMonitorStarted = true;

    // Listen to idTokenChanges to detect token refreshes and sign-outs
    _idTokenSubscription = FirebaseAuth.instance.idTokenChanges().listen(
      (user) {
        if (user != null) {
          debugPrint('AuthService: ID token changed for ${user.uid}');
        } else {
          debugPrint('AuthService: User signed out');
          _stopTokenRefresh();
        }
      },
      onError: (error) {
        debugPrint('AuthService: idTokenChanges error: $error');
      },
    );

    // Start periodic token refresh (Firebase tokens expire after 1 hour)
    _startTokenRefresh();

    // Listen to app lifecycle to refresh token on resume
    WidgetsBinding.instance.addObserver(this);
  }

  /// Stop monitoring the auth session.
  void stopSessionMonitor() {
    _sessionMonitorStarted = false;
    _idTokenSubscription?.cancel();
    _idTokenSubscription = null;
    _stopTokenRefresh();
    WidgetsBinding.instance.removeObserver(this);
  }

  void _startTokenRefresh() {
    _stopTokenRefresh();
    // Refresh every 50 minutes (tokens expire after 1 hour)
    _tokenRefreshTimer = Timer.periodic(
      const Duration(minutes: 50),
      (_) => _refreshToken(),
    );
  }

  void _stopTokenRefresh() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
  }

  /// Force-refresh the ID token to keep the session alive.
  Future<void> _refreshToken() async {
    if (!firebaseReady) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await user.getIdToken(true);
      debugPrint('AuthService: Token refreshed successfully');
    } catch (e) {
      debugPrint('AuthService: Token refresh failed: $e');
    }
  }

  /// Manually refresh the ID token. Useful before making API calls that
  /// require a fresh token.
  Future<void> refreshToken() => _refreshToken();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh token when app comes back to foreground
      _refreshToken();
    }
  }

  Never _notConfigured() {
    throw FirebaseAuthException(
      code: 'firebase-not-configured',
      message:
          'Firebase is not connected yet. Run `flutterfire configure` first.',
    );
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!firebaseReady) _notConfigured();
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await UserService.instance.ensureProfile(credential.user!);
    return credential;
  }

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (!firebaseReady) _notConfigured();
    final credential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (displayName != null && displayName.trim().isNotEmpty) {
      await credential.user?.updateDisplayName(displayName.trim());
    }
    await UserService.instance.ensureProfile(credential.user!);
    return credential;
  }

  Future<UserCredential> signInWithGoogle() async {
    if (!firebaseReady) _notConfigured();

    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;

    final scopes = <String>['email', 'profile'];
    final authorization = await account.authorizationClient
            .authorizationForScopes(scopes) ??
        await account.authorizationClient.authorizeScopes(scopes);

    final credential = GoogleAuthProvider.credential(
      accessToken: authorization.accessToken,
      idToken: idToken,
    );
    final result =
        await FirebaseAuth.instance.signInWithCredential(credential);
    await UserService.instance.ensureProfile(result.user!);
    return result;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    if (!firebaseReady) _notConfigured();
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    if (!firebaseReady) return;

    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance
            .signOut()
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    }

    try {
      await FirebaseAuth.instance
          .signOut()
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      debugPrint('AuthService: FirebaseAuth.signOut timed out');
    }
  }
}
