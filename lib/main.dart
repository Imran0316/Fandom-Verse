import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebase =
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
          .then((_) {
            AuthService.firebaseReady = true;
            return NotificationService.instance.initialize();
          })
          .catchError((_) {
            AuthService.firebaseReady = false;
          });

  runApp(const FandomVerseApp());
  await firebase;
}
