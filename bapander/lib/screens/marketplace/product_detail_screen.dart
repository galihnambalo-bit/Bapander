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
          .from('products')
          .select()
          .eq('id', widget.productId)
          .maybeSingle();
      setState(() { _product = data; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _chatWithSeller() async {
    final p = _product!;
    final auth = context.read<AuthService>();
    final chatSvc = context.read<ChatService>();
    final myUid = auth.currentUid ?? '';
    final sellerId = p['seller_id']?.toString() ?? '';
    final sellerName = p['seller_name'] ?? '';
    final sellerPhoto = p['seller_photo'] ?? '';
    final fmt = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    final price = ((p['price'] ?? 0) as num).toDouble();

    final chatId = await chatSvc.getOrCreateChat(myUid, sellerId);

    // Kirim pesan detail produk otomatis
    await chatSvc.sendMessage(
      chatId: chatId,
      senderId: myUid,
      text: '🛍️ Halo, saya tertarik dengan produk ini:\n\n'
          '📦 *${p['title']}*\n'
          '💰 Harga: ${fmt.format(price)}\n'
          '📍 Lokasi: ${p['location'] ?? '-'}\n'
          '🏷️ Kondisi: ${p['condition'] ?? '-'}\n\n'
          'Apakah masih tersedia?',
      type: 'text',
    );

    if (context.mounted) {
      context.push('/chat/$chatId', extra: {
        'name': sellerName,
        'photo': sellerPhoto,
        'uid': sellerId,
      });
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
    final sellerName = p['seller_name'] ?? '';
    final sellerPhoto = p['seller_photo'] ?? '';
    final sellerId = p['seller_id']?.toString() ?? '';
    final myUid = context.read<AuthService>().currentUid ?? '';
    final isOwner = sellerId == myUid;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        title: const Text('Detail Produk'),
        actions: [
          if (isOwner)
            PopupMenuButton(
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'sold', child: Text('Tandai Terjual')),
                const PopupMenuItem(value: 'delete',
                  child: Text('Hapus', style: TextStyle(color: Colors.red))),
              ],
              onSelected: (val) async {
                if (val == 'sold') {
                  await SupabaseConfig.client.from('products')
                      .update({'status': 'terjual'}).eq('id', widget.productId);
                  setState(() => _product!['status'] = 'terjual');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Produk ditandai terjual ✅'),
                      backgroundColor: AppTheme.primaryBlue));
                } else {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Hapus Produk?'),
                      content: const Text('Produk akan dihapus permanen'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false),
                          child: const Text('Batal')),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Hapus')),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await SupabaseConfig.client.from('products')
                        .delete().eq('id', widget.productId);
                    if (context.mounted) context.pop();
                  }
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── FOTO ─────────────────────────────────────
                  if (images.isNotEmpty) ...[
                    SizedBox(
                      height: 300,
                      child: PageView.builder(
                        itemCount: images.length,
                        onPageChanged: (i) => setState(() => _currentImage = i),
                        itemBuilder: (_, i) => CachedNetworkImage(
                          imageUrl: images[i].toString(),
                          fit: BoxFit.cover, width: double.infinity,
                          placeholder: (_, __) => Container(color: const Color(0xFFF0F2F1)),
                        ),
                      ),
                    ),
                    if (images.length > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(images.length, (i) => Container(
                            width: 8, height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImage == i
                                  ? AppTheme.primaryBlue : Colors.grey[300],
                            ),
                          )),
                        ),
                      ),
                  ] else
                    Container(
                      height: 250, color: const Color(0xFFF0F2F1),
                      child: const Center(
                        child: Icon(Icons.image_rounded, size: 80, color: Color(0xFFCCCCCC)))),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status
                        if (p['status'] == 'terjual')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(100)),
                            child: const Text('TERJUAL',
                              style: TextStyle(color: Colors.red,
                                fontWeight: FontWeight.w700, fontSize: 12)),
                          ),

                        // Judul
                        Text(p['title'] ?? '',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),

                        // Harga
                        Text(fmt.format(price),
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                            color: AppTheme.primaryBlue)),
                        const SizedBox(height: 12),

                        // Chips
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: [
                            _Chip(label: p['condition'] ?? 'baru', color: AppTheme.primaryBlue,
                              icon: Icons.star_rounded),
                            _Chip(label: p['category'] ?? 'lainnya', color: AppTheme.accentAmber,
                              icon: Icons.category_rounded),
                            if ((p['location'] ?? '').isNotEmpty)
                              _Chip(label: p['location'], color: Colors.blue,
                                icon: Icons.location_on_rounded),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Deskripsi
                        const Text('Deskripsi',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            (p['description'] ?? '').isEmpty
                                ? 'Tidak ada deskripsi'
                                : p['description'],
                            style: const TextStyle(fontSize: 14, height: 1.6,
                              color: Color(0xFF444444)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Penjual
                        const Text('Penjual',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => context.push('/user/$sellerId'),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                AvatarWidget(name: sellerName, photoUrl: sellerPhoto, size: 48),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(sellerName,
                                        style: const TextStyle(fontSize: 15,
                                          fontWeight: FontWeight.w600)),
                                      const Text('Ketuk untuk lihat profil',
                                        style: TextStyle(fontSize: 12,
                                          color: Color(0xFF888780))),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded,
                                  color: Color(0xFFCCCCCC)),
                              ],
                            ),
                          ),
                        ),
                        if (!isOwner && p['status'] != 'terjual') ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _chatWithSeller,
                              icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                              label: const Text('Hubungi Penjual', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                backgroundColor: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── TOMBOL BAWAH ──────────────────────────────────
          if (!isOwner && p['status'] != 'terjual')
            Container(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 12,
                bottom: MediaQuery.of(context).padding.bottom + 12,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08),
                  blurRadius: 10, offset: const Offset(0, -2))],
              ),
              child: Row(
                children: [
                  // Simpan
                  GestureDetector(
                    onTap: () async {
                      final auth = context.read<AuthService>();
                      final myUid = auth.currentUid ?? '';
                      final savedBy = List<String>.from(p['saved_by'] ?? []);
                      if (savedBy.contains(myUid)) {
                        savedBy.remove(myUid);
                      } else {
                        savedBy.add(myUid);
                      }
                      await SupabaseConfig.client.from('products')
                          .update({'saved_by': savedBy}).eq('id', widget.productId);
                      setState(() => _product!['saved_by'] = savedBy);
                    },
                    child: Container(
                      width: 52, height: 52,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F8F7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDDDDD8)),
                      ),
                      child: Icon(
                        List<String>.from(p['saved_by'] ?? []).contains(myUid)
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),

                  // Tawar / Chat
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _chatWithSeller,
                      icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                      label: const Text('Tawar / Chat Penjual',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _Chip({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12,
            fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
