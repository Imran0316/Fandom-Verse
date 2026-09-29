import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../core/pkr_format.dart';
import '../../core/theme/app_colors.dart';
import '../../models/catalog_docs.dart';
import '../../models/content_docs.dart';
import '../../models/post_docs.dart';
import '../../services/catalog_service.dart';
import '../../services/maps_config.dart';
import '../../services/image_upload_service.dart';
import '../../services/post_service.dart';
import '../../services/stream_cache.dart';
import '../../services/taxonomy_service.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/cached_image.dart';
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
  required Widget Function(
    BuildContext sheetContext,
    void Function(VoidCallback) setSheetState,
  )
  fields,
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
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.88,
              ),
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
                    Flexible(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: fields(sheetContext, setSheetState),
                      ),
                    ),
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
                            ScaffoldMessenger.of(
                              sheetContext,
                            ).showSnackBar(SnackBar(content: Text('$e')));
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

class CategoriesPanel extends StatefulWidget {
  const CategoriesPanel({super.key});

  @override
  State<CategoriesPanel> createState() => _CategoriesPanelState();
}

class _CategoriesPanelState extends State<CategoriesPanel> {
  final _fandoms = StreamCache<List<FandomDoc>>(
    () => TaxonomyService.instance.watchFandoms(),
  );

