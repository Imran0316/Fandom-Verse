import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/cart_docs.dart';
import '../../services/cart_service.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/liquid_glass.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, this.cartStream});

  /// Test seam — defaults to the live Firestore cart.
  final Stream<List<CartItemDoc>>? cartStream;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _address = TextEditingController();
  final _addressFocus = FocusNode();
  bool _placing = false;
  String _method = 'cod';

  @override
  void dispose() {
    _address.dispose();
    _addressFocus.dispose();
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

  Future<void> _placeOrder(List<CartItemDoc> items) async {
    if (_placing || items.isEmpty) return;
    final address = _address.text.trim();
    if (address.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a full delivery address (at least street + city).'),
        ),
      );
      _addressFocus.requestFocus();
      return;
    }

    setState(() => _placing = true);
    try {
      final id = await CartService.instance.checkout(
        shipTo: address,
        paymentMethod: _method,
      );
      if (!mounted) return;
      final cod = _method == 'cod';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xF2101018),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Order placed',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          content: Text(
            cod
                ? 'Order ${id.substring(0, 6).toUpperCase()} is confirmed.\n\n'
                    'Pay ${_format(_total(items))} in cash when your order arrives.'
                : 'Order ${id.substring(0, 6).toUpperCase()} is confirmed and paid.',
            style: const TextStyle(color: Colors.white70, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacementNamed(context, AppRoutes.orders);
              },
              child: const Text(
                'View orders',
                style: TextStyle(color: AppColors.accent),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.dashboard,
                  (route) => false,
                );
              },
              child: const Text(
                'Continue shopping',
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
      if (mounted) setState(() => _placing = false);
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
            stream: widget.cartStream ?? CartService.instance.watchCart(),
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
                              'Checkout',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Text(
                            'Cart  ›  Checkout  ›  Done',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
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
                                    Icons.receipt_long_rounded,
                                    color: Colors.white,
                                    size: 34,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Nothing to check out',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Add items to your cart first, then come '
                                  'back to place the order.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13.5,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: 200,
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
                    else
                      Expanded(
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          children: [
                            const _SectionLabel('Deliver to'),
                            LiquidGlass(
                              radius: 18,
                              blur: 0,
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
                                      Icon(
                                        Icons.place_outlined,
                                        size: 16,
                                        color: AppColors.accent,
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Shipping address',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _address,
                                    focusNode: _addressFocus,
                                    minLines: 2,
                                    maxLines: 3,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Street, building, city, ZIP code…',
                                      hintStyle: const TextStyle(
                                        color: Colors.white38,
                                      ),
                                      filled: true,
                                      fillColor:
                                          Colors.black.withValues(alpha: 0.35),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: Colors.white
                                              .withValues(alpha: 0.14),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: Colors.white
                                              .withValues(alpha: 0.14),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: AppColors.accent,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Used only to deliver your order.',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            const _SectionLabel('Order summary'),
                            LiquidGlass(
                              radius: 18,
                              blur: 0,
                              padding: const EdgeInsets.all(14),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.1),
                                  Colors.white.withValues(alpha: 0.04),
                                ],
                              ),
                              child: Column(
                                children: [
                                  for (final i in items)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: Row(
                                        children: [
                                          _Thumb(url: i.imageUrl),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              '${i.quantity}× ${i.name}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13.5,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            i.lineTotalLabel,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const Divider(color: Colors.white12, height: 16),
                                  _SummaryRow(
                                    label: 'Subtotal',
                                    value: '\$${_format(total)}',
                                  ),
                                  const SizedBox(height: 6),
                                  const _SummaryRow(
                                    label: 'Delivery',
                                    value: 'Free',
                                    valueColor: Color(0xFF10B981),
                                  ),
                                  const SizedBox(height: 10),
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
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            const _SectionLabel('Payment method'),
                            LiquidGlass(
                              radius: 18,
                              blur: 0,
                              padding: const EdgeInsets.all(8),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.1),
                                  Colors.white.withValues(alpha: 0.04),
                                ],
                              ),
                              child: Column(
                                children: [
                                  _PayTile(
                                    icon: Icons.payments_outlined,
                                    title: 'Cash on Delivery',
                                    subtitle:
                                        'Pay in cash when your order arrives',
                                    selected: _method == 'cod',
                                    enabled: true,
                                    onTap: () =>
                                        setState(() => _method = 'cod'),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Divider(
                                      color: Colors.white
                                          .withValues(alpha: 0.08),
                                      height: 4,
                                    ),
                                  ),
                                  _PayTile(
                                    icon: Icons.credit_card_rounded,
                                    title: 'Card payment',
                                    subtitle: 'Coming soon',
                                    selected: _method == 'card',
                                    enabled: false,
                                    onTap: () =>
                                        setState(() => _method = 'card'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            LiquidGlass(
                              radius: 14,
                              blur: 16,
                              padding: const EdgeInsets.all(12),
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.accent.withValues(alpha: 0.12),
                                  Colors.white.withValues(alpha: 0.03),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _method == 'cod'
                                        ? Icons.delivery_dining_rounded
                                        : Icons.lock_outline_rounded,
                                    size: 18,
                                    color: AppColors.accent,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _method == 'cod'
                                          ? 'No online payment needed — keep '
                                              'the exact amount ready and pay '
                                              'the courier on delivery.'
                                          : 'Your card will be charged when '
                                              'the order is placed.',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12.5,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (items.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: GlassButton(
                          label: _placing
                              ? 'Placing order…'
                              : 'Place order · \$${_format(total)}',
                          isLoading: _placing,
                          onPressed:
                              _placing ? null : () => _placeOrder(items),
                        ),
                      ),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
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

class _Thumb extends StatelessWidget {
  const _Thumb({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      clipBehavior: Clip.antiAlias,
      child: url?.isNotEmpty == true
          ? Image.network(
              url!,
              fit: BoxFit.cover,
              width: 34,
              height: 34,
              errorBuilder: (_, _, _) => const Center(
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.white24,
                  size: 16,
                ),
              ),
            )
          : const Center(
              child: Icon(
                Icons.inventory_2_outlined,
                color: Colors.white24,
                size: 16,
              ),
            ),
    );
  }
}

class _PayTile extends StatelessWidget {
  const _PayTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? AppColors.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: enabled ? Colors.white : Colors.white24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: enabled ? Colors.white : Colors.white38,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: enabled ? Colors.white54 : Colors.white24,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            if (enabled)
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? AppColors.accent : Colors.white38,
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                child: const Text(
                  'Soon',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return content;
  }
}
