import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/catalog_docs.dart';
import '../../services/cart_service.dart';
import '../../services/catalog_service.dart';
import '../../widgets/liquid_glass.dart';

enum MerchExploreSort {
  topSales('Top sales'),
  recentlyAdded('Recently added'),
  priceHighLow('Price: High to low'),
  priceLowHigh('Price: Low to high');

  const MerchExploreSort(this.label);
  final String label;
}

class MerchExploreScreen extends StatefulWidget {
  const MerchExploreScreen({super.key});

  @override
  State<MerchExploreScreen> createState() => _MerchExploreScreenState();
}

class _MerchExploreScreenState extends State<MerchExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  MerchExploreSort _sort = MerchExploreSort.topSales;

  static double _parsedPrice(MerchProductDoc product) {
    final digits = product.priceLabel.replaceAll(RegExp(r'[^0-9.]'), '');
    final value = double.tryParse(digits);
    return value ?? 0;
  }

  static DateTime _createdAt(MerchProductDoc product) =>
      product.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  List<MerchProductDoc> _applyFilters(List<MerchProductDoc> source) {
    final query = _searchController.text.trim().toLowerCase();
    final items = source.where((product) {
      if (query.isEmpty) return true;
      final haystack = [
        product.name,
        product.description,
        product.sellerName,
        product.emoji,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    switch (_sort) {
      case MerchExploreSort.topSales:
        items.sort((a, b) {
          final priceCompare = _parsedPrice(b).compareTo(_parsedPrice(a));
          if (priceCompare != 0) return priceCompare;
          return _createdAt(b).compareTo(_createdAt(a));
        });
        break;
      case MerchExploreSort.recentlyAdded:
        items.sort((a, b) => _createdAt(b).compareTo(_createdAt(a)));
        break;
      case MerchExploreSort.priceHighLow:
        items.sort((a, b) => _parsedPrice(b).compareTo(_parsedPrice(a)));
        break;
      case MerchExploreSort.priceLowHigh:
        items.sort((a, b) => _parsedPrice(a).compareTo(_parsedPrice(b)));
        break;
    }

    return items;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: StreamBuilder<List<MerchProductDoc>>(
                stream: CatalogService.instance.watchMerch(),
                builder: (context, snapshot) {
                  final items = _applyFilters(snapshot.data ?? const []);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                          Expanded(
                            child: Text(
                              'Merch Store',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          // Header actions: Save and Add to cart
                          IconButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Save action')),
                              );
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.02),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.bookmark_border_rounded),
                          ),
                          IconButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Add to cart action')),
                              );
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.02),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.shopping_cart_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: LiquidGlass(
                          radius: 22,
                          blur: 18,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                            cursorColor: AppColors.accent,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              hintText: 'Search merch, sellers, styles…',
                              hintStyle: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              suffixIcon: _searchController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        color: AppColors.textSecondary,
                                        size: 18,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 42,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: MerchExploreSort.values.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final option = MerchExploreSort.values[index];
                            final selected = option == _sort;
                            return GestureDetector(
                              onTap: () => setState(() => _sort = option),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primary.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.accent.withValues(alpha: 0.6)
                                        : Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Text(
                                  option.label,
                                  style: TextStyle(
                                    color: selected ? Colors.white : Colors.white70,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: items.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.search_off_rounded,
                                      color: Colors.white54,
                                      size: 34,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'No merch found',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Try a different keyword or clear the search.',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : GridView.builder(
                                padding: EdgeInsets.zero,
                                physics: const BouncingScrollPhysics(),
                                itemCount: items.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.74,
                                ),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return MerchExploreCard(item: item);
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MerchExploreCard extends StatefulWidget {
  const MerchExploreCard({required this.item, super.key});

  final MerchProductDoc item;

  @override
  State<MerchExploreCard> createState() => _MerchExploreCardState();
}

class _MerchExploreCardState extends State<MerchExploreCard> {

  int get _stockLeft {
    final seed = widget.item.id.hashCode + widget.item.name.length;
    return 2 + (seed.abs() % 12);
  }

  int get _reviewCount {
    final seed = widget.item.sellerName.length + widget.item.name.length;
    return 18 + (seed % 120);
  }

  // addToCart handled via header action; keep implementation for manual calls.
  Future<void> _addToCart() async {
    try {
      await CartService.instance.addToCart(widget.item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.item.name} added to cart')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add to cart: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.item.color;
    final seller = widget.item.sellerName.isNotEmpty
        ? widget.item.sellerName
        : 'Qasim Studio';

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.product,
        arguments: widget.item,
      ),
      child: LiquidGlass(
        radius: 22,
        blur: 22,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        borderColor: Colors.white.withValues(alpha: 0.14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.7),
                      color.withValues(alpha: 0.25),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Center(
                  child: widget.item.imageUrl?.isNotEmpty == true
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            widget.item.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, _, _) => Text(
                              widget.item.emoji,
                              style: const TextStyle(fontSize: 42),
                            ),
                          ),
                        )
                      : Text(
                          widget.item.emoji,
                          style: const TextStyle(fontSize: 42),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Sold by $seller',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Only $_stockLeft left',
                    style: const TextStyle(
                      color: Color(0xFFFFD166),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        widget.item.priceLabel,
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFFD166),
                              size: 13,
                            ),
                            const SizedBox(width: 3),
                            const Text(
                              '4.8',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const SizedBox.shrink(),
                  const SizedBox(height: 8),
                  Text(
                    '$_reviewCount reviews',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
