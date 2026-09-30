import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase without blocking the UI.
  // The splash screen handles waiting for Firebase readiness.
  unawaited(
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .then((_) {
          // Settings must land before any query runs: the moment readiness
          // flips, dashboard tabs start their Firestore listeners, and the
          // SDK rejects settings changes once it has started.
          // Local offline storage: Firestore keeps an on-disk cache of every
          // document it has seen, so feed reads keep working with zero
          // connectivity, and writes made offline queue in the same cache and
          // auto-sync when the connection returns.
          FirebaseFirestore.instance.settings = const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
          );
          AuthService.firebaseReady = true;
          return NotificationService.instance.initialize();
        })
        .catchError((_) {
          AuthService.firebaseReady = false;
        }),
  );

  runApp(const FandomVerseApp());
}
