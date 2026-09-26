import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/catalog_docs.dart';
import '../../services/cart_service.dart';
import '../../services/catalog_service.dart';
import '../../services/wishlist_service.dart';

/// The fan's wishlist — products saved with the heart button. Strictly
/// separate from the cart: saving never changes quantity, stock or checkout.
///
/// Test seams: [wishlistStream] (saved product ids), [productsStream],
/// and the three action callbacks.
class WishlistScreen extends StatefulWidget {
  const WishlistScreen({
    super.key,
    this.wishlistStream,
    this.productsStream,
    this.onOpenProduct,
    this.onRemove,
    this.onMoveToCart,
  });

  final Stream<List<String>>? wishlistStream;
  final Stream<List<MerchProductDoc>>? productsStream;
  final void Function(MerchProductDoc product)? onOpenProduct;
  final void Function(String productId)? onRemove;
  final void Function(MerchProductDoc product)? onMoveToCart;

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  late final Stream<List<String>> _ids;
  late final Stream<List<MerchProductDoc>> _products;

  @override
  void initState() {
    super.initState();
    _ids = widget.wishlistStream ??
        WishlistService.instance.watchMyProductIds();
    _products =
        widget.productsStream ?? CatalogService.instance.watchMerch();
  }

  void _open(MerchProductDoc product) {
    if (widget.onOpenProduct != null) {
      widget.onOpenProduct!(product);
      return;
    }
    Navigator.pushNamed(context, AppRoutes.product, arguments: product);
  }

  void _remove(String productId) {
    if (widget.onRemove != null) {
      widget.onRemove!(productId);
      return;
    }
    WishlistService.instance.remove(productId);
  }

  void _moveToCart(MerchProductDoc product) {
    if (widget.onMoveToCart != null) {
      widget.onMoveToCart!(product);
      return;
    }
    CartService.instance.addToCart(product).then((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${product.name} added to cart.'),
            backgroundColor: const Color(0xE616161F),
          ),
        );
    }).catchError((Object _) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not add to cart.'),
            backgroundColor: Color(0xE616161F),
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
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
                      const Expanded(
                        child: Text(
                          'Wishlist',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.favorite_outline_rounded,
                        color: Color(0xFFEF4444),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<String>>(
                    stream: _ids,
                    builder: (context, idsSnap) {
                      if (idsSnap.connectionState ==
                              ConnectionState.waiting &&
                          idsSnap.data == null) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      final ids = idsSnap.data ?? const <String>[];
                      if (ids.isEmpty) return const _WishlistEmpty();
                      return StreamBuilder<List<MerchProductDoc>>(
                        stream: _products,
                        builder: (context, prodSnap) {
                          final products = prodSnap.data ??
                              const <MerchProductDoc>[];
                          final byId = {for (final p in products) p.id: p};
                          final saved = <MerchProductDoc>[
                            for (final id in ids)
                              if (byId[id] != null) byId[id]!,
                          ];
                          if (saved.isEmpty && prodSnap.hasData) {
                            return const _WishlistEmpty();
                          }
                          if (saved.isEmpty) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                            physics: const BouncingScrollPhysics(),
                            itemCount: saved.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) =>
                                _tile(saved[i]),
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
      ),
    );
  }

  Widget _tile(MerchProductDoc product) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _open(product),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: product.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    product.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.sellerName.isNotEmpty
                            ? '${product.sellerName} · ${product.priceLabel}'
                            : product.priceLabel,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _remove(product.id),
                  tooltip: 'Remove from wishlist',
                  icon: const Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFFEF4444),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _moveToCart(product),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                  label: const Text(
                    'Move to cart',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () => _open(product),
                child: const Text(
                  'View',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WishlistEmpty extends StatelessWidget {
  const _WishlistEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.favorite_outline_rounded,
              size: 56,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nothing saved yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the heart on any product to keep it here — separate '
              'from your cart.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.merchExplore),
              child: const Text(
                'Browse the merch store',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
