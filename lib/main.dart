import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Don't block the first frame on Firebase — paint the shell immediately
  // and flip the flag when init finishes (or fails).
  final firebase = Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ).then((_) {
    AuthService.firebaseReady = true;
  }).catchError((_) {
    AuthService.firebaseReady = false;
  });

  runApp(const FandomVerseApp());
  await firebase;
}
