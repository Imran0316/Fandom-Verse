import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/catalog_docs.dart';
import '../../services/cart_service.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/liquid_glass.dart';

// Simple in-memory review model for UI/demo purposes.
class _Review {
  _Review({required this.author, required this.text, required this.rating, required this.time});
  final String author;
  final String text;
  final int rating;
  final DateTime time;
}

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.product});

  final MerchProductDoc product;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _qty = 1;
  bool _busy = false;
  final List<_Review> _reviews = [
    _Review(
      author: 'Ayesha, verified buyer',
      text: '“Fits perfectly and the print quality is excellent.”',
      rating: 5,
      time: DateTime.now().subtract(const Duration(days: 12)),
    ),
  ];

  Future<void> _addToCart({bool goCart = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await CartService.instance.addToCart(widget.product, qty: _qty);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            goCart
                ? 'Added — opening cart…'
                : '${widget.product.name} added to cart',
          ),
        ),
      );
      if (goCart) {
        Navigator.pushReplacementNamed(context, '/cart');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final color = p.color;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
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
                      const Expanded(
                        child: Text(
                          'Product',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      Container(
                        height: 280,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              color.withValues(alpha: 0.55),
                              color.withValues(alpha: 0.15),
                            ],
                          ),
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
                                errorBuilder: (_, _, _) => Center(
                                  child: Text(
                                    p.emoji,
                                    style: const TextStyle(fontSize: 72),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  p.emoji,
                                  style: const TextStyle(fontSize: 72),
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
                      const SizedBox(height: 6),
                      if (p.sellerName.isNotEmpty)
                        Text(
                          'Sold by ${p.sellerName}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13.5,
                          ),
                        ),
                      const SizedBox(height: 14),
                      Text(
                        p.priceLabel,
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                Spacer(),
                                Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFFFD166),
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '4.8',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Loved by 94% of shoppers.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13.5,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Render current reviews (newest first)
                            ..._reviews.map((r) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        for (var i = 1; i <= 5; i++)
                                          Icon(
                                            Icons.star_rounded,
                                            color: i <= r.rating ? const Color(0xFFFFD166) : Colors.white24,
                                            size: 14,
                                          ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            r.author,
                                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      r.text,
                                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
                                    ),
                                  ],
                                ),
                              );
                            }),
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
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Text(
                            'Qty',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 14),
                          _QtyButton(
                            icon: Icons.remove_rounded,
                            onTap: _qty > 1
                                ? () => setState(() => _qty--)
                                : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                            onTap: () => setState(() => _qty++),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: GlassButton(
                          label: 'Add to cart',
                          isLoading: _busy,
                          onPressed: _busy ? null : () => _addToCart(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GlassButton(
                          label: 'Buy now',
                          variant: GlassButtonVariant.outline,
                          onPressed: _busy ? null : () => _addToCart(goCart: true),
                        ),
                      ),
                    ],
                  ),
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
        title: const Text('Write a review', style: TextStyle(color: Colors.white)),
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
                      color: idx <= value ? const Color(0xFFFFD166) : Colors.white24,
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
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              final newReview = _Review(
                author: 'You',
                text: text.isEmpty ? 'No comment.' : text,
                rating: rating.value,
                time: DateTime.now(),
              );
              setState(() => _reviews.insert(0, newReview));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Thanks for your review! Rating: ${rating.value}')),
              );
            },
            child: const Text('Submit', style: TextStyle(color: AppColors.accent)),
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
