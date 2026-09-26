import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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

  /// Apple sign-in.
  ///
  /// Web uses Firebase's popup (provider config lives in the Firebase
  /// console); iOS/macOS use the native sheet with a hashed nonce.
  /// The Apple provider must be enabled in Firebase authentication settings.
  Future<UserCredential> signInWithApple() async {
    if (!firebaseReady) _notConfigured();

    if (kIsWeb) {
      final result = await FirebaseAuth.instance.signInWithPopup(
        OAuthProvider('apple.com'),
      );
      if (result.user != null) {
        await UserService.instance.ensureProfile(result.user!);
      }
      return result;
    }

    final rawNonce = _generateNonce();
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: _sha256ofString(rawNonce),
    );
    final credential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
      rawNonce: rawNonce,
    );
    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    await UserService.instance.ensureProfile(result.user!);
    return result;
  }

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  static String _sha256ofString(String input) =>
      sha256.convert(utf8.encode(input)).toString();

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
