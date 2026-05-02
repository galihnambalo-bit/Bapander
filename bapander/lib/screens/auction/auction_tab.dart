import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../services/auction_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';

class AuctionTab extends StatefulWidget {
  const AuctionTab({super.key});
  @override
  State<AuctionTab> createState() => _AuctionTabState();
}

class _AuctionTabState extends State<AuctionTab> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final svc = context.read<AuctionService>();
    final myUid = auth.currentUid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        title: const Text('Lelang Bapander'),
        actions: [
          IconButton(
            icon: const Icon(Icons.gavel_rounded),
            onPressed: () => context.push('/auction/create'),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Berlangsung'),
            Tab(text: 'Lelangku'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: svc.activeAuctionsStream(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final auctions = snap.data ?? [];
              if (auctions.isEmpty) {
                return _EmptyAuction(onCreate: () => context.push('/auction/create'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: auctions.length,
                itemBuilder: (ctx, i) => _AuctionCard(auction: auctions[i]),
              );
            },
          ),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: svc.myAuctionsStream(myUid),
            builder: (ctx, snap) {
              final auctions = snap.data ?? [];
              if (auctions.isEmpty) {
                return _EmptyAuction(onCreate: () => context.push('/auction/create'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: auctions.length,
                itemBuilder: (ctx, i) => _AuctionCard(auction: auctions[i], isOwner: true),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AuctionCard extends StatefulWidget {
  final Map<String, dynamic> auction;
  final bool isOwner;

  const _AuctionCard({required this.auction, this.isOwner = false});

  @override
  State<_AuctionCard> createState() => _AuctionCardState();
}

class _AuctionCardState extends State<_AuctionCard> {
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _update() {
    if (!mounted) return;
    final endStr = widget.auction['end_time']?.toString() ?? '';
    final endTime = DateTime.tryParse(endStr);
    setState(() {
      _timeLeft = endTime != null
          ? endTime.difference(DateTime.now())
          : Duration.zero;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return 'Berakhir';
    if (d.inDays > 0) return '${d.inDays}h ${d.inHours % 24}j';
    if (d.inHours > 0) return '${d.inHours}j ${d.inMinutes % 60}m';
    return '${d.inMinutes}m ${d.inSeconds % 60}d';
  }

  Color _timeColor() {
    if (_timeLeft.isNegative) return AppTheme.dangerRed;
    if (_timeLeft.inHours < 1) return AppTheme.dangerRed;
    if (_timeLeft.inHours < 6) return AppTheme.accentAmber;
    return AppTheme.primaryBlue;
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.auction;
    final fmt = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    final images = (a['images'] as List? ?? []);
    final currentPrice = ((a['current_price'] ?? 0) as num).toDouble();
    final totalBids = a['total_bids'] ?? 0;
    final highestBidder = a['highest_bidder_anonymous'] == true
        ? 'Penawar Anonim'
        : (a['highest_bidder_name'] ?? '');
    final buyNowPrice = (a['buy_now_price'] as num?)?.toDouble();
    final isActive = a['status'] == 'berlangsung' && !_timeLeft.isNegative;
    final auctionId = a['id']?.toString() ?? '';

    return GestureDetector(
      onTap: () => context.push('/auction/$auctionId'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 180,
                    child: images.isNotEmpty
                        ? CachedNetworkImage(imageUrl: images.first.toString(), fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: const Color(0xFFF0F2F1)))
                        : Container(color: const Color(0xFFF0F2F1),
                            child: const Center(child: Icon(Icons.gavel_rounded, size: 48, color: Color(0xFFCCCCCC)))),
                  ),
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: _timeColor(), borderRadius: BorderRadius.circular(100)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_rounded, color: Colors.white, size: 13),
                          const SizedBox(width: 4),
                          Text(_formatDuration(_timeLeft),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(100)),
                      child: Text('$totalBids tawaran',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Harga Saat Ini',
                                style: TextStyle(fontSize: 11, color: Color(0xFF888780))),
                            Text(fmt.format(currentPrice),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primaryBlue)),
                          ],
                        ),
                      ),
                      if (buyNowPrice != null) ...[
                        Container(height: 40, width: 1, color: const Color(0xFFEEEEEE), margin: const EdgeInsets.symmetric(horizontal: 12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Beli Langsung', style: TextStyle(fontSize: 11, color: AppTheme.accentAmber)),
                              Text(fmt.format(buyNowPrice),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.accentAmber)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (highestBidder.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.emoji_events_rounded, size: 14, color: AppTheme.accentAmber),
                        const SizedBox(width: 4),
                        Text('Tertinggi: $highestBidder',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF888780))),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (!widget.isOwner && isActive)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/auction/$auctionId'),
                        icon: const Icon(Icons.gavel_rounded, size: 18),
                        label: const Text('Tawar Sekarang'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      ),
                    ),
                  if (widget.isOwner)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? AppTheme.primaryBg : const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        isActive ? 'Berlangsung' : 'Selesai',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: isActive ? AppTheme.primaryBlue : const Color(0xFF888780),
                        ),
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

class _EmptyAuction extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyAuction({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.gavel_outlined, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('Belum ada lelang', style: TextStyle(fontSize: 16, color: Color(0xFF888780))),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.gavel_rounded, size: 18),
            label: const Text('Buat Lelang'),
          ),
        ],
      ),
    );
  }
}
