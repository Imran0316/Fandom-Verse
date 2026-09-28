import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/cart_docs.dart';
import '../../services/cart_service.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/liquid_glass.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key, this.cartStream});

  /// Test seam — defaults to the live Firestore cart.
  final Stream<List<CartItemDoc>>? cartStream;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  int _total(List<CartItemDoc> items) {
    var t = 0;
    for (final i in items) {
      t += i.lineTotalCents;
    }
    return t;
  }

  String _format(int cents) {
    final d = cents ~/ 100;
    final r = cents % 100;
    return r == 0 ? '$d' : '$d.${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: StreamBuilder<List<CartItemDoc>>(
            stream: widget.cartStream ?? CartService.instance.watchCart(),
            builder: (context, snap) {
              final items = snap.data ?? const <CartItemDoc>[];
              final total = _total(items);
              var count = 0;
              for (final i in items) {
                count += i.quantity;
              }

              return SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Your cart',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (items.isNotEmpty)
                                  Text(
                                    '$count ${count == 1 ? 'item' : 'items'}',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (items.isNotEmpty)
                            TextButton(
                              onPressed: () async {
                                await CartService.instance.clearCart();
                              },
                              child: const Text(
                                'Clear',
                                style: TextStyle(color: Color(0xFFFF6B6B)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (items.isEmpty)
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 36),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                LiquidGlass(
                                  radius: 24,
                                  blur: 20,
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary.withValues(alpha: 0.25),
                                      Colors.white.withValues(alpha: 0.05),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  child: const Icon(
                                    Icons.shopping_cart_outlined,
                                    color: Colors.white,
                                    size: 34,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Cart is empty',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Browse merch on Home and tap Add to cart.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: 200,
                                  child: GlassButton(
                                    label: 'Browse merch',
                                    variant: GlassButtonVariant.outline,
                                    height: 48,
                                    onPressed: () =>
                                        Navigator.pushReplacementNamed(
                                      context,
                                      AppRoutes.merchExplore,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else ...[
                      Expanded(
                        child: ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final item = items[i];
                            return _CartRow(
                              item: item,
                              onInc: () => CartService.instance.setQuantity(
                                item.productId,
                                item.quantity + 1,
                              ),
                              onDec: () => CartService.instance.setQuantity(
                                item.productId,
                                item.quantity - 1,
                              ),
                              onRemove: () =>
                                  CartService.instance.removeFromCart(
                                item.productId,
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: LiquidGlass(
                          radius: 20,
                          blur: 0,
                          padding: const EdgeInsets.all(16),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.1),
                              Colors.white.withValues(alpha: 0.04),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SummaryLine(
                                label: 'Subtotal',
                                value: '\$${_format(total)}',
                              ),
                              const SizedBox(height: 6),
                              const _SummaryLine(
                                label: 'Delivery',
                                value: 'Free',
                                valueColor: Color(0xFF10B981),
                              ),
                              const SizedBox(height: 10),
                              const Divider(
                                color: Colors.white12,
                                height: 14,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Total',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '\$${_format(total)}',
                                    style: const TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              GlassButton(
                                label: 'Proceed to checkout',
                                icon: Icons.arrow_forward_rounded,
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.checkout,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size.fromHeight(36),
                                ),
                                child: const Text(
                                  'Continue shopping',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 13.5),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
      ],
    );
  }
}

class _CartRow extends StatelessWidget {
  const _CartRow({
    required this.item,
    required this.onInc,
    required this.onDec,
    required this.onRemove,
  });

  final CartItemDoc item;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: 16,
      blur: 0,
      padding: const EdgeInsets.all(12),
      gradient: LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0.04),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: item.imageUrl?.isNotEmpty == true
                ? Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    width: 56,
                    height: 56,
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.white24,
                        size: 24,
                      ),
                    ),
                  )
                : const Center(
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.white24,
                      size: 24,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.priceLabel} each',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _TinyBtn(icon: Icons.remove_rounded, onTap: onDec),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _TinyBtn(icon: Icons.add_rounded, onTap: onInc),
                    const Spacer(),
                    Text(
                      item.lineTotalLabel,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            children: [
              const SizedBox(height: 2),
              IconButton(
                onPressed: onRemove,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 30,
                  minHeight: 30,
                ),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white38,
                  size: 18,
                ),
                tooltip: 'Remove',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TinyBtn extends StatelessWidget {
  const _TinyBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.1),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    );
  }
}
