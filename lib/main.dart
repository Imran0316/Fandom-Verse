import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AuthService.firebaseReady = true;
  } catch (_) {
    // Placeholder options or missing config — app runs in UI-only mode
    // until `flutterfire configure` generates real firebase_options.dart.
    AuthService.firebaseReady = false;
  }

  runApp(const FandomVerseApp());
}
