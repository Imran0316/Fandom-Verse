import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import 'user_service.dart';

class AuthService {
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

  /// Google sign-in, platform-aware:
  ///
  /// - Web: `signInWithPopup` — no google_sign_in plugin involved and no SHA-1
  ///   requirement; the browser handles the whole flow.
  /// - Android/iOS: `google_sign_in` — requires the app's SHA-1 fingerprint to
  ///   be registered in the Firebase console, otherwise this fails with
  ///   ApiException 10 (mapped to a clear message in the auth form).
  /// - Windows/macOS: `signInWithProvider` — flutterfire's desktop OAuth flow
  ///   (google_sign_in has no desktop implementation and would throw
  ///   MissingPluginException).
  ///
  /// If the email already has a password account, the Google credential is
  /// linked to it instead of failing with credential-already-in-use, so
  /// progress (favorites, orders, profile) survives the first Google login.
  Future<UserCredential> signInWithGoogle() async {
    if (!firebaseReady) _notConfigured();

    UserCredential result;
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      result = await FirebaseAuth.instance.signInWithPopup(provider);
    } else if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'google-no-id-token',
          message:
              'Google did not return an identity token. Verify the OAuth '
              'client (SHA-1 fingerprint) in the Firebase console.',
        );
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      result = await _signInOrLink(credential);
    } else {
      // Windows / macOS desktop OAuth via flutterfire.
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      result = await FirebaseAuth.instance.signInWithProvider(provider);
    }

    await UserService.instance.ensureProfile(result.user!);
    return result;
  }

  /// Tries [credential] directly. When Firebase reports the email already has
  /// an account with a different provider (typically password), surface a
  /// clear "sign in with password first" path instead of the raw error —
  /// after that password sign-in, the app links Google so future logins use
  /// either method.
  Future<UserCredential> _signInOrLink(AuthCredential credential) async {
    try {
      return await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'credential-already-in-use') {
        rethrow;
      }
      throw FirebaseAuthException(
        code: 'account-exists-with-password',
        message:
            'This email is registered with a password. Sign in with your '
            'password once — Google will be linked automatically.',
      );
    }
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
