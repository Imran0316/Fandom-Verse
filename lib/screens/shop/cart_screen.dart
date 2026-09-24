import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/cart_docs.dart';
import '../../models/catalog_docs.dart';
import '../../services/cart_service.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/liquid_glass.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _address = TextEditingController();
  bool _checkingOut = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

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

  Future<void> _checkout(List<CartItemDoc> items) async {
    if (_checkingOut || items.isEmpty) return;
    setState(() => _checkingOut = true);
    try {
      final id = await CartService.instance.checkout(shipTo: _address.text);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xF2101018),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Order placed 🎉',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Order ${id.substring(0, 6).toUpperCase()} is confirmed.\n'
            'Track it under My Orders.',
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacementNamed(context, '/orders');
              },
              child: const Text(
                'View orders',
                style: TextStyle(color: AppColors.accent),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Done',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: StreamBuilder<List<CartItemDoc>>(
            stream: CartService.instance.watchCart(),
            builder: (context, snap) {
              final items = snap.data ?? const <CartItemDoc>[];
              final total = _total(items);

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
                          const Expanded(
                            child: Text(
                              'Your cart',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
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
                                  width: 180,
                                  child: GlassButton(
                                    label: 'Back',
                                    variant: GlassButtonVariant.outline,
                                    height: 48,
                                    onPressed: () => Navigator.pop(context),
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
                          blur: 22,
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
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Total',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '\$${_format(total)}',
                                    style: const TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _address,
                                minLines: 2,
                                maxLines: 3,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Shipping address…',
                                  hintStyle: const TextStyle(
                                    color: Colors.white38,
                                  ),
                                  filled: true,
                                  fillColor: Colors.black.withValues(
                                    alpha: 0.35,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color:
                                          Colors.white.withValues(alpha: 0.14),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color:
                                          Colors.white.withValues(alpha: 0.14),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              GlassButton(
                                label: _checkingOut
                                    ? 'Placing order…'
                                    : 'Checkout · \$${_format(total)}',
                                isLoading: _checkingOut,
                                onPressed: _checkingOut
                                    ? null
                                    : () => _checkout(items),
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
      blur: 20,
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [
                  CatalogIcons.colorFromName(item.colorName),
                  CatalogIcons.colorFromName(item.colorName)
                      .withValues(alpha: 0.4),
                ],
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: item.imageUrl?.isNotEmpty == true
                ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                : Center(
                    child: Text(item.emoji, style: const TextStyle(fontSize: 24)),
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
                  item.lineTotalLabel,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  _TinyBtn(icon: Icons.remove_rounded, onTap: onDec),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _TinyBtn(icon: Icons.add_rounded, onTap: onInc),
                ],
              ),
              TextButton(
                onPressed: onRemove,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                ),
                child: const Text(
                  'Remove',
                  style: TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 11.5,
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
