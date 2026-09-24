import 'package:flutter/material.dart';

import '../../core/animations/app_transitions.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/liquid_glass.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const _items = [
    (
      Icons.favorite_rounded,
      'Likes',
      'When someone likes your posts or listings',
      true,
    ),
    (
      Icons.chat_bubble_outline_rounded,
      'Comments & replies',
      'Conversations on your content',
      true,
    ),
    (
      Icons.storefront_rounded,
      'Orders & sales',
      'New orders on your shop',
      true,
    ),
    (
      Icons.event_rounded,
      'Events nearby',
      'Conventions and meetups you might like',
      true,
    ),
    (
      Icons.campaign_rounded,
      'Product updates',
      'New FandomVerse features',
      false,
    ),
    (
      Icons.smart_toy_outlined,
      'AI Fan Helper tips',
      'Weekly fandom digests',
      false,
    ),
  ];

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
                        'Notifications',
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
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  children: [
                    const Text(
                      'Choose what you want to hear about.',
                      style: TextStyle(color: Colors.white54, fontSize: 13.5),
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < _items.length; i++)
                      FadeSlideIn(
                        delay: Duration(milliseconds: i * 50),
                        child: _ToggleTile(
                          icon: _items[i].$1,
                          title: _items[i].$2,
                          subtitle: _items[i].$3,
                          initial: _items[i].$4,
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

class _ToggleTile extends StatefulWidget {
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.initial,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool initial;

  @override
  State<_ToggleTile> createState() => _ToggleTileState();
}

class _ToggleTileState extends State<_ToggleTile> {
  late bool _on = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LiquidGlass(
        radius: 16,
        blur: 18,
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: _on ? 0.12 : 0.06),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(widget.icon, color: _on ? AppColors.accent : Colors.white38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _on,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.primary,
              onChanged: (v) => setState(() => _on = v),
            ),
          ],
        ),
      ),
    );
  }
}
