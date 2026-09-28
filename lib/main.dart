import 'package:cloud_firestore/cloud_firestore.dart';
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
            // Local offline storage (requirement): Firestore keeps an
            // on-disk cache of every document it has seen, so feed reads
            // keep working with zero connectivity, and writes made offline
            // queue in the same cache and auto-sync when the connection
            // returns. Must be set before any other Firestore call.
            // On web this uses the IndexedDB persistent cache.
            FirebaseFirestore.instance.settings = const Settings(
              persistenceEnabled: true,
              cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
            );
            return NotificationService.instance.initialize();
          })
          .catchError((_) {
            AuthService.firebaseReady = false;
          });

  runApp(const FandomVerseApp());
  await firebase;
}
