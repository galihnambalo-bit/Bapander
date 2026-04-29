import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/marketplace_models.dart';

class AuctionService extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  // ─── CREATE AUCTION ───────────────────────────────────────
  Future<String> createAuction({
    required String sellerId,
    required String sellerName,
    required String sellerPhoto,
    required bool sellerAnonymous,
    required String title,
    required String description,
    required double startPrice,
    required double minBidIncrement,
    double? buyNowPrice,
    required ProductCategory category,
    required ProductCondition condition,
    required DateTime endTime,
    required String location,
    List<File> imageFiles = const [],
  }) async {
    final auctionId = _uuid.v4();

    // Upload images
    List<String> imageUrls = [];
    for (var i = 0; i < imageFiles.length; i++) {
      final ref = _storage.ref('auctions/$auctionId/img_$i.jpg');
      await ref.putFile(imageFiles[i]);
      imageUrls.add(await ref.getDownloadURL());
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final auction = AuctionModel(
      id: auctionId,
      sellerId: sellerId,
      sellerName: sellerName,
      sellerPhoto: sellerPhoto,
      sellerAnonymous: sellerAnonymous,
      title: title,
      description: description,
      images: imageUrls,
      category: category,
      condition: condition,
      startPrice: startPrice,
      currentPrice: startPrice,
      buyNowPrice: buyNowPrice,
      minBidIncrement: minBidIncrement,
      status: AuctionStatus.berlangsung,
      startTime: now,
      endTime: endTime.millisecondsSinceEpoch,
      createdAt: now,
      location: location,
    );

    await _db.collection('auctions').doc(auctionId).set(auction.toMap());
    return auctionId;
  }

  // ─── PLACE BID ────────────────────────────────────────────
  Future<BidResult> placeBid({
    required String auctionId,
    required String bidderId,
    required String bidderName,
    required bool bidderAnonymous,
    required double bidAmount,
  }) async {
    try {
      return await _db.runTransaction((tx) async {
        final auctionRef = _db.collection('auctions').doc(auctionId);
        final auctionDoc = await tx.get(auctionRef);

        if (!auctionDoc.exists) return BidResult.notFound;

        final auction =
            AuctionModel.fromMap(auctionDoc.data()!, auctionDoc.id);

        // Validasi
        if (!auction.isActive) return BidResult.auctionEnded;
        if (auction.sellerId == bidderId) return BidResult.ownAuction;
        if (bidAmount < auction.currentPrice + auction.minBidIncrement) {
          return BidResult.tooLow;
        }

        // Simpan bid ke history
        final bidId = _uuid.v4();
        final bidRef = _db
            .collection('auctions')
            .doc(auctionId)
            .collection('bids')
            .doc(bidId);

        final bid = BidModel(
          id: bidId,
          auctionId: auctionId,
          bidderId: bidderId,
          bidderName: bidderName,
          bidderAnonymous: bidderAnonymous,
          amount: bidAmount,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );

        tx.set(bidRef, bid.toMap());

        // Update auction current price
        tx.update(auctionRef, {
          'current_price': bidAmount,
          'highest_bidder_id': bidderId,
          'highest_bidder_name': bidderName,
          'highest_bidder_anonymous': bidderAnonymous,
          'total_bids': FieldValue.increment(1),
        });

        return BidResult.success;
      });
    } catch (e) {
      return BidResult.error;
    }
  }

  // ─── BUY NOW ──────────────────────────────────────────────
  Future<bool> buyNow({
    required String auctionId,
    required String buyerId,
  }) async {
    try {
      await _db.collection('auctions').doc(auctionId).update({
        'status': AuctionStatus.selesai.name,
        'highest_bidder_id': buyerId,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── AUCTIONS STREAM (active) ─────────────────────────────
  Stream<List<AuctionModel>> activeAuctionsStream({
    ProductCategory? category,
  }) {
    Query query = _db
        .collection('auctions')
        .where('status', isEqualTo: AuctionStatus.berlangsung.name)
        .orderBy('end_time');

    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }

    return query.snapshots().map((snap) => snap.docs
        .map((d) => AuctionModel.fromMap(d.data() as Map<String, dynamic>, d.id))
        .where((a) => a.isActive)
        .toList());
  }

  // ─── SINGLE AUCTION STREAM ────────────────────────────────
  Stream<AuctionModel> auctionStream(String auctionId) {
    return _db
        .collection('auctions')
        .doc(auctionId)
        .snapshots()
        .map((d) => AuctionModel.fromMap(d.data()!, d.id));
  }

  // ─── BID HISTORY STREAM ───────────────────────────────────
  Stream<List<BidModel>> bidsStream(String auctionId) {
    return _db
        .collection('auctions')
        .doc(auctionId)
        .collection('bids')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => BidModel.fromMap(d.data(), d.id)).toList());
  }

  // ─── MY AUCTIONS STREAM ───────────────────────────────────
  Stream<List<AuctionModel>> myAuctionsStream(String sellerId) {
    return _db
        .collection('auctions')
        .where('seller_id', isEqualTo: sellerId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AuctionModel.fromMap(d.data(), d.id))
            .toList());
  }

  // ─── MY BIDS STREAM ───────────────────────────────────────
  Stream<List<AuctionModel>> myBidsStream(String bidderId) {
    return _db
        .collection('auctions')
        .where('highest_bidder_id', isEqualTo: bidderId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AuctionModel.fromMap(d.data(), d.id))
            .toList());
  }

  // ─── END EXPIRED AUCTIONS (Cloud Function trigger) ────────
  Future<void> checkAndEndAuctions() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final snap = await _db
        .collection('auctions')
        .where('status', isEqualTo: AuctionStatus.berlangsung.name)
        .where('end_time', isLessThan: now)
        .get();

    for (var doc in snap.docs) {
      await doc.reference.update({'status': AuctionStatus.selesai.name});
    }
  }
}

enum BidResult {
  success,
  tooLow,
  auctionEnded,
  ownAuction,
  notFound,
  error,
}

extension BidResultMessage on BidResult {
  String get message {
    switch (this) {
      case BidResult.success: return 'Tawaran berhasil ditempatkan!';
      case BidResult.tooLow: return 'Tawaran terlalu rendah. Naikkan minimal sesuai increment.';
      case BidResult.auctionEnded: return 'Lelang sudah berakhir.';
      case BidResult.ownAuction: return 'Kamu tidak bisa menawar barangmu sendiri.';
      case BidResult.notFound: return 'Lelang tidak ditemukan.';
      case BidResult.error: return 'Terjadi kesalahan. Coba lagi.';
    }
  }
}
