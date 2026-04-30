import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/supabase_config.dart';
import '../../widgets/avatar_widget.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Map<String, dynamic>? _product;
  bool _loading = true;
  int _currentImage = 0;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    try {
      final data = await SupabaseConfig.client
          .from('products').select().eq('id', widget.productId).maybeSingle();
      setState(() { _product = data; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_product == null) return Scaffold(
      appBar: AppBar(title: const Text('Detail Produk')),
      body: const Center(child: Text('Produk tidak ditemukan')));

    final p = _product!;
    final images = (p['images'] as List? ?? []);
    final price = ((p['price'] ?? 0) as num).toDouble();
    final sellerAnon = p['seller_anonymous'] ?? false;
    final sellerName = sellerAnon ? 'Penjual Anonim' : (p['seller_name'] ?? '');
    final sellerPhoto = sellerAnon ? '' : (p['seller_photo'] ?? '');
    final sellerId = p['seller_id']?.toString() ?? '';
    final myUid = context.read<AuthService>().currentUid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        title: const Text('Detail Produk'),
        actions: [
          if (sellerId == myUid)
            PopupMenuButton(
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'sold', child: Text('Tandai Terjual')),
                const PopupMenuItem(value: 'delete', child: Text('Hapus', style: TextStyle(color: Colors.red))),
              ],
              onSelected: (val) async {
                if (val == 'sold') {
                  await SupabaseConfig.client.from('products').update({'status': 'terjual'}).eq('id', widget.productId);
                  setState(() => _product!['status'] = 'terjual');
                } else {
                  await SupabaseConfig.client.from('products').delete().eq('id', widget.productId);
                  if (context.mounted) context.pop();
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (images.isNotEmpty)
              SizedBox(
                height: 300,
                child: PageView.builder(
                  itemCount: images.length,
                  onPageChanged: (i) => setState(() => _currentImage = i),
                  itemBuilder: (_, i) => CachedNetworkImage(imageUrl: images[i].toString(), fit: BoxFit.cover, width: double.infinity),
                ),
              )
            else
              Container(height: 200, color: const Color(0xFFF0F2F1),
                  child: const Center(child: Icon(Icons.image_rounded, size: 64, color: Color(0xFFCCCCCC)))),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p['status'] == 'terjual')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(100)),
                      child: const Text('TERJUAL', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  const SizedBox(height: 8),
                  Text(p['title'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(fmt.format(price), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)),
                  const SizedBox(height: 12),
                  Row(children: [
                    _Chip(label: p['condition'] ?? 'baru', color: AppTheme.primaryGreen),
                    const SizedBox(width: 8),
                    _Chip(label: p['category'] ?? 'lainnya', color: AppTheme.accentAmber),
                  ]),
                  if ((p['location'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF888780)),
                      const SizedBox(width: 4),
                      Text(p['location'], style: const TextStyle(color: Color(0xFF888780))),
                    ]),
                  ],
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Deskripsi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text((p['description'] ?? '').isEmpty ? 'Tidak ada deskripsi' : p['description'],
                      style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF444444))),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Penjual', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(children: [
                    AvatarWidget(name: sellerName, photoUrl: sellerPhoto, size: 44),
                    const SizedBox(width: 12),
                    Text(sellerName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  ]),
                  const SizedBox(height: 24),
                  if (sellerId != myUid && p['status'] != 'terjual')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final chatSvc = context.read<ChatService>();
                          final chatId = await chatSvc.getOrCreateChat(myUid, sellerId);
                          if (context.mounted) context.push('/chat/$chatId', extra: {
                            'name': sellerName, 'photo': sellerPhoto, 'uid': sellerId,
                          });
                        },
                        icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                        label: const Text('Chat dengan Penjual'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
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

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
    child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
  );
}
