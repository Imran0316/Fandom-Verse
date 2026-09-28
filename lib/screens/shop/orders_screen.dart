import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/cart_docs.dart';
import '../../services/cart_service.dart';
import '../../widgets/liquid_glass.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: StreamBuilder<List<OrderDoc>>(
            stream: CartService.instance.watchMyOrders(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  snap.data == null) {
                return const Scaffold(
                  backgroundColor: AppColors.backgroundDeep,
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final orders = snap.data ?? const <OrderDoc>[];

              return SafeArea(
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
                              'My Orders',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.receipt_long_rounded,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                    if (orders.isEmpty)
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
                                    Icons.inventory_2_outlined,
                                    color: Colors.white,
                                    size: 34,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No orders yet',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Checkout from your cart to see orders here.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          key: const PageStorageKey<String>('orders_list'),
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: orders.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, i) =>
                              _OrderCard(order: orders[i]),
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

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderDoc order;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (order.status) {
      OrderStatus.paid => const Color(0xFF10B981),
      OrderStatus.shipped => const Color(0xFF3B82F6),
      OrderStatus.delivered => AppColors.accent,
      OrderStatus.cancelled => const Color(0xFFFF6B6B),
      OrderStatus.pending => Colors.amber,
    };

    return LiquidGlass(
      radius: 18,
      blur: 0,
      padding: const EdgeInsets.all(16),
      gradient: LinearGradient(
        colors: [
          statusColor.withValues(alpha: 0.14),
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
                  'Order ${order.id.substring(0, 6).toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: statusColor.withValues(alpha: 0.2),
                  border: Border.all(color: statusColor.withValues(alpha: 0.55)),
                ),
                child: Text(
                  order.statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...order.items.map(
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: i.imageUrl?.isNotEmpty == true
                        ? Image.network(
                            i.imageUrl!,
                            fit: BoxFit.cover,
                            width: 24,
                            height: 24,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(
                                Icons.inventory_2_outlined,
                                size: 14,
                                color: Colors.white24,
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.inventory_2_outlined,
                              size: 14,
                              color: Colors.white24,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${i.quantity}× ${i.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    i.lineTotalLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 18),
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 14, color: Colors.white38),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  order.shipTo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              Text(
                order.totalLabel,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.payments_outlined,
                size: 13,
                color: Colors.white38,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  order.paymentMethodLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (order.paymentNote.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              order.paymentNote,
              style: TextStyle(
                color: order.paymentMethod == 'cod' &&
                        order.status != OrderStatus.delivered &&
                        order.status != OrderStatus.paid
                    ? const Color(0xFFFFD166)
                    : Colors.white38,
                fontSize: 11,
              ),
            ),
          ],
          if (order.createdAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Placed ${order.createdAt!.month}/${order.createdAt!.day}/${order.createdAt!.year}',
              style: const TextStyle(color: Colors.white38, fontSize: 11.5),
            ),
          ],
          if (order.status == OrderStatus.pending) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _confirmCancel(context),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Cancel order'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF6B6B),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xF2101018),
        title: const Text(
          'Cancel order?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Order ${order.id.substring(0, 6).toUpperCase()} will be '
          'cancelled. This cannot be undone.',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cancel order',
              style: TextStyle(color: Color(0xFFFF6B6B)),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await CartService.instance.cancelOrder(order.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order cancelled.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
