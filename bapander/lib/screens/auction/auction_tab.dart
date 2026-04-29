import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../services/auction_service.dart';
import '../../services/auth_service.dart';
import '../../models/marketplace_models.dart';
import '../../utils/app_theme.dart';

class AuctionTab extends StatefulWidget {
  const AuctionTab({super.key});

  @override
  State<AuctionTab> createState() => _AuctionTabState();
}

class _AuctionTabState extends State<AuctionTab>
    with SingleTickerProviderStateMixin {
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
            tooltip: 'Buat Lelang',
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Sedang Berlangsung'),
            Tab(text: 'Lelangku'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // ── ACTIVE AUCTIONS ──────────────────────────────────
          StreamBuilder<List<AuctionModel>>(
            stream: svc.activeAuctionsStream(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final auctions = snap.data ?? [];
              if (auctions.isEmpty) {
                return _EmptyAuction(
                    onCreate: () => context.push('/auction/create'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: auctions.length,
                itemBuilder: (ctx, i) => _AuctionCard(auction: auctions[i]),
              );
            },
          ),

          // ── MY AUCTIONS + MY BIDS ─────────────────────────
          StreamBuilder<List<AuctionModel>>(
            stream: svc.myAuctionsStream(myUid),
            builder: (ctx, snap) {
              final auctions = snap.data ?? [];
              if (auctions.isEmpty) {
                return _EmptyAuction(
                    onCreate: () => context.push('/auction/create'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: auctions.length,
                itemBuilder: (ctx, i) => _AuctionCard(
                    auction: auctions[i], isOwner: true),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AuctionCard extends StatefulWidget {
  final AuctionModel auction;
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
    _updateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTimeLeft());
  }

  void _updateTimeLeft() {
    if (!mounted) return;
    setState(() => _timeLeft = widget.auction.timeLeft);
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
    return AppTheme.primaryGreen;
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.auction;
    final fmt = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

    return GestureDetector(
      onTap: () => context.push('/auction/${a.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image + countdown overlay
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 180,
                    child: a.images.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: a.images.first,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: const Color(0xFFF0F2F1)),
                          )
                        : Container(
                            color: const Color(0xFFF0F2F1),
                            child: const Center(
                              child: Icon(Icons.gavel_rounded,
                                  size: 48, color: Color(0xFFCCCCCC)),
                            ),
                          ),
                  ),
                  // Countdown badge
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _timeColor(),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_rounded,
                              color: Colors.white, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            _formatDuration(_timeLeft),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Total bids badge
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '${a.totalBids} tawaran',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                  Text(
                    a.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),

                  // Price row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Harga Saat Ini',
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF888780))),
                            Text(
                              fmt.format(a.currentPrice),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (a.buyNowPrice != null) ...[
                        Container(
                          height: 40,
                          width: 1,
                          color: const Color(0xFFEEEEEE),
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Beli Langsung',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.accentAmber)),
                              Text(
                                fmt.format(a.buyNowPrice),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.accentAmber,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Highest bidder
                  if (a.highestBidderName != null)
                    Row(
                      children: [
                        const Icon(Icons.emoji_events_rounded,
                            size: 14, color: AppTheme.accentAmber),
                        const SizedBox(width: 4),
                        Text(
                          'Tertinggi: ${a.displayBidderName}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF888780)),
                        ),
                      ],
                    ),

                  const SizedBox(height: 12),

                  // Bid button
                  if (!widget.isOwner && a.isActive)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/auction/${a.id}'),
                        icon: const Icon(Icons.gavel_rounded, size: 18),
                        label: const Text('Tawar Sekarang'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                  if (widget.isOwner)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: a.isActive
                                ? AppTheme.primaryBg
                                : const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            a.isActive ? 'Berlangsung' : 'Selesai',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: a.isActive
                                  ? AppTheme.primaryGreen
                                  : const Color(0xFF888780),
                            ),
                          ),
                        ),
                      ],
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
          const Text('Belum ada lelang',
              style: TextStyle(fontSize: 16, color: Color(0xFF888780))),
          const SizedBox(height: 8),
          const Text('Mulai lelang barangmu sekarang!',
              style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),
          const SizedBox(height: 20),
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
