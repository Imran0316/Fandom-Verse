import 'package:cloud_firestore/cloud_firestore.dart';

class CartItemDoc {
  const CartItemDoc({
    required this.productId,
    required this.name,
    required this.priceLabel,
    required this.priceCents,
    required this.quantity,
    this.sellerUid = '',
    this.sellerName = '',
    this.emoji = '✨',
    this.colorName = 'red',
    this.imageUrl,
    this.addedAt,
  });

  final String productId;
  final String name;
  final String priceLabel;
  final int priceCents;
  final int quantity;
  final String sellerUid;
  final String sellerName;
  final String emoji;
  final String colorName;
  final String? imageUrl;
  final DateTime? addedAt;

  int get lineTotalCents => priceCents * quantity;

  String get lineTotalLabel => _formatCents(lineTotalCents);

  factory CartItemDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final added = data['addedAt'];
    return CartItemDoc(
      productId: doc.id,
      name: (data['name'] as String?) ?? '',
      priceLabel: (data['priceLabel'] as String?) ?? r'$0',
      priceCents: (data['priceCents'] as num?)?.toInt() ?? 0,
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      sellerUid: (data['sellerUid'] as String?) ?? '',
      sellerName: (data['sellerName'] as String?) ?? '',
      emoji: (data['emoji'] as String?) ?? '✨',
      colorName: (data['colorName'] as String?) ?? 'red',
      imageUrl: data['imageUrl'] as String?,
      addedAt: added is Timestamp ? added.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'priceLabel': priceLabel,
        'priceCents': priceCents,
        'quantity': quantity,
        'sellerUid': sellerUid,
        'sellerName': sellerName,
        'emoji': emoji,
        'colorName': colorName,
        'imageUrl': imageUrl,
        'addedAt': FieldValue.serverTimestamp(),
      };
}

enum OrderStatus { pending, paid, shipped, delivered, cancelled }

class OrderDoc {
  const OrderDoc({
    required this.id,
    required this.buyerUid,
    this.buyerName = '',
    this.items = const [],
    this.totalCents = 0,
    this.status = OrderStatus.pending,
    this.shipTo = '',
    this.paymentMethod = 'cod',
    this.createdAt,
    this.paidAt,
  });

  final String id;
  final String buyerUid;
  final String buyerName;
  final List<CartItemDoc> items;
  final int totalCents;
  final OrderStatus status;
  final String shipTo;

  /// 'cod' (Cash on Delivery) or 'card'.
  final String paymentMethod;
  final DateTime? createdAt;
  final DateTime? paidAt;

  String get totalLabel => _formatCents(totalCents);

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case 'card':
        return 'Card payment';
      case 'cod':
        return 'Cash on Delivery';
      default:
        return '—';
    }
  }

  String get paymentNote {
    switch (paymentMethod) {
      case 'cod':
        return status == OrderStatus.delivered || status == OrderStatus.paid
            ? 'Paid in cash'
            : 'Pay in cash when your order arrives';
      case 'card':
        return 'Paid online';
      default:
        return '';
    }
  }

  String get statusLabel {
    switch (status) {
      case OrderStatus.paid:
        return 'Paid';
      case OrderStatus.shipped:
        return 'Shipped';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.pending:
        return 'Pending';
    }
  }

  factory OrderDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final created = data['createdAt'];
    final paid = data['paidAt'];
    final rawItems = (data['items'] as List?) ?? const [];
    return OrderDoc(
      id: doc.id,
      buyerUid: (data['buyerUid'] as String?) ?? '',
      buyerName: (data['buyerName'] as String?) ?? '',
      items: rawItems
          .whereType<Map>()
          .map(
            (m) => CartItemDoc(
              productId: (m['productId'] as String?) ?? '',
              name: (m['name'] as String?) ?? '',
              priceLabel: (m['priceLabel'] as String?) ?? r'$0',
              priceCents: (m['priceCents'] as num?)?.toInt() ?? 0,
              quantity: (m['quantity'] as num?)?.toInt() ?? 1,
              sellerUid: (m['sellerUid'] as String?) ?? '',
              sellerName: (m['sellerName'] as String?) ?? '',
              emoji: (m['emoji'] as String?) ?? '✨',
              colorName: (m['colorName'] as String?) ?? 'red',
              imageUrl: m['imageUrl'] as String?,
            ),
          )
          .toList(),
      totalCents: (data['totalCents'] as num?)?.toInt() ?? 0,
      status: _statusFrom(data['status'] as String?),
      shipTo: (data['shipTo'] as String?) ?? '',
      paymentMethod: (data['paymentMethod'] as String?) ?? 'cod',
      createdAt: created is Timestamp ? created.toDate() : null,
      paidAt: paid is Timestamp ? paid.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'buyerUid': buyerUid,
        'buyerName': buyerName,
        'items': items
            .map(
              (i) => {
                'productId': i.productId,
                'name': i.name,
                'priceLabel': i.priceLabel,
                'priceCents': i.priceCents,
                'quantity': i.quantity,
                'sellerUid': i.sellerUid,
                'sellerName': i.sellerName,
                'emoji': i.emoji,
                'colorName': i.colorName,
                'imageUrl': i.imageUrl,
              },
            )
            .toList(),
      'totalCents': totalCents,
      'status': status.name,
      'shipTo': shipTo,
      'paymentMethod': paymentMethod,
      'createdAt': FieldValue.serverTimestamp(),
        'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      };

  static OrderStatus _statusFrom(String? raw) {
    switch (raw) {
      case 'paid':
        return OrderStatus.paid;
      case 'shipped':
        return OrderStatus.shipped;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }
}

/// Parse `'$29'`, `'29'`, `'$29.99'` → cents.
int parsePriceToCents(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) return 0;
  final value = double.tryParse(cleaned);
  if (value == null || value.isNaN) return 0;
  return (value * 100).round();
}

String _formatCents(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  final dollars = abs ~/ 100;
  final rem = abs % 100;
  if (rem == 0) return '$sign\$$dollars';
  return '$sign\$$dollars.${rem.toString().padLeft(2, '0')}';
}
