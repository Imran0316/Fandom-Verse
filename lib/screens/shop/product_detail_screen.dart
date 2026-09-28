import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/catalog_docs.dart';
import '../../services/cart_service.dart';
import '../../services/catalog_service.dart';
import '../../services/stream_cache.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/liquid_glass.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.product});

  final MerchProductDoc product;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _qty = 1;
  bool _busy = false;
  final _cartCount = StreamCache<int>(
    () => CartService.instance.watchCartCount(),
  );
  late final _product = StreamCache<MerchProductDoc?>(
    () => CatalogService.instance.watchMerchProduct(widget.product.id),
  );
  late final _reviews = StreamCache<List<ProductReviewDoc>>(
    () => CatalogService.instance.watchReviews(widget.product.id),
  );

  Future<void> _addToCart({bool goCheckout = false}) async {
    if (_busy) return;
    final stock = widget.product.stock;
    if (stock != null && stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This listing is out of stock.')),
      );
      return;
    }
    var qty = _qty;
    if (stock != null && qty > stock) qty = stock;
    setState(() => _busy = true);
    try {
      await CartService.instance.addToCart(widget.product, qty: qty);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            goCheckout
                ? 'Added — opening checkout…'
                : '${widget.product.name} added to cart',
          ),
        ),
      );
      if (goCheckout) {
        Navigator.pushNamed(context, AppRoutes.checkout);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final soldOut = p.stock != null && p.stock! <= 0;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 4,
                  left: 8,
                  right: 16,
                  height: 54,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.55),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        LiquidGlassPill(
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            style: IconButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(9),
                              minimumSize: const Size(38, 38),
                              iconSize: 20,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        ),
                        const Spacer(),
                        StreamBuilder<int>(
                          stream: _cartCount(),
                          builder: (context, countSnap) {
                            final n = countSnap.data ?? 0;
                            return LiquidGlassPill(
                              child: IconButton(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.cart,
                                ),
                                style: IconButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.all(9),
                                  minimumSize: const Size(38, 38),
                                  iconSize: 20,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: Badge(
                                  isLabelVisible: n > 0,
                                  label: Text(
                                    '$n',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.shopping_bag_outlined,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  children: [
                    Expanded(
                      child: StreamBuilder<MerchProductDoc?>(
                        stream: _product(),
                        builder: (context, snap) {
                          final p = snap.data ?? widget.product;
                          return ListView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            children: [
                              Container(
                                height: 280,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  color: Colors.white.withValues(alpha: 0.06),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.14),
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: p.imageUrl?.isNotEmpty == true
                                    ? Image.network(
                                        p.imageUrl!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        errorBuilder: (_, _, _) => const Center(
                                          child: Icon(
                                            Icons.inventory_2_outlined,
                                            color: Colors.white24,
                                            size: 64,
                                          ),
                                        ),
                                      )
                                    : const Center(
                                        child: Icon(
                                          Icons.inventory_2_outlined,
                                          color: Colors.white24,
                                          size: 64,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                p.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (p.reviewCount > 0 || p.soldCount > 0) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    if (p.reviewCount > 0)
                                      _StatChip(
                                        icon: Icons.star_rounded,
                                        iconColor: const Color(0xFFFFD166),
                                        label:
                                            '${p.rating.toStringAsFixed(1)} (${p.reviewCount} ${p.reviewCount == 1 ? 'review' : 'reviews'})',
                                      ),
                                    if (p.soldCount > 0)
                                      _StatChip(
                                        icon: Icons.trending_up_rounded,
                                        iconColor: AppColors.accent,
                                        label: '${p.soldCount} sold',
                                      ),
                                  ],
                                ),
                              ],
                              if (p.sellerName.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                LiquidGlass(
                                  radius: 14,
                                  blur: 16,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.09),
                                      Colors.white.withValues(alpha: 0.035),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.primary,
                                              AppColors.accent,
                                            ],
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          _initials(p.sellerName),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Sold by',
                                              style: TextStyle(
                                                color: Colors.white38,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              p.sellerName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.storefront_outlined,
                                        size: 16,
                                        color: Colors.white38,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Text(
                                    p.priceLabel,
                                    style: const TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const Spacer(),
                                  const _StatChip(
                                    icon: Icons.delivery_dining_rounded,
                                    iconColor: AppColors.accent,
                                    label: 'Free delivery',
                                  ),
                                ],
                              ),
                              if (p.stock != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  p.stock! <= 0
                                      ? 'Out of stock'
                                      : p.stock! <= 10
                                      ? 'Only ${p.stock} left — order soon'
                                      : 'In stock',
                                  style: TextStyle(
                                    color: p.stock! <= 0
                                        ? const Color(0xFFFF6B6B)
                                        : p.stock! <= 10
                                        ? const Color(0xFFFFD166)
                                        : AppColors.accent,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              if (p.description.isNotEmpty) ...[
                                const SizedBox(height: 18),
                                LiquidGlass(
                                  radius: 18,
                                  blur: 20,
                                  padding: const EdgeInsets.all(16),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.1),
                                      Colors.white.withValues(alpha: 0.04),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Description',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        p.description,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          height: 1.45,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              LiquidGlass(
                                radius: 18,
                                blur: 20,
                                padding: const EdgeInsets.all(16),
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
                                        const Text(
                                          'Reviews',
                                          key: Key('reviews_heading'),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (p.reviewCount > 0) ...[
                                          const Icon(
                                            Icons.star_rounded,
                                            color: Color(0xFFFFD166),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            p.rating.toStringAsFixed(1),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '(${p.reviewCount})',
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    StreamBuilder<List<ProductReviewDoc>>(
                                      stream: _reviews(),
                                      builder: (context, reviewSnap) {
                                        if (reviewSnap.hasError) {
                                          return const Text(
                                            'Could not load reviews right now.',
                                            style: TextStyle(
                                              color: Colors.white60,
                                              fontSize: 13.5,
                                              height: 1.4,
                                            ),
                                          );
                                        }
                                        final reviews = reviewSnap.data;
                                        if (reviews == null) {
                                          return const Text(
                                            'Loading reviews…',
                                            style: TextStyle(
                                              color: Colors.white54,
                                              fontSize: 13.5,
                                            ),
                                          );
                                        }
                                        if (reviews.isEmpty) {
                                          return const Text(
                                            'No reviews yet — be the first to rate '
                                            'this product.',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13.5,
                                              height: 1.4,
                                            ),
                                          );
                                        }
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            for (final r in reviews)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 12,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        for (
                                                          var i = 1;
                                                          i <= 5;
                                                          i++
                                                        )
                                                          Icon(
                                                            Icons.star_rounded,
                                                            color: i <= r.rating
                                                                ? const Color(
                                                                    0xFFFFD166,
                                                                  )
                                                                : Colors
                                                                      .white24,
                                                            size: 14,
                                                          ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            r.authorName,
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white54,
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      r.text,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 13,
                                                        height: 1.5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      width: double.infinity,
                                      child: GlassButton(
                                        label: 'Write a review',
                                        variant: GlassButtonVariant.outline,
                                        onPressed: _showReviewDialog,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                      child: LiquidGlass(
                        radius: 22,
                        blur: 24,
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.12),
                            Colors.white.withValues(alpha: 0.05),
                          ],
                        ),
                        borderColor: Colors.white.withValues(alpha: 0.16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, -6),
                          ),
                        ],
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Quantity',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                _QtyButton(
                                  icon: Icons.remove_rounded,
                                  onTap: _qty > 1
                                      ? () => setState(() => _qty--)
                                      : null,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    '$_qty',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                _QtyButton(
                                  icon: Icons.add_rounded,
                                  onTap:
                                      widget.product.stock == null ||
                                          _qty < widget.product.stock!
                                      ? () => setState(() => _qty++)
                                      : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: GlassButton(
                                    label: soldOut
                                        ? 'Out of stock'
                                        : 'Add to cart',
                                    isLoading: _busy,
                                    onPressed: (_busy || soldOut)
                                        ? null
                                        : () => _addToCart(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GlassButton(
                                    label: 'Buy now',
                                    variant: GlassButtonVariant.outline,
                                    onPressed: (_busy || soldOut)
                                        ? null
                                        : () => _addToCart(goCheckout: true),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showReviewDialog() async {
    final controller = TextEditingController();
    final rating = ValueNotifier<int>(5);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundDeep,
        title: const Text(
          'Write a review',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<int>(
              valueListenable: rating,
              builder: (context, value, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final idx = i + 1;
                  return IconButton(
                    onPressed: () => rating.value = idx,
                    icon: Icon(
                      Icons.star_rounded,
                      color: idx <= value
                          ? const Color(0xFFFFD166)
                          : Colors.white24,
                    ),
                  );
                }),
              ),
            ),
            TextField(
              controller: controller,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Share your thoughts...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please write a few words first.'),
                  ),
                );
                return;
              }
              try {
                await CatalogService.instance.addReview(
                  productId: widget.product.id,
                  rating: rating.value,
                  text: text,
                );
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not save your review. Sign in and try again.',
                      ),
                    ),
                  );
                }
                return;
              }
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thanks — your review is live!'),
                  ),
                );
              }
            },
            child: const Text(
              'Submit',
              style: TextStyle(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: onTap == null ? 0.04 : 0.1),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? Colors.white24 : Colors.white,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  if (words.isEmpty) return '?';
  final first = words.first.isNotEmpty ? words.first[0] : '';
  if (words.length == 1) return first.toUpperCase();
  final second = words.last.isNotEmpty ? words.last[0] : '';
  return (first + second).toUpperCase();
}
