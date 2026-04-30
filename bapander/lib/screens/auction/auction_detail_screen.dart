import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../services/auction_service.dart';
import '../../services/auth_service.dart';
import '../../models/marketplace_models.dart';
import '../../utils/app_theme.dart';
import '../../widgets/avatar_widget.dart';

class AuctionDetailScreen extends StatefulWidget {
  final String auctionId;
  const AuctionDetailScreen({super.key, required this.auctionId});

  @override
  State<AuctionDetailScreen> createState() => _AuctionDetailScreenState();
}

class _AuctionDetailScreenState extends State<AuctionDetailScreen> {
  final _bidCtrl = TextEditingController();
  bool _bidAnonymous = false;
  bool _isBidding = false;
  int _imgIndex = 0;

  final fmt = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

  Future<void> _placeBid(Map<String, dynamic> auction) async {
    final amount = double.tryParse(_bidCtrl.text.replaceAll('.', ''));
    if (amount == null) {
      _showSnack('Masukkan jumlah tawaran yang valid');
      return;
    }

    final minBid = auction.currentPrice + auction.minBidIncrement;
    if (amount < minBid) {
      _showSnack('Tawaran minimal ${fmt.format(minBid)}');
      return;
    }

    setState(() => _isBidding = true);

    final auth = context.read<AuthService>();
    final svc = context.read<AuctionService>();
    final userData = await auth.getUserData(auth.currentUid ?? '');

    final result = await svc.placeBid(
      auctionId: widget.auctionId,
      bidderId: auth.currentUid ?? '',
      bidderName: userData?['name'] ?? '',
      bidderAnonymous: _bidAnonymous,
      bidAmount: amount,
    );

    setState(() => _isBidding = false);
    _bidCtrl.clear();

    _showSnack(
      result == 'success' ? 'Tawaran berhasil!' : 
      result == 'tooLow' ? 'Tawaran terlalu rendah!' :
      result == 'ownAuction' ? 'Tidak bisa tawar barang sendiri!' : 'Gagal',
      isSuccess: result == 'success');
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isSuccess ? AppTheme.primaryGreen : AppTheme.dangerRed,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final svc = context.read<AuctionService>();
    final myUid = auth.currentUid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: svc.auctionStream(widget.auctionId),
        builder: (ctx, snap) {
          if (!snap.hasData || snap.data!.isEmpty) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final a = snap.data!;  // Map<String, dynamic>
          final isOwner = a['seller_id']?.toString() == myUid;
          final minNextBid = ((a['current_price'] ?? 0) as num).toDouble() + ((a['min_bid_increment'] ?? 1000) as num).toDouble();

          return CustomScrollView(
            slivers: [
              // ── IMAGE SLIVER APP BAR ──────────────────────
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: AppTheme.primaryGreen,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: (a['images'] as List? ?? []).isNotEmpty
                      ? PageView.builder(
                          itemCount: (a['images'] as List? ?? []).length,
                          onPageChanged: (i) =>
                              setState(() => _imgIndex = i),
                          itemBuilder: (_, i) => CachedNetworkImage(
                            imageUrl: (a['images'] as List)[i].toString(),
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          color: const Color(0xFFF0F2F1),
                          child: const Icon(Icons.gavel_rounded,
                              size: 80, color: Color(0xFFCCCCCC)),
                        ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── COUNTDOWN ────────────────────────────
                      _CountdownWidget(endTime: DateTime.tryParse(a['end_time']?.toString() ?? '')?.millisecondsSinceEpoch ?? 0),
                      const SizedBox(height: 12),

                      // ── TITLE ────────────────────────────────
                      Text((a['title'] ?? ''),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text((a['location'] ?? ''),
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF888780))),
                      const SizedBox(height: 16),

                      // ── PRICE CARD ───────────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryGreen, AppTheme.primaryLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Tawaran Tertinggi',
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(
                                    fmt.format(((a['current_price'] ?? 0) as num).toDouble()),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (a['highest_bidder_name'] != null)
                                    Text(
                                      'oleh ${(a['highest_bidder_anonymous'] == true ? 'Penawar Anonim' : (a['highest_bidder_name'] ?? '-'))}',
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Icon(Icons.people_rounded,
                                    color: Colors.white60, size: 16),
                                Text(
                                  '${(a['total_bids'] ?? 0)} tawaran',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Min. kenaikan\n${fmt.format(((a['min_bid_increment'] ?? 1000) as num).toDouble())}',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── BUY NOW ──────────────────────────────
                      if ((a['buy_now_price'] as num?)?.toDouble() != null && !isOwner && (a['status'] == 'berlangsung' && DateTime.tryParse(a['end_time']?.toString() ?? '')?.isAfter(DateTime.now()) == true))
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E7),
                            border: Border.all(
                                color: AppTheme.accentAmber, width: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Beli Langsung',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.accentAmber,
                                          fontWeight: FontWeight.w600)),
                                  Text(
                                    fmt.format((a['buy_now_price'] as num?)?.toDouble()),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.accentAmber,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              ElevatedButton(
                                onPressed: () => _confirmBuyNow(a),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentAmber,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Beli'),
                              ),
                            ],
                          ),
                        ),

                      // ── BID INPUT ────────────────────────────
                      if (!isOwner && (a['status'] == 'berlangsung' && DateTime.tryParse(a['end_time']?.toString() ?? '')?.isAfter(DateTime.now()) == true)) ...[
                        const Text('PASANG TAWARAN',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF888780),
                                letterSpacing: 0.7)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _bidCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                decoration: InputDecoration(
                                  hintText: 'Min ${fmt.format(minNextBid)}',
                                  prefixText: 'Rp ',
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed:
                                  _isBidding ? null : () => _placeBid(a),
                              style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 16)),
                              child: _isBidding
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
                                  : const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.gavel_rounded, size: 18),
                                        SizedBox(width: 6),
                                        Text('Tawar'),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Quick bid buttons
                        Row(
                          children: [
                            _QuickBidBtn(
                              label: '+${fmt.format(((a['min_bid_increment'] ?? 1000) as num).toDouble())}',
                              onTap: () => _bidCtrl.text =
                                  (minNextBid).toStringAsFixed(0),
                            ),
                            const SizedBox(width: 8),
                            _QuickBidBtn(
                              label: '+${fmt.format(((a['min_bid_increment'] ?? 1000) as num).toDouble() * 2)}',
                              onTap: () => _bidCtrl.text =
                                  (((a['current_price'] ?? 0) as num).toDouble() + ((a['min_bid_increment'] ?? 1000) as num).toDouble() * 2)
                                      .toStringAsFixed(0),
                            ),
                            const SizedBox(width: 8),
                            _QuickBidBtn(
                              label: '+${fmt.format(((a['min_bid_increment'] ?? 1000) as num).toDouble() * 5)}',
                              onTap: () => _bidCtrl.text =
                                  (((a['current_price'] ?? 0) as num).toDouble() + ((a['min_bid_increment'] ?? 1000) as num).toDouble() * 5)
                                      .toStringAsFixed(0),
                            ),
                          ],
                        ),

                        // Anonymous bid toggle
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Switch(
                              value: _bidAnonymous,
                              onChanged: (v) =>
                                  setState(() => _bidAnonymous = v),
                              activeColor: AppTheme.primaryGreen,
                            ),
                            const SizedBox(width: 6),
                            const Text('Tawar secara anonim',
                                style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 6),
                            Icon(
                              _bidAnonymous
                                  ? Icons.person_off_rounded
                                  : Icons.person_rounded,
                              size: 16,
                              color: const Color(0xFF888780),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── DESCRIPTION ──────────────────────────
                      const Text('DESKRIPSI',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF888780),
                              letterSpacing: 0.7)),
                      const SizedBox(height: 8),
                      Text((a['description'] ?? ''),
                          style: const TextStyle(
                              fontSize: 14, height: 1.6)),
                      const SizedBox(height: 20),

                      // ── BID HISTORY ──────────────────────────
                      const Text('RIWAYAT TAWARAN',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF888780),
                              letterSpacing: 0.7)),
                      const SizedBox(height: 8),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: svc.bidsStream(widget.auctionId),
                        builder: (ctx2, bidSnap) {
                          final bids = bidSnap.data ?? <Map<String, dynamic>>[];
                          if (bids.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Belum ada tawaran. Jadilah yang pertama!',
                                  style: TextStyle(color: Color(0xFFAAAAAA))),
                            );
                          }
                          return Column(
                            children: bids.asMap().entries.map((e) {
                              final bid = e.value as Map<String, dynamic>;
                              final isFirst = e.key == 0;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isFirst
                                      ? AppTheme.primaryBg
                                      : Colors.white,
                                  border: Border.all(
                                    color: isFirst
                                        ? AppTheme.primaryLight
                                        : const Color(0xFFEEEEEE),
                                    width: isFirst ? 1.5 : 0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    if (isFirst)
                                      const Icon(Icons.emoji_events_rounded,
                                          color: AppTheme.accentAmber,
                                          size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (bid['bidder_anonymous'] == true ? 'Penawar Anonim' : (bid['bidder_name'] ?? 'User')),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: isFirst
                                                  ? AppTheme.primaryGreen
                                                  : null,
                                            ),
                                          ),
                                          Text(
                                            _formatTs(bid['created_at']),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF888780)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      fmt.format(((bid['amount'] ?? 0) as num).toDouble()),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: isFirst
                                            ? AppTheme.primaryGreen
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatTs(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmBuyNow(Map<String, dynamic> a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Beli Langsung?'),
        content: Text(
            'Kamu akan membeli "${a['title'] ?? ''}" seharga ${fmt.format((a['buy_now_price'] as num?)?.toDouble()!)}. '
            'Lelang akan segera berakhir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Beli Sekarang'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final svc = context.read<AuctionService>();
      final auth = context.read<AuthService>();
      await svc.placeBid(
          auctionId: widget.auctionId,
          bidderId: auth.currentUid ?? '',
          bidderName: 'BuyNow',
          bidderAnonymous: false,
          bidAmount: (a['buy_now_price'] as num).toDouble(),
        );
        await svc.endAuction(widget.auctionId);
      if (mounted) {
        _showSnack('Berhasil membeli! Silakan hubungi penjual.', isSuccess: true);
        context.pop();
      }
    }
  }
}

class _CountdownWidget extends StatefulWidget {
  final int endTime;
  const _CountdownWidget({required this.endTime});

  @override
  State<_CountdownWidget> createState() => _CountdownWidgetState();
}

class _CountdownWidgetState extends State<_CountdownWidget> {
  Timer? _timer;
  Duration _left = Duration.zero;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _update() {
    if (!mounted) return;
    setState(() {
      _left = DateTime.fromMillisecondsSinceEpoch(widget.endTime)
          .difference(DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_left.isNegative) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEB),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Lelang telah berakhir',
            style: TextStyle(color: AppTheme.dangerRed, fontWeight: FontWeight.w600)),
      );
    }

    final days = _left.inDays;
    final hours = _left.inHours % 24;
    final mins = _left.inMinutes % 60;
    final secs = _left.inSeconds % 60;
    final color = _left.inHours < 1 ? AppTheme.dangerRed : AppTheme.primaryGreen;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _TimeUnit(value: days, label: 'Hari', color: color),
          _Divider(color: color),
          _TimeUnit(value: hours, label: 'Jam', color: color),
          _Divider(color: color),
          _TimeUnit(value: mins, label: 'Menit', color: color),
          _Divider(color: color),
          _TimeUnit(value: secs, label: 'Detik', color: color),
        ],
      ),
    );
  }
}

class _TimeUnit extends StatelessWidget {
  final int value;
  final String label;
  final Color color;

  const _TimeUnit({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800, color: color),
        ),
        Text(label,
            style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  final Color color;
  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(':', style: TextStyle(fontSize: 22, color: color, fontWeight: FontWeight.w800));
  }
}

class _QuickBidBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickBidBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.primaryLight),
            borderRadius: BorderRadius.circular(8),
            color: AppTheme.primaryBg,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryGreen),
          ),
        ),
      ),
    );
  }
}
