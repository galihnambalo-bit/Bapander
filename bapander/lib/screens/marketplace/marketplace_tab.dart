import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../services/auth_service.dart';
import '../../services/marketplace_service.dart';
import '../../models/marketplace_models.dart';
import '../../utils/app_theme.dart';
import '../../widgets/avatar_widget.dart';

class MarketplaceTab extends StatefulWidget {
  const MarketplaceTab({super.key});

  @override
  State<MarketplaceTab> createState() => _MarketplaceTabState();
}

class _MarketplaceTabState extends State<MarketplaceTab> {
  String? _selectedCategory;
  final _searchCtrl = TextEditingController();

  static const _categories = [
    (ProductCategory.elektronik, Icons.devices_rounded, 'Elektronik'),
    (ProductCategory.fashion, Icons.checkroom_rounded, 'Fashion'),
    (ProductCategory.makanan, Icons.restaurant_rounded, 'Makanan'),
    (ProductCategory.kendaraan, Icons.directions_car_rounded, 'Kendaraan'),
    (ProductCategory.properti, Icons.home_rounded, 'Properti'),
    (ProductCategory.jasa, Icons.handyman_rounded, 'Jasa'),
    (ProductCategory.seni, Icons.palette_rounded, 'Seni'),
    (ProductCategory.lainnya, Icons.category_rounded, 'Lainnya'),
  ];

  @override
  Widget build(BuildContext context) {
    final svc = context.read<MarketplaceService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        title: const Text('Toko Bapander'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline_rounded),
            onPressed: () => context.push('/marketplace/saved'),
          ),
          IconButton(
            icon: const Icon(Icons.add_box_rounded),
            onPressed: () => context.push('/marketplace/create'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari produk...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Category filter chips
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _CategoryChip(
                  label: 'Semua',
                  icon: Icons.grid_view_rounded,
                  selected: _selectedCategory == null,
                  onTap: () => setState(() => _selectedCategory = null),
                ),
                ..._categories.map((c) => _CategoryChip(
                      label: c.$3,
                      icon: c.$2,
                      selected: _selectedCategory == c.$1.name,
                      onTap: () => setState(() =>
                          _selectedCategory = _selectedCategory == c.$1
                              ? null
                              : c.$1),
                    )),
              ],
            ),
          ),

          // Products grid
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: svc.productsStream(category: _selectedCategory),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final products = snap.data ?? <Map<String, dynamic>>[];
                if (products.isEmpty) {
                  return _EmptyState(
                    onAdd: () => context.push('/marketplace/create'),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: products.length,
                  itemBuilder: (ctx, i) => _ProductCardMap(product: products[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? AppTheme.primaryGreen : const Color(0xFFDDDDD8),
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14,
                color: selected ? Colors.white : const Color(0xFF888780)),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? Colors.white : const Color(0xFF888780),
                )),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

    return GestureDetector(
      onTap: () => context.push('/marketplace/product/${product.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: AspectRatio(
                aspectRatio: 1,
                child: product.images.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: product.images.first,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: const Color(0xFFF0F2F1),
                          child: const Center(
                              child: Icon(Icons.image_rounded, color: Color(0xFFCCCCCC))),
                        ),
                      )
                    : Container(
                        color: const Color(0xFFF0F2F1),
                        child: Center(
                          child: Icon(
                            _categoryIcon(product.category),
                            size: 40,
                            color: const Color(0xFFCCCCCC),
                          ),
                        ),
                      ),
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fmt.format(product.price),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _conditionColor(product.condition)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _conditionLabel(product.condition),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _conditionColor(product.condition),
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (product.location.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded,
                                  size: 10, color: Colors.grey[400]),
                              Text(
                                product.location.split(',').first,
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[400]),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(ProductCategory cat) {
    switch (cat) {
      case ProductCategory.elektronik: return Icons.devices_rounded;
      case ProductCategory.fashion: return Icons.checkroom_rounded;
      case ProductCategory.makanan: return Icons.restaurant_rounded;
      case ProductCategory.kendaraan: return Icons.directions_car_rounded;
      case ProductCategory.properti: return Icons.home_rounded;
      case ProductCategory.jasa: return Icons.handyman_rounded;
      case ProductCategory.seni: return Icons.palette_rounded;
      default: return Icons.category_rounded;
    }
  }

  Color _conditionColor(ProductCondition cond) {
    switch (cond) {
      case ProductCondition.baru: return AppTheme.primaryGreen;
      case ProductCondition.bekasLayak: return AppTheme.accentAmber;
      case ProductCondition.bekasRusak: return AppTheme.dangerRed;
    }
  }

  String _conditionLabel(ProductCondition cond) {
    switch (cond) {
      case ProductCondition.baru: return 'BARU';
      case ProductCondition.bekasLayak: return 'BEKAS';
      case ProductCondition.bekasRusak: return 'RUSAK';
    }
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storefront_outlined, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('Belum ada produk',
              style: TextStyle(color: Color(0xFF888780), fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Jadilah yang pertama berjualan!',
              style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Jual Sekarang'),
          ),
        ],
      ),
    );
  }
}
