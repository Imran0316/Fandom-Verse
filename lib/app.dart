import 'package:flutter/material.dart';

import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/get_started/get_started_screen.dart';
import 'services/auth_service.dart';

class FandomVerseApp extends StatelessWidget {
  const FandomVerseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FandomVerse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: AuthService.instance.isSignedIn
          ? AppRoutes.dashboard
          : AppRoutes.getStarted,
      routes: {
        AppRoutes.getStarted: (_) => const GetStartedScreen(),
        AppRoutes.signIn: (_) =>
            const GetStartedScreen(openAuthInitially: true),
        AppRoutes.dashboard: (_) => const DashboardScreen(),
      },
    );
  }
}