  void _edit(BuildContext context, FandomDoc? existing) {
    final name = TextEditingController(text: existing?.name ?? '');
    var icon = existing?.iconName ?? 'anime';
    var color = existing?.colorName ?? 'rose';
    var coverUrl = existing?.coverImageUrl;
    var uploading = false;

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
            const SizedBox(height: 14),
            if (coverUrl != null && coverUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 2.4,
                  child: CachedImage(url: coverUrl!, fit: BoxFit.cover),
                ),
              ),
            if (coverUrl != null && coverUrl!.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: uploading
                      ? null
                      : () => setSheetState(() => coverUrl = null),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Remove image'),
                ),
              ),
            OutlinedButton.icon(
              onPressed: uploading
                  ? null
                  : () async {
                      setSheetState(() => uploading = true);
                      try {
                        final url = await ImageUploadService.instance.pickAndUpload(
                          name:
                              'fandom-cover-${DateTime.now().millisecondsSinceEpoch}',
                        );
                        if (url != null) {
                          setSheetState(() => coverUrl = url);
                        }
                      } catch (error) {
                        if (sheetContext.mounted) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                ImageUploadService.friendlyMessage(error),
                              ),
                            ),
                          );
                        }
                      } finally {
                        if (sheetContext.mounted) {
                          setSheetState(() => uploading = false);
                        }
                      }
                    },
              icon: uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image_outlined),
              label: Text(
                uploading ? 'Uploading image…' : 'Choose cover image',
              ),
            ),
          ],
        );
      },
      onSubmit: () => TaxonomyService.instance.upsertFandom(
        id: existing?.id,
        name: name.text,
        iconName: icon,
        colorName: color,
        coverImageUrl: coverUrl,
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
          subtitle: 'Fandoms shown in Trending Fandoms. Admin write only.',
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
          child: StreamBuilder<List<FandomDoc>>(
            stream: _fandoms(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  snap.data == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return AdminEmptyBox(message: 'Error: ${snap.error}');
              }
              final items = snap.data ?? const [];
              if (items.isEmpty) {
                return const AdminEmptyBox(
                  message:
                      'No categories yet. Tap + to add one.\n'
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
                      blur: 0,
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
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(
                                          color: AppColors.accent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await TaxonomyService.instance.deleteFandom(
                                  c.id,
                                );
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

class EventsPanel extends StatefulWidget {
  const EventsPanel({super.key});

  @override
  State<EventsPanel> createState() => _EventsPanelState();
}

class _EventsPanelState extends State<EventsPanel> {
  final _events = StreamCache<List<FandomEventDoc>>(
    () => CatalogService.instance.watchEvents(activeOnly: false),
  );

  Future<void> _edit(BuildContext context, FandomEventDoc? existing) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final city = TextEditingController(text: existing?.city ?? '');
    final description = TextEditingController(
      text: existing?.description ?? '',
    );
    final venue = TextEditingController(text: existing?.venue ?? '');
    final address = TextEditingController(text: existing?.address ?? '');
    final latitude = TextEditingController(
      text: existing?.latitude?.toString() ?? '',
    );
    final longitude = TextEditingController(
      text: existing?.longitude?.toString() ?? '',
    );
    final ticketUrl = TextEditingController(text: existing?.ticketUrl ?? '');
    final organizer = TextEditingController(text: existing?.organizer ?? '');
    var icon = existing?.iconName ?? 'event';
    var color = existing?.colorName ?? 'red';
    var eventType = existing?.eventType ?? 'Convention';
    var startAt =
        existing?.startAt ?? DateTime.now().add(const Duration(days: 7));
    var endAt = existing?.endAt;
    var coverUrl = existing?.coverImageUrl;
    var uploading = false;

    Future<void> chooseDateTime({required bool chooseEnd}) async {
      final current = chooseEnd
          ? (endAt ?? startAt.add(const Duration(hours: 2)))
          : startAt;
      final date = await showDatePicker(
        context: context,
        initialDate: current,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (date == null || !context.mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
      );
      if (time == null) return;
      final result = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (chooseEnd) {
        endAt = result;
      } else {
        startAt = result;
      }
    }

    try {
      await showAdminSheet(
        context,
        title: existing == null ? 'Add event' : 'Edit event',
        fields: (sheetContext, setSheetState) {
          return Column(
            children: [
              AppTextField(
                controller: title,
                label: 'Event name',
                prefixIcon: Icons.event_outlined,
                validator: (value) => (value == null || value.trim().length < 2)
                    ? 'Name required'
                    : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: eventType,
                decoration: const InputDecoration(labelText: 'Event type'),
                items:
                    const [
                          'Convention',
                          'Cosplay Meetup',
                          'Screening',
                          'Fan Meetup',
                          'Other',
                        ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: (value) =>
                    setSheetState(() => eventType = value ?? eventType),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: city,
                label: 'City',
                prefixIcon: Icons.location_city_outlined,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'City required'
                    : null,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: venue,
                label: 'Venue',
                prefixIcon: Icons.place_outlined,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Venue required'
                    : null,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: address,
                label: 'Street address (optional)',
                prefixIcon: Icons.pin_drop_outlined,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await chooseDateTime(chooseEnd: false);
                  setSheetState(() {});
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text('Starts ${_adminDateTime(startAt)}'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await chooseDateTime(chooseEnd: true);
                  setSheetState(() {});
                },
                icon: const Icon(Icons.schedule_outlined),
                label: Text(
                  endAt == null
                      ? 'Add end time (optional)'
                      : 'Ends ${_adminDateTime(endAt!)}',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: latitude,
                      label: 'Latitude',
                      prefixIcon: Icons.north_rounded,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: (value) => _validCoordinate(value, -90, 90)
                          ? null
                          : 'Required: -90 to 90',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(
                      controller: longitude,
                      label: 'Longitude',
                      prefixIcon: Icons.east_rounded,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: (value) => _validCoordinate(value, -180, 180)
                          ? null
                          : 'Required: -180 to 180',
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final pin = await _selectEventPin(
                      context,
                      latitude: double.tryParse(latitude.text),
                      longitude: double.tryParse(longitude.text),
                      searchAddress: [
                        address.text,
                        venue.text,
                        city.text,
                      ].where((value) => value.trim().isNotEmpty).join(', '),
                    );
                    if (pin != null) {
                      setSheetState(() {
                        latitude.text = pin.coordinates.latitude
                            .toStringAsFixed(6);
                        longitude.text = pin.coordinates.longitude
                            .toStringAsFixed(6);
                        address.text = pin.address ?? '';
                      });
                    }
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Pick on map'),
                ),
              ),
              AppTextField(
                controller: description,
                label: 'Description (optional)',
                prefixIcon: Icons.notes_rounded,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: organizer,
                label: 'Organizer (optional)',
                prefixIcon: Icons.groups_outlined,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: ticketUrl,
                label: 'Ticket URL (optional)',
                prefixIcon: Icons.confirmation_num_outlined,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 14),
              if (coverUrl != null && coverUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 2.4,
                    child: CachedImage(url: coverUrl!, fit: BoxFit.cover),
                  ),
                ),
              if (coverUrl != null && coverUrl!.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: uploading
                        ? null
                        : () => setSheetState(() => coverUrl = null),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Remove image'),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: uploading
                    ? null
                    : () async {
                        setSheetState(() => uploading = true);
                        try {
                          final url = await ImageUploadService.instance
                              .pickAndUpload(
                                name:
                                    'event-cover-${DateTime.now().millisecondsSinceEpoch}',
                              );
                          if (url != null) setSheetState(() => coverUrl = url);
                        } catch (error) {
                          if (sheetContext.mounted) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ImageUploadService.friendlyMessage(error),
                                ),
                              ),
                            );
                          }
                        } finally {
                          if (sheetContext.mounted) {
                            setSheetState(() => uploading = false);
                          }
                        }
                      },
                icon: uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image_outlined),
                label: Text(
                  uploading ? 'Uploading image...' : 'Choose cover image',
                ),
              ),
              const SizedBox(height: 14),
              iconDropdown(
                value: icon,
                onChanged: (value) => setSheetState(() => icon = value ?? icon),
              ),
              const SizedBox(height: 14),
              colorDropdown(
                value: color,
                onChanged: (value) =>
                    setSheetState(() => color = value ?? color),
              ),
            ],
          );
        },
        onSubmit: () => CatalogService.instance.upsertEvent(
          id: existing?.id,
          title: title.text,
          city: city.text,
          dateLabel: _adminDateLabel(startAt),
          iconName: icon,
          colorName: color,
          coverImageUrl: coverUrl,
          startAt: startAt,
          endAt: endAt,
          description: description.text,
          eventType: eventType,
          venue: venue.text,
          address: address.text,
          latitude: double.parse(latitude.text),
          longitude: double.parse(longitude.text),
          ticketUrl: ticketUrl.text,
          organizer: organizer.text,
          isActive: existing?.isActive ?? true,
        ),
      );
    } finally {
      title.dispose();
      city.dispose();
      description.dispose();
      venue.dispose();
      address.dispose();
      latitude.dispose();
      longitude.dispose();
      ticketUrl.dispose();
      organizer.dispose();
    }
  }

  Future<void> _delete(BuildContext context, FandomEventDoc event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text('“${event.title}” will be removed from event discovery.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await CatalogService.instance.deleteEvent(event.id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminSectionHeader(
          title: 'Events',
          subtitle: 'Publish conventions, meetups and screenings for fans.',
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
            stream: _events(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  snap.data == null) {
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
                      blur: 0,
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
                                  '${e.eventType} · ${e.city} · ${e.dateLabel}',
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
                            onPressed: () => _delete(context, e),
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

bool _validCoordinate(String? value, double minimum, double maximum) {
  final coordinate = double.tryParse(value?.trim() ?? '');
  return coordinate != null &&
      coordinate.isFinite &&
      coordinate >= minimum &&
      coordinate <= maximum;
}

String _adminDateLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

String _adminDateTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '${_adminDateLabel(date)} · $hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
}

typedef _EventMapSelection = ({LatLng coordinates, String? address});

Future<_EventMapSelection?> _selectEventPin(
  BuildContext context, {
  double? latitude,
  double? longitude,
  required String searchAddress,
}) async {
  if (!MapsConfig.hasKey) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Configure a Google Maps key to pick a pin. Enter coordinates manually for now.',
        ),
      ),
    );
    return null;
  }
  final hasSavedCoordinates = latitude != null && longitude != null;
  final addressLocation = hasSavedCoordinates
      ? null
      : await _geocodeEventAddress(searchAddress);
  final initial = hasSavedCoordinates
      ? LatLng(latitude, longitude)
      : addressLocation ?? const LatLng(0, 0);
  if (!context.mounted) return null;
  var selected = initial;
  var selectedAddress =
      searchAddress.trim().isEmpty ||
          (!hasSavedCoordinates && addressLocation == null)
      ? null
      : searchAddress.trim();
  var lookingUpAddress = false;
  var didSelectPoint = false;
  return showDialog<_EventMapSelection>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Choose event location'),
        content: SizedBox(
          width: 560,
          height: 420,
          child: Column(
            children: [
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: initial,
                    zoom: hasSavedCoordinates || addressLocation != null
                        ? 15
                        : 2,
                  ),
                  onTap: (point) async {
                    setDialogState(() {
                      selected = point;
                      didSelectPoint = true;
                      selectedAddress = null;
                      lookingUpAddress = true;
                    });
                    final resolved = await _reverseGeocodeEventLocation(point);
                    if (!dialogContext.mounted) return;
                    setDialogState(() {
                      selectedAddress = resolved;
                      lookingUpAddress = false;
                    });
                  },
                  markers: {
                    Marker(
                      markerId: const MarkerId('event-location'),
                      position: selected,
                    ),
                  },
                  zoomControlsEnabled: true,
                  myLocationButtonEnabled: false,
                ),
              ),
              if (lookingUpAddress) const LinearProgressIndicator(),
              if (selectedAddress != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    selectedAddress!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else if (!lookingUpAddress)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    didSelectPoint
                        ? 'Address lookup unavailable. The selected coordinates will still be saved.'
                        : !hasSavedCoordinates &&
                              searchAddress.trim().isNotEmpty &&
                              addressLocation == null
                        ? 'Address not found. Move the map to the venue and select a point.'
                        : 'Tap the map to select a pin and look up its address.',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, (
              coordinates: selected,
              address: selectedAddress,
            )),
            child: const Text('Use location'),
          ),
        ],
      ),
    ),
  );
}

