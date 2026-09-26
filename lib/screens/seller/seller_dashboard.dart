import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/catalog_docs.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/catalog_service.dart';
import '../../services/image_upload_service.dart';
import '../../services/user_service.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/liquid_glass.dart';

class SellerDashboardScreen extends StatelessWidget {
  const SellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;

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
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Seller dashboard',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showProductSheet(context, uid),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.35),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              if (uid == null)
                const Expanded(
                  child: Center(
                    child: Text(
                      'Sign in to manage listings.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                )
              else
                Expanded(
                  child: StreamBuilder<List<MerchProductDoc>>(
                    stream: CatalogService.instance.watchSellerMerch(uid),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Could not load listings: ${snap.error}',
                            style: const TextStyle(
                              color: Colors.white60,
                              height: 1.4,
                            ),
                          ),
                        );
                      }
                      final items = snap.data ?? const [];
                      if (items.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(28),
                            child: Text(
                              'No listings yet.\nTap + to create your first product.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white54,
                                height: 1.45,
                              ),
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final m = items[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GestureDetector(
                              onTap: () =>
                                  _showProductSheet(context, uid, existing: m),
                              child: LiquidGlass(
                                radius: 18,
                                blur: 20,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.12),
                                    Colors.white.withValues(alpha: 0.05),
                                  ],
                                ),
                                borderColor:
                                    Colors.white.withValues(alpha: 0.14),
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        color: Colors.white
                                            .withValues(alpha: 0.06),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.10),
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child:
                                          m.imageUrl?.isNotEmpty == true
                                              ? Image.network(
                                                  m.imageUrl!,
                                                  width: 52,
                                                  height: 52,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (_, _, _) => const Center(
                                                        child: Icon(
                                                          Icons
                                                              .inventory_2_outlined,
                                                          color:
                                                              Colors.white24,
                                                          size: 24,
                                                        ),
                                                      ),
                                                )
                                              : const Center(
                                                  child: Icon(
                                                    Icons
                                                        .inventory_2_outlined,
                                                    color: Colors.white24,
                                                    size: 24,
                                                  ),
                                                ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            m.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            m.soldCount > 0
                                                ? '${m.priceLabel} · ${m.active ? 'Active' : 'Paused'} · ${m.soldCount} sold'
                                                : '${m.priceLabel} · ${m.active ? 'Active' : 'Paused'}',
                                            style: TextStyle(
                                              color: m.active
                                                  ? AppColors.accent
                                                  : Colors.white54,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _showProductSheet(
                                        context,
                                        uid,
                                        existing: m,
                                      ),
                                      tooltip: 'Edit listing',
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: Colors.white54,
                                        size: 20,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => CatalogService.instance
                                          .setMerchActive(m.id, !m.active),
                                      icon: Icon(
                                        m.active
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.white70,
                                        size: 22,
                                      ),
                                    ),
                                  IconButton(
                                    onPressed: () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor:
                                              const Color(0xF2101018),
                                          title: const Text(
                                            'Delete listing?',
                                            style: TextStyle(
                                              color: Colors.white,
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
                                                  color: AppColors.accent,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok == true) {
                                        await CatalogService.instance
                                            .deleteMerch(m.id);
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
                              ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _showProductSheet(
    BuildContext context,
    String? uid, {
    MerchProductDoc? existing,
  }) async {
    if (uid == null) return;

    final editing = existing != null;
    final name = TextEditingController(text: existing?.name ?? '');
    final price = TextEditingController(text: existing?.priceLabel ?? '');
    final description = TextEditingController(
      text: existing?.description ?? '',
    );
    final stock = TextEditingController(
      text: existing?.stock?.toString() ?? '',
    );
    UserProfile? profile;
    try {
      profile = await UserService.instance.fetch(uid);
    } catch (_) {
      profile = null;
    }
    if (profile != null && !profile.isSeller && !profile.isAdmin) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upgrade to seller first to list products.'),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    final sellerName =
        profile?.shopName?.isNotEmpty == true ? profile!.shopName! : (profile?.name ?? 'Shop');

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final formKey = GlobalKey<FormState>();
        var loading = false;
        var uploadingImage = false;
        String? imageUrl = existing?.imageUrl;

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
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
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
                        editing ? 'Edit listing' : 'New listing',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 18),
                      AppTextField(
                        controller: name,
                        label: 'Product name',
                        prefixIcon: Icons.inventory_2_outlined,
                        validator: (v) => (v == null || v.trim().length < 2)
                            ? 'Name required'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: price,
                        label: 'Price (e.g. \$29)',
                        prefixIcon: Icons.attach_money_rounded,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Price required'
                                : null,
                      ),
                      const SizedBox(height: 14),
                      if (imageUrl != null) ...[
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                imageUrl!,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 64,
                                  height: 64,
                                  color:
                                      Colors.white.withValues(alpha: 0.06),
                                  child: const Icon(
                                    Icons.image_outlined,
                                    color: Colors.white24,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Image attached',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  setSheetState(() => imageUrl = null),
                              child: const Text(
                                'Remove',
                                style: TextStyle(color: Color(0xFFFF6B6B)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                      OutlinedButton.icon(
                        onPressed: uploadingImage
                            ? null
                            : () async {
                                setSheetState(() => uploadingImage = true);
                                try {
                                  final url = await ImageUploadService
                                      .instance
                                      .pickAndUpload(name: 'product');
                                  if (url != null) {
                                    imageUrl = url;
                                  }
                                } catch (e) {
                                  if (sheetContext.mounted) {
                                    ScaffoldMessenger.of(sheetContext)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          ImageUploadService.friendlyMessage(e),
                                        ),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (sheetContext.mounted) {
                                    setSheetState(
                                      () => uploadingImage = false,
                                    );
                                  }
                                }
                              },
                        icon: uploadingImage
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                imageUrl == null
                                    ? Icons.image_outlined
                                    : Icons.check_circle_outline_rounded,
                              ),
                        label: Text(
                          uploadingImage
                              ? 'Uploading…'
                              : imageUrl == null
                                  ? 'Upload product image'
                                  : 'Replace image',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: description,
                        label: 'Description (optional)',
                        prefixIcon: Icons.notes_rounded,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: stock,
                        label: 'Stock units (optional)',
                        prefixIcon: Icons.inventory_2_outlined,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return null;
                          final n = int.tryParse(t);
                          if (n == null || n < 0) {
                            return 'Enter a whole number 0 or more';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      GlassButton(
                        label: loading
                            ? (editing ? 'Saving…' : 'Creating…')
                            : (editing ? 'Save changes' : 'Create listing'),
                        isLoading: loading,
                        onPressed: () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          setSheetState(() => loading = true);
                          try {
                            final parsedStock =
                                int.tryParse(stock.text.trim());
                            if (editing) {
                              await CatalogService.instance.updateMerch(
                                existing.id,
                                {
                                  'name': name.text.trim(),
                                  'priceLabel': price.text.trim(),
                                  'description': description.text.trim(),
                                  'stock': parsedStock,
                                  'imageUrl': imageUrl,
                                },
                              );
                            } else {
                              await CatalogService.instance.createMerch(
                                name: name.text,
                                priceLabel: price.text.trim(),
                                sellerUid: uid,
                                sellerName: sellerName,
                                description: description.text,
                                imageUrl: imageUrl,
                                stock: parsedStock,
                              );
                            }
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
}
