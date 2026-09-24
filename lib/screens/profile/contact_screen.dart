import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/animations/app_transitions.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/lottie_view.dart';
import '../../widgets/liquid_glass.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  static const _email = 'support@fandomverse.app';

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
                        'Contact Us',
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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    Center(
                      child: LottieView(
                        width: 88,
                        height: 88,
                        asset: 'assets/lottie/sparkle.json',
                        fallback: const PulseDot(size: 72),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'We usually reply within 24h.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 13.5),
                    ),
                    const SizedBox(height: 24),
                    FadeSlideIn(
                      child: _ContactTile(
                        icon: Icons.mail_outline_rounded,
                        title: 'Email support',
                        subtitle: _email,
                        onTap: () async {
                          await Clipboard.setData(
                            const ClipboardData(text: _email),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Email copied to clipboard'),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 80),
                      child: _ContactTile(
                        icon: Icons.forum_outlined,
                        title: 'Community Discord',
                        subtitle: 'Chat with other fans (link coming soon)',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Discord invite opens soon'),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 140),
                      child: _ContactTile(
                        icon: Icons.bug_report_outlined,
                        title: 'Report a bug',
                        subtitle: 'Tell us what broke — we fix fast',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Bug form shipping with the next build',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                    GlassButton(
                      label: 'Copy email',
                      icon: Icons.copy_rounded,
                      variant: GlassButtonVariant.outline,
                      onPressed: () async {
                        await Clipboard.setData(
                          const ClipboardData(text: _email),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied $_email')),
                          );
                        }
                      },
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

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LiquidGlass(
        radius: 16,
        blur: 18,
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.11),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFFC1121F), Color(0xFF7F1D1D)],
                ),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white38,
            ),
          ],
        ),
      ),
    );
  }
}