Future<LatLng?> _geocodeEventAddress(String address) async {
  if (!MapsConfig.hasKey || address.trim().isEmpty) return null;
  try {
    final response = await http
        .get(
          Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
            'address': address.trim(),
            'key': MapsConfig.apiKey,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final payload = jsonDecode(response.body);
    if (payload is! Map || payload['status'] != 'OK') return null;
    final results = payload['results'];
    if (results is! List || results.isEmpty || results.first is! Map) {
      return null;
    }
    final geometry = results.first['geometry'];
    final location = geometry is Map ? geometry['location'] : null;
    if (location is! Map ||
        location['lat'] is! num ||
        location['lng'] is! num) {
      return null;
    }
    return LatLng(
      (location['lat'] as num).toDouble(),
      (location['lng'] as num).toDouble(),
    );
  } catch (_) {
    return null;
  }
}

Future<String?> _reverseGeocodeEventLocation(LatLng location) async {
  if (!MapsConfig.hasKey) return null;
  try {
    final response = await http
        .get(
          Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
            'latlng': '${location.latitude},${location.longitude}',
            'key': MapsConfig.apiKey,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final payload = jsonDecode(response.body);
    if (payload is! Map || payload['status'] != 'OK') return null;
    final results = payload['results'];
    if (results is! List || results.isEmpty || results.first is! Map) {
      return null;
    }
    final formattedAddress = results.first['formatted_address'];
    return formattedAddress is String && formattedAddress.isNotEmpty
        ? formattedAddress
        : null;
  } catch (_) {
    return null;
  }
}

/* ================================== MERCH ================================= */

class MerchAdminPanel extends StatefulWidget {
  const MerchAdminPanel({super.key, this.showInactive = true});

  final bool showInactive;

  @override
  State<MerchAdminPanel> createState() => _MerchAdminPanelState();
}

class _MerchAdminPanelState extends State<MerchAdminPanel> {
  final _merch = StreamCache<List<MerchProductDoc>>(
    () => CatalogService.instance.watchMerch(activeOnly: false),
  );

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
            stream: _merch(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  snap.data == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return AdminEmptyBox(message: 'Error: ${snap.error}');
              }
              final items = (snap.data ?? const [])
                  .where((m) => widget.showInactive || m.active)
                  .toList();
              if (items.isEmpty) {
                return const AdminEmptyBox(
                  message:
                      'No products yet. Sellers create listings from '
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
                      blur: 0,
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(
                            alpha: m.active ? 0.12 : 0.06,
                          ),
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
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white.withValues(alpha: 0.06),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: m.imageUrl?.isNotEmpty == true
                                ? CachedImage(
                                    url: m.imageUrl!,
                                    fit: BoxFit.cover,
                                    width: 44,
                                    height: 44,
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.inventory_2_outlined,
                                      color: Colors.white24,
                                      size: 20,
                                    ),
                                  ),
                          ),
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
                                  '${formatPkrPrice(m.priceLabel)} · ${m.sellerName.isEmpty ? 'Seller' : m.sellerName}'
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
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(
                                          color: AppColors.accent,
                                        ),
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

class ContentModerationPanel extends StatefulWidget {
  const ContentModerationPanel({super.key});

  @override
  State<ContentModerationPanel> createState() => _ContentModerationPanelState();
}

class _ContentModerationPanelState extends State<ContentModerationPanel> {
  final _feed = StreamCache<List<PostDoc>>(
    () => PostService.instance.watchFeed(limit: 50),
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PostDoc>>(
      stream: _feed(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            snap.data == null) {
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
                                  await PostService.instance.adminDeletePost(
                                    p.id,
                                  );
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
