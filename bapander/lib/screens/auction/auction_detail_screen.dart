import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/auction_service.dart';
import '../../services/chat_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/supabase_config.dart';
import '../../widgets/avatar_widget.dart';

class AuctionDetailScreen extends StatefulWidget {
  final String auctionId;
  const AuctionDetailScreen({super.key, required this.auctionId});
  @override
  State<AuctionDetailScreen> createState() => _AuctionDetailScreenState();
}

class _AuctionDetailScreenState extends State<AuctionDetailScreen> {
  final _bidCtrl = TextEditingController();
  bool _isBidding = false;
  int _currentImage = 0;
  Duration _timeLeft = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bidCtrl.dispose();
    super.dispose();
  }

  Duration _getTimeLeft(Map<String, dynamic> a) {
    final endTime = DateTime.tryParse(a['end_time']?.toString() ?? '');
    if (endTime == null) return Duration.zero;
    final diff = endTime.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 0) return '${d.inDays}h ${d.inHours % 24}j ${d.inMinutes % 60}m';
    if (d.inHours > 0) return '${d.inHours}j ${d.inMinutes % 60}m ${d.inSeconds % 60}d';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}d';
    return '${d.inSeconds}d';
  }

  Color _timerColor(Duration d) {
    if (d.inHours < 1) return Colors.red;
    if (d.inHours < 6) return AppTheme.accentAmber;
    return AppTheme.primaryGreen;
  }

  Future<void> _placeBid(Map<String, dynamic> a) async {
    final bidAmount = double.tryParse(_bidCtrl.text.replaceAll('.', '').replaceAll(',', ''));
    if (bidAmount == null) {
      _showSnack('Masukkan jumlah tawaran yang valid', isSuccess: false);
      return;
    }

    final currentPrice = ((a['current_price'] ?? 0) as num).toDouble();
    final minIncrement = ((a['min_bid_increment'] ?? 1000) as num).toDouble();
    final minBid = currentPrice + minIncrement;

    if (bidAmount < minBid) {
      final fmt = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
      _showSnack('Tawaran minimal ${fmt.format(minBid)}', isSuccess: false);
      return;
    }

    setState(() => _isBidding = true);
    final auth = context.read<AuthService>();
    final svc = context.read<AuctionService>();
    final userData = await auth.getUserData(auth.currentUid ?? '');

    final result = await svc.placeBid(
      auctionId: widget.auctionId,
      bidderId: auth.currentUid ?? '',
      bidderName: userData?['name'] ?? 'Penawar',
      bidderAnonymous: true, // Semua penawar anonim selama lelang
      bidAmount: bidAmount,
    );

    setState(() => _isBidding = false);
    _bidCtrl.clear();

    if (result == 'success') {
      _showSnack('Tawaran berhasil! 🎉', isSuccess: true);
    } else if (result == 'tooLow') {
      _showSnack('Tawaran terlalu rendah!', isSuccess: false);
    } else if (result == 'ownAuction') {
      _showSnack('Tidak bisa menawar lelang sendiri!', isSuccess: false);
    } else {
      _showSnack('Gagal menawar. Coba lagi.', isSuccess: false);
    }
  }

  // Tetapkan pemenang dan buka chat
  Future<void> _declareWinner(Map<String, dynamic> a) async {
    final winnerId = a['highest_bidder_id']?.toString() ?? '';
    if (winnerId.isEmpty) {
      _showSnack('Belum ada penawar!', isSuccess: false);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tetapkan Pemenang?'),
        content: const Text(
          'Pemenang lelang akan diumumkan dan bisa menghubungi kamu langsung. '
          'Identitas pemenang akan terungkap ke kamu, dan identitas kamu terungkap ke pemenang.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            child: const Text('Ya, Tetapkan Pemenang'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Update auction status ke selesai dan reveal identitas
    await SupabaseConfig.client.from('auctions').update({
      'status': 'selesai',
      'winner_revealed': true,
    }).eq('id', widget.auctionId);

    // Buka chat antara penjual dan pemenang
    final auth = context.read<AuthService>();
    final chatSvc = context.read<ChatService>();
    final myUid = auth.currentUid ?? '';
    final fmt = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    final winnerPrice = ((a['current_price'] ?? 0) as num).toDouble();

    // Ambil data pemenang yang asli (bukan anonim)
    final winnerData = await auth.getUserData(winnerId);
    final winnerName = winnerData?['name'] ?? 'Pemenang';
    final winnerPhoto = winnerData?['photo'] ?? '';

    final chatId = await chatSvc.getOrCreateChat(myUid, winnerId);

    // Kirim pesan selamat otomatis
    await chatSvc.sendMessage(
      chatId: chatId,
      senderId: myUid,
      text: '🎉 Selamat! Kamu memenangkan lelang!\n\n'
          '🏆 Produk: *${a['title']}*\n'
          '💰 Harga menang: ${fmt.format(winnerPrice)}\n\n'
          'Silakan hubungi saya untuk proses pembayaran dan pengiriman.',
      type: 'text',
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pemenang ditetapkan! Chat dibuka 🎉'),
          backgroundColor: AppTheme.primaryGreen));

      // Navigasi ke chat dengan pemenang
      context.push('/chat/$chatId', extra: {
        'name': winnerName,
        'photo': winnerPhoto,
        'uid': winnerId,
      });
    }
  }

  void _showSnack(String msg, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isSuccess ? AppTheme.primaryGreen : Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final svc = context.read<AuctionService>();
    final myUid = auth.currentUid ?? '';
    final fmt = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(title: const Text('Detail Lelang')),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: svc.auctionStream(widget.auctionId),
        builder: (ctx, snap) {
          if (!snap.hasData || snap.data!.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final a = snap.data!;
          final images = (a['images'] as List? ?? []);
          final currentPrice = ((a['current_price'] ?? 0) as num).toDouble();
          final minIncrement = ((a['min_bid_increment'] ?? 1000) as num).toDouble();
          final buyNowPrice = (a['buy_now_price'] as num?)?.toDouble();
          final timeLeft = _getTimeLeft(a);
          final isActive = a['status'] == 'berlangsung' && timeLeft > Duration.zero;
          final isOwner = a['seller_id']?.toString() == myUid;
          final isBerlangsung = a['status'] == 'berlangsung';
          final isSelesai = a['status'] == 'selesai';
          final highestBidderId = a['highest_bidder_id']?.toString() ?? '';
          final isWinner = highestBidderId == myUid && isSelesai;
          final winnerRevealed = a['winner_revealed'] ?? false;

          // Nama penawar - anonim selama lelang
          final highestBidderName = (isSelesai && winnerRevealed)
              ? (a['highest_bidder_name'] ?? 'Pemenang')
              : 'Penawar Anonim';

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── FOTO ───────────────────────────────
                      Stack(
                        children: [
                          SizedBox(
                            height: 280,
                            child: images.isNotEmpty
                                ? PageView.builder(
                                    itemCount: images.length,
                                    onPageChanged: (i) => setState(() => _currentImage = i),
                                    itemBuilder: (_, i) => CachedNetworkImage(
                                      imageUrl: images[i].toString(),
                                      fit: BoxFit.cover, width: double.infinity,
                                    ),
                                  )
                                : Container(color: const Color(0xFFF0F2F1),
                                    child: const Center(
                                      child: Icon(Icons.gavel_rounded, size: 80,
                                        color: Color(0xFFCCCCCC)))),
                          ),
                          // Timer badge
                          Positioned(
                            top: 12, right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _timerColor(timeLeft),
                                borderRadius: BorderRadius.circular(100)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.timer_rounded, color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    isActive ? _formatDuration(timeLeft) : 'Berakhir',
                                    style: const TextStyle(color: Colors.white,
                                      fontSize: 12, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                          // Status badge
                          if (!isBerlangsung)
                            Positioned(
                              top: 12, left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelesai ? AppTheme.primaryGreen : Colors.grey,
                                  borderRadius: BorderRadius.circular(100)),
                                child: Text(
                                  isSelesai ? 'SELESAI' : a['status']?.toString().toUpperCase() ?? '',
                                  style: const TextStyle(color: Colors.white,
                                    fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                            ),
                        ],
                      ),

                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Judul
                            Text(a['title'] ?? '',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),

                            // Harga card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Harga Saat Ini',
                                              style: TextStyle(fontSize: 12, color: Color(0xFF888780))),
                                            Text(fmt.format(currentPrice),
                                              style: const TextStyle(fontSize: 22,
                                                fontWeight: FontWeight.w800,
                                                color: AppTheme.primaryGreen)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('${a['total_bids'] ?? 0} tawaran',
                                            style: const TextStyle(fontSize: 13,
                                              color: Color(0xFF888780))),
                                          if (highestBidderId.isNotEmpty)
                                            Text(
                                              isSelesai && winnerRevealed
                                                  ? '🏆 $highestBidderName'
                                                  : '👤 $highestBidderName',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isSelesai
                                                    ? AppTheme.primaryGreen
                                                    : const Color(0xFF888780),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (buyNowPrice != null) ...[
                                    const Divider(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Harga Beli Langsung',
                                          style: TextStyle(fontSize: 13,
                                            color: AppTheme.accentAmber)),
                                        Text(fmt.format(buyNowPrice),
                                          style: const TextStyle(fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.accentAmber)),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Info minimal bid
                            if (isActive && !isOwner)
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded,
                                      size: 16, color: AppTheme.primaryGreen),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Min. tawaran: ${fmt.format(currentPrice + minIncrement)}',
                                      style: const TextStyle(fontSize: 13,
                                        color: AppTheme.primaryGreen)),
                                  ],
                                ),
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
                                borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                (a['description'] ?? '').isEmpty
                                    ? 'Tidak ada deskripsi'
                                    : a['description'],
                                style: const TextStyle(fontSize: 14, height: 1.6,
                                  color: Color(0xFF444444))),
                            ),
                            const SizedBox(height: 16),

                            // Penjual - anonim selama lelang aktif
                            const Text('Penjual',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48, height: 48,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.person_rounded,
                                      color: AppTheme.primaryGreen, size: 26),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isSelesai && winnerRevealed
                                              ? (a['seller_name'] ?? 'Penjual')
                                              : 'Penjual Anonim',
                                          style: const TextStyle(fontSize: 15,
                                            fontWeight: FontWeight.w600)),
                                        Text(
                                          isSelesai && winnerRevealed
                                              ? 'Identitas terungkap setelah deal'
                                              : '🔒 Identitas tersembunyi selama lelang',
                                          style: const TextStyle(fontSize: 12,
                                            color: Color(0xFF888780))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Riwayat tawaran
                            const Text('Riwayat Tawaran',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            StreamBuilder<List<Map<String, dynamic>>>(
                              stream: svc.bidsStream(widget.auctionId),
                              builder: (ctx, bidSnap) {
                                final bids = bidSnap.data ?? [];
                                if (bids.isEmpty) return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12)),
                                  child: const Center(
                                    child: Text('Belum ada tawaran',
                                      style: TextStyle(color: Color(0xFF888780)))));

                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12)),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: bids.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (ctx, i) {
                                      final bid = bids[i] as Map<String, dynamic>;
                                      final amount = ((bid['amount'] ?? 0) as num).toDouble();
                                      final isTopBid = i == 0;
                                      // Semua anonim selama lelang, reveal kalau selesai
                                      final bidderName = (isSelesai && winnerRevealed && isTopBid)
                                          ? (bid['bidder_name'] ?? 'Penawar')
                                          : 'Penawar Anonim';
                                      return ListTile(
                                        leading: Container(
                                          width: 36, height: 36,
                                          decoration: BoxDecoration(
                                            color: isTopBid
                                                ? AppTheme.primaryBg
                                                : const Color(0xFFF0F2F1),
                                            shape: BoxShape.circle),
                                          child: Icon(
                                            isTopBid
                                                ? Icons.emoji_events_rounded
                                                : Icons.person_outline_rounded,
                                            size: 18,
                                            color: isTopBid
                                                ? AppTheme.primaryGreen
                                                : const Color(0xFF888780)),
                                        ),
                                        title: Text(bidderName,
                                          style: TextStyle(
                                            fontWeight: isTopBid
                                                ? FontWeight.w700 : FontWeight.normal,
                                            fontSize: 14)),
                                        trailing: Text(fmt.format(amount),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: isTopBid
                                                ? AppTheme.primaryGreen
                                                : const Color(0xFF444444),
                                            fontSize: 14)),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── TOMBOL BAWAH ─────────────────────────────────
              Container(
                padding: EdgeInsets.only(
                  left: 16, right: 16, top: 12,
                  bottom: MediaQuery.of(context).padding.bottom + 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10, offset: const Offset(0, -2))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Owner - tombol tetapkan pemenang
                    if (isOwner && highestBidderId.isNotEmpty && !isSelesai)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _declareWinner(a),
                          icon: const Icon(Icons.emoji_events_rounded, size: 18),
                          label: const Text('Tetapkan Pemenang & Buka Chat',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentAmber,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                        ),
                      ),

                    // Pemenang - chat dengan penjual
                    if (isWinner && winnerRevealed) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final chatSvc = context.read<ChatService>();
                            final sellerId = a['seller_id']?.toString() ?? '';
                            final sellerData = await auth.getUserData(sellerId);
                            final chatId = await chatSvc.getOrCreateChat(myUid, sellerId);
                            if (context.mounted) {
                              context.push('/chat/$chatId', extra: {
                                'name': sellerData?['name'] ?? 'Penjual',
                                'photo': sellerData?['photo'] ?? '',
                                'uid': sellerId,
                              });
                            }
                          },
                          icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                          label: const Text('Chat dengan Penjual',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                    ],

                    // Penawar aktif - form tawar
                    if (isActive && !isOwner) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _bidCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'Masukkan tawaran...',
                                prefixText: 'Rp ',
                                filled: true,
                                fillColor: const Color(0xFFF6F8F7),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _isBidding ? null : () => _placeBid(a),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                            child: _isBidding
                                ? const SizedBox(width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                                : const Text('Tawar',
                                    style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      if (buyNowPrice != null) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Beli Langsung?'),
                                  content: Text(
                                    'Beli dengan harga ${fmt.format(buyNowPrice)}?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Batal')),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Beli')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await svc.endAuction(widget.auctionId);
                                _showSnack('Pembelian berhasil! 🎉', isSuccess: true);
                              }
                            },
                            icon: const Icon(Icons.bolt_rounded,
                              color: AppTheme.accentAmber),
                            label: Text('Beli Langsung ${fmt.format(buyNowPrice)}',
                              style: const TextStyle(color: AppTheme.accentAmber,
                                fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.accentAmber),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                          ),
                        ),
                      ],
                    ],

                    // Lelang berakhir tanpa pemenang
                    if (!isActive && !isOwner && !isSelesai)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12)),
                        child: const Center(
                          child: Text('Lelang telah berakhir',
                            style: TextStyle(color: Color(0xFF888780),
                              fontWeight: FontWeight.w500))),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
