import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'liquid_glass.dart';

/// Indices: 0 Home · 1 Trending · 2 Search · 3 Library · 4 Profile
/// Pill hosts 0/1/3/4 — Search (2) is the detached circle.
class LiquidFloatingNav extends StatelessWidget {
  const LiquidFloatingNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _pillOrder = [0, 1, 3, 4];

  static const _labels = {
    0: 'Home',
    1: 'Trending',
    2: 'Search',
    3: 'Library',
    4: 'Profile',
  };

  static const _icons = {
    0: (Icons.home_rounded, Icons.home_outlined),
    1: (
      Icons.local_fire_department_rounded,
      Icons.local_fire_department_outlined,
    ),
    2: (Icons.search_rounded, Icons.search_rounded),
    3: (Icons.folder_rounded, Icons.folder_outlined),
    4: (Icons.person_rounded, Icons.person_outline_rounded),
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + 16,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          Expanded(
            child: LiquidGlassPill(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  for (final i in _pillOrder)
                    Expanded(
                      child: _NavItem(
                        index: i,
                        label: _labels[i]!,
                        activeIcon: _icons[i]!.$1,
                        inactiveIcon: _icons[i]!.$2,
                        selected: selectedIndex == i,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          _SearchCircle(
            selected: selectedIndex == 2,
            onTap: () => onSelected(2),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.92),
                    Colors.white.withValues(alpha: 0.72),
                  ],
                )
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? activeIcon : inactiveIcon,
              size: 21,
              color: selected ? AppColors.primary : Colors.white70,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 10,
                height: 1.1,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.primary : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchCircle extends StatelessWidget {
  const _SearchCircle({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? [
                    Colors.white.withValues(alpha: 0.95),
                    Colors.white.withValues(alpha: 0.75),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.08),
                  ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
            if (selected)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Icon(
              Icons.search_rounded,
              size: 24,
              color: selected ? AppColors.primary : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
