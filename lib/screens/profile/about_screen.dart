import 'package:flutter/material.dart';

import '../../core/animations/app_transitions.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/lottie_view.dart';
import '../../widgets/liquid_glass.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.08),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const Text(
                        'About Us',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    Center(
                      child: LottieView(
                        width: 96,
                        height: 96,
                        asset: 'lib/assets/lottie/sparkle.json',
                        fallback: const PulseDot(size: 80),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        'FandomVerse',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text(
                        'v1.0.0',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FadeSlideIn(
                      child: _Section(
                        title: 'Our mission',
                        body:
                            'One place for every fandom — discover communities, '
                            'share moments, shop merch, and never miss a con.',
                      ),
                    ),
                    const SizedBox(height: 14),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 80),
                      child: _Section(
                        title: 'What you can do',
                        body:
                            '• Build a profile & pick interests\n'
                            '• Upgrade to seller and list merch\n'
                            '• Browse events and fandom categories\n'
                            '• Get help from the AI Fan Helper',
                      ),
                    ),
                    const SizedBox(height: 14),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 140),
                      child: _Section(
                        title: 'Credits',
                        body:
                            'Built with Flutter + Firebase.\n'
                            'Designed for fans, by fans.',
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Center(
                      child: Text(
                        '© 2026 FandomVerse',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: 18,
      blur: 18,
      gradient: LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0.04),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.45,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}
