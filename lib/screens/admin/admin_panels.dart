import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/catalog_docs.dart';
import '../../models/post_docs.dart';
import '../../services/catalog_service.dart';
import '../../services/post_service.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/liquid_glass.dart';

class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminEmptyBox extends StatelessWidget {
  const AdminEmptyBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LiquidGlass(
        radius: 18,
        blur: 20,
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60, height: 1.4),
        ),
      ),
    );
  }
}

Future<void> showAdminSheet(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext sheetContext, void Function(VoidCallback) setSheetState) fields,
  required Future<void> Function() onSubmit,
}) async {
  final formKey = GlobalKey<FormState>();
  var loading = false;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              decoration: BoxDecoration(
                color: const Color(0xF2101018),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    fields(sheetContext, setSheetState),
                    const SizedBox(height: 20),
                    GlassButton(
                      label: loading ? 'Saving…' : 'Save',
                      isLoading: loading,
                      onPressed: () async {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        setSheetState(() => loading = true);
                        try {
                          await onSubmit();
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        } catch (e) {
                          setSheetState(() => loading = false);
                          if (sheetContext.mounted) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(content: Text('$e')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

DropdownButtonFormField<String> iconDropdown({
  required String value,
  required ValueChanged<String?> onChanged,
  String label = 'Icon',
}) {
  return DropdownButtonFormField<String>(
    initialValue: CatalogIcons.map.containsKey(value)
        ? value
        : CatalogIcons.map.keys.first,
    dropdownColor: const Color(0xF2101018),
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(CatalogIcons.fromName(value), size: 20),
      filled: true,
      fillColor: const Color(0x59000000),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: AppColors.accent, width: 1.6),
      ),
    ),
    items: CatalogIcons.map.entries
        .map(
          (e) => DropdownMenuItem(
            value: e.key,
            child: Row(
              children: [
                Icon(e.value, size: 18, color: Colors.white70),
                const SizedBox(width: 10),
                Text(e.key, style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        )
        .toList(),
    onChanged: onChanged,
  );
}

DropdownButtonFormField<String> colorDropdown({
  required String value,
  required ValueChanged<String?> onChanged,
  String label = 'Color',
}) {
  return DropdownButtonFormField<String>(
    initialValue: CatalogIcons.colors.containsKey(value) ? value : 'rose',
    dropdownColor: const Color(0xF2101018),
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        Icons.palette_outlined,
        size: 20,
        color: CatalogIcons.colorFromName(value),
      ),
      filled: true,
      fillColor: const Color(0x59000000),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: AppColors.accent, width: 1.6),
      ),
    ),
    items: CatalogIcons.colors.entries
        .map(
          (e) => DropdownMenuItem(
            value: e.key,
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: e.value,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                ),
                const SizedBox(width: 10),
                Text(e.key, style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        )
        .toList(),
    onChanged: onChanged,
  );
}

/* ================================ CATEGORIES =============================== */

class CategoriesPanel extends StatelessWidget {
  const CategoriesPanel({super.key});

  void _edit(BuildContext context, FandomCategoryDoc? existing) {
    final name = TextEditingController(text: existing?.name ?? '');
    var icon = existing?.iconName ?? 'anime';
    var color = existing?.colorName ?? 'rose';

    showAdminSheet(
      context,
      title: existing == null ? 'Add category' : 'Edit category',
      fields: (sheetContext, setSheetState) {
        return Column(
          children: [
            AppTextField(
              controller: name,
              label: 'Category name',
              prefixIcon: Icons.label_outline_rounded,
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? 'Name required' : null,
            ),
            const SizedBox(height: 14),
            iconDropdown(
              value: icon,
              onChanged: (v) => setSheetState(() => icon = v ?? icon),
            ),
            const SizedBox(height: 14),
            colorDropdown(
              value: color,
              onChanged: (v) => setSheetState(() => color = v ?? color),
            ),
          ],
        );
      },
      onSubmit: () => CatalogService.instance.upsertCategory(
        id: existing?.id,
        name: name.text,
        iconName: icon,
        colorName: color,
        sortOrder: existing?.sortOrder ?? 99,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminSectionHeader(
          title: 'Category management',
          subtitle: 'Fandom categories shown on Home. Admin write only.',
          action: IconButton(
            onPressed: () => _edit(context, null),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.3),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add_rounded),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<FandomCategoryDoc>>(
            stream: CatalogService.instance.watchCategories(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return AdminEmptyBox(message: 'Error: ${snap.error}');
              }
              final items = snap.data ?? const [];
              if (items.isEmpty) {
                return const AdminEmptyBox(
                  message: 'No categories yet. Tap + to add one.\n'
                      'Republish firestore.rules (categories) if writes fail.',
                );
              }
              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final c = items[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: LiquidGlass(
                      radius: 16,
                      blur: 18,
                      gradient: LinearGradient(
                        colors: [
                          c.color.withValues(alpha: 0.2),
                          Colors.white.withValues(alpha: 0.05),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: c.color.withValues(alpha: 0.35),
                            ),
                            child: Icon(c.icon, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              c.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _edit(context, c),
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xF2101018),
                                  title: const Text(
                                    'Delete category?',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(color: AppColors.accent),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await CatalogService.instance
                                    .deleteCategory(c.id);
                              }
                            },
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white54,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/* ================================= EVENTS ================================= */

class EventsPanel extends StatelessWidget {
  const EventsPanel({super.key});

  void _edit(BuildContext context, FandomEventDoc? existing) {
    final title = TextEditingController(text: existing?.title ?? '');
    final city = TextEditingController(text: existing?.city ?? '');
    final date = TextEditingController(text: existing?.dateLabel ?? '');
    var icon = existing?.iconName ?? 'event';
    var color = existing?.colorName ?? 'red';

    showAdminSheet(
      context,
      title: existing == null ? 'Add event' : 'Edit event',
      fields: (sheetContext, setSheetState) {
        return Column(
          children: [
            AppTextField(
              controller: title,
              label: 'Event name',
              prefixIcon: Icons.event_outlined,
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? 'Name required' : null,
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: city,
              label: 'City',
              prefixIcon: Icons.location_on_outlined,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'City required' : null,
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: date,
              label: 'Date label (e.g. Jul 12)',
              prefixIcon: Icons.calendar_today_outlined,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Date required' : null,
            ),
            const SizedBox(height: 14),
            iconDropdown(
              value: icon,
              onChanged: (v) => setSheetState(() => icon = v ?? icon),
            ),
            const SizedBox(height: 14),
            colorDropdown(
              value: color,
              onChanged: (v) => setSheetState(() => color = v ?? color),
            ),
          ],
        );
      },
      onSubmit: () => CatalogService.instance.upsertEvent(
        id: existing?.id,
        title: title.text,
        city: city.text,
        dateLabel: date.text,
        iconName: icon,
        colorName: color,
        startAt: existing?.startAt ?? DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminSectionHeader(
          title: 'Events',
          subtitle: 'Conventions & meetups on Home. Admin write only.',
          action: IconButton(
            onPressed: () => _edit(context, null),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.3),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add_rounded),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<FandomEventDoc>>(
            stream: CatalogService.instance.watchEvents(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return AdminEmptyBox(message: 'Error: ${snap.error}');
              }
              final items = snap.data ?? const [];
              if (items.isEmpty) {
                return const AdminEmptyBox(
                  message: 'No events yet. Tap + to add one.',
                );
              }
              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final e = items[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: LiquidGlass(
                      radius: 16,
                      blur: 18,
                      gradient: LinearGradient(
                        colors: [
                          e.color.withValues(alpha: 0.35),
                          e.color.withValues(alpha: 0.12),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(e.icon, color: Colors.white, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${e.city} · ${e.dateLabel}',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _edit(context, e),
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                CatalogService.instance.deleteEvent(e.id),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white54,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/* ================================== MERCH ================================= */

class MerchAdminPanel extends StatelessWidget {
  const MerchAdminPanel({super.key, this.showInactive = true});

  final bool showInactive;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminSectionHeader(
          title: 'Merchandise',
          subtitle: 'All listings. Pause, resume or remove products.',
        ),
        Expanded(
          child: StreamBuilder<List<MerchProductDoc>>(
            stream: CatalogService.instance.watchMerch(activeOnly: false),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return AdminEmptyBox(message: 'Error: ${snap.error}');
              }
              final items = (snap.data ?? const [])
                  .where((m) => showInactive || m.active)
                  .toList();
              if (items.isEmpty) {
                return const AdminEmptyBox(
                  message: 'No products yet. Sellers create listings from '
                      'their Seller dashboard.',
                );
              }
              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final m = items[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: LiquidGlass(
                      radius: 16,
                      blur: 18,
                      gradient: LinearGradient(
                        colors: [
                          m.color.withValues(alpha: m.active ? 0.28 : 0.1),
                          Colors.white.withValues(alpha: 0.05),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Text(m.emoji, style: const TextStyle(fontSize: 26)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${m.priceLabel} · ${m.sellerName.isEmpty ? 'Seller' : m.sellerName}'
                                  '${m.active ? '' : ' · paused'}',
                                  style: TextStyle(
                                    color: m.active
                                        ? AppColors.accent
                                        : Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: m.active ? 'Pause' : 'Resume',
                            onPressed: () => CatalogService.instance
                                .setMerchActive(m.id, !m.active),
                            icon: Icon(
                              m.active
                                  ? Icons.pause_circle_outline_rounded
                                  : Icons.play_circle_outline_rounded,
                              color: Colors.white70,
                              size: 22,
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xF2101018),
                                  title: const Text(
                                    'Delete product?',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(color: AppColors.accent),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await CatalogService.instance.deleteMerch(m.id);
                              }
                            },
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white54,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/* ============================ CONTENT / REPORTS ============================ */

class ContentModerationPanel extends StatelessWidget {
  const ContentModerationPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PostDoc>>(
      stream: PostService.instance.watchFeed(limit: 50),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final posts = snap.data ?? const <PostDoc>[];
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            AdminSectionHeader(
              title: 'Content moderation',
              subtitle:
                  'Live posts. Delete to remove from the feed for everyone.',
            ),
            if (posts.isEmpty)
              const AdminEmptyBox(
                message:
                    'No posts yet.\n'
                    'Create one from Fan Feed or a community — it will appear here.',
              )
            else
              ...posts.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LiquidGlass(
                    radius: 16,
                    blur: 20,
                    padding: const EdgeInsets.all(14),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.1),
                        Colors.white.withValues(alpha: 0.04),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.authorName.isEmpty ? 'Fan' : p.authorName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (p.communityName != null &&
                                p.communityName!.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                                child: Text(
                                  p.communityName!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: const Color(0xFF1A1A22),
                                    title: const Text(
                                      'Delete post?',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    content: Text(
                                      p.body.isEmpty
                                          ? 'Remove this post?'
                                          : p.body,
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(
                                            color: Color(0xFFFF6B6B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await PostService.instance
                                      .adminDeletePost(p.id);
                                }
                              },
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xFFFF6B6B),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.body,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.35,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '♥ ${p.likeCount}   💬 ${p.commentCount}   ↻ ${p.repostCount}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ReportsPanel extends StatelessWidget {
  const ReportsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        const AdminSectionHeader(
          title: 'Reports queue',
          subtitle: 'User reports on content and accounts.',
        ),
        const AdminEmptyBox(
          message:
              'Reports collection is empty.\n'
              'Queue UI activates with the feed / reporting module.',
        ),
      ],
    );
  }
}
