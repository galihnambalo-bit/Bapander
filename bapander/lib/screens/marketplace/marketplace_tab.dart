import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../services/auth_service.dart';
import '../../services/marketplace_service.dart';
import '../../utils/app_theme.dart';

class MarketplaceTab extends StatefulWidget {
  const MarketplaceTab({super.key});
  @override
  State<MarketplaceTab> createState() => _MarketplaceTabState();
}

class _MarketplaceTabState extends State<MarketplaceTab> {
  String? _selectedCategory;

  static const _categories = [
    ('elektronik', Icons.devices_rounded, 'Elektronik'),
    ('fashion', Icons.checkroom_rounded, 'Fashion'),
    ('makanan', Icons.restaurant_rounded, 'Makanan'),
    ('kendaraan', Icons.directions_car_rounded, 'Kendaraan'),
    ('properti', Icons.home_rounded, 'Properti'),
    ('jasa', Icons.handyman_rounded, 'Jasa'),
    ('seni', Icons.palette_rounded, 'Seni'),
    ('lainnya', Icons.category_rounded, 'Lainnya'),
  ];

  @override
  Widget build(BuildContext context) {
    final svc = context.read<MarketplaceService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        title: const Text('Toko Bapander'),
        actions: [
          IconButton(icon: const Icon(Icons.add_box_rounded), onPressed: () => context.push('/marketplace/create')),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari produk...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _CategoryChip(label: 'Semua', icon: Icons.grid_view_rounded,
                    selected: _selectedCategory == null,
                    onTap: () => setState(() => _selectedCategory = null)),
                ..._categories.map((c) => _CategoryChip(
                      label: c.$3, icon: c.$2,
                      selected: _selectedCategory == c.$1,
                      onTap: () => setState(() =>
                          _selectedCategory = _selectedCategory == c.$1 ? null : c.$1),
                    )),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: svc.productsStream(category: _selectedCategory),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final products = snap.data ?? [];
                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.storefront_outlined, size: 72, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text('Belum ada produk', style: TextStyle(color: Color(0xFF888780), fontSize: 16)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/marketplace/create'),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Jual Sekarang'),
                        ),
                      ],
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, childAspectRatio: 0.72,
                    crossAxisSpacing: 10, mainAxisSpacing: 10,
                  ),
                  itemCount: products.length,
                  itemBuilder: (ctx, i) => _ProductCard(product: products[i]),
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

  const _CategoryChip({required this.label, required this.icon, required this.selected, required this.onTap});

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
          border: Border.all(color: selected ? AppTheme.primaryGreen : const Color(0xFFDDDDD8), width: selected ? 1.5 : 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : const Color(0xFF888780)),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? Colors.white : const Color(0xFF888780))),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    final images = (product['images'] as List? ?? []);
    final price = ((product['price'] ?? 0) as num).toDouble();
    final condition = product['condition'] ?? 'baru';
    final location = product['location'] ?? '';
    final productId = product['id']?.toString() ?? '';
    if (productId.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.push('/marketplace/product/$productId'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: AspectRatio(
                aspectRatio: 1,
                child: images.isNotEmpty
                    ? CachedNetworkImage(imageUrl: images.first.toString(), fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: const Color(0xFFF0F2F1)))
                    : Container(color: const Color(0xFFF0F2F1),
                        child: const Center(child: Icon(Icons.image_rounded, color: Color(0xFFCCCCCC)))),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(fmt.format(price),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen)),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _condColor(condition).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(_condLabel(condition),
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _condColor(condition))),
                        ),
                        const Spacer(),
                        if (location.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded, size: 10, color: Colors.grey[400]),
                              Text(location.split(',').first,
                                  style: TextStyle(fontSize: 10, color: Colors.grey[400])),
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

  Color _condColor(String c) {
    if (c == 'baru') return AppTheme.primaryGreen;
    if (c == 'bekasLayak') return AppTheme.accentAmber;
    return AppTheme.dangerRed;
  }

  String _condLabel(String c) {
    if (c == 'baru') return 'BARU';
    if (c == 'bekasLayak') return 'BEKAS';
    return 'RUSAK';
  }
}
