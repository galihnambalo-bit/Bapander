import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../utils/supabase_config.dart';

// ============================================================
// MARKETPLACE SERVICE
// ============================================================
class MarketplaceService extends ChangeNotifier {
  final _client = SupabaseConfig.client;
  final _uuid = const Uuid();

  Future<String> createProduct({
    required String sellerId,
    required String sellerName,
    required String sellerPhoto,
    required bool sellerAnonymous,
    required String title,
    required String description,
    required double price,
    required String category,
    required String condition,
    required String location,
    List<File> imageFiles = const [],
  }) async {
    final productId = _uuid.v4();
    List<String> imageUrls = [];

    for (var i = 0; i < imageFiles.length; i++) {
      final path = 'products/$productId/img_$i.jpg';
      await _client.storage.from('media').upload(path, imageFiles[i]);
      imageUrls.add(_client.storage.from('media').getPublicUrl(path));
    }

    await _client.from('products').insert({
      'id': productId,
      'seller_id': sellerId,
      'seller_name': sellerName,
      'seller_photo': sellerPhoto,
      'seller_anonymous': sellerAnonymous,
      'title': title,
      'description': description,
      'price': price,
      'images': imageUrls,
      'category': category,
      'condition': condition,
      'status': 'aktif',
      'location': location,
    });

    return productId;
  }

  Stream<List<Map<String, dynamic>>> productsStream({String? category}) {
    var query = _client
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('status', 'aktif')
        .order('created_at', ascending: false);

    return query.map((list) {
      if (category != null) {
        return list.where((p) => p['category'] == category).toList();
      }
      return List<Map<String, dynamic>>.from(list);
    });
  }

  Future<void> toggleSave(String productId, String userId) async {
    final product = await _client
        .from('products')
        .select('saved_by')
        .eq('id', productId)
        .single();

    final savedBy = List<String>.from(product['saved_by'] ?? []);
    if (savedBy.contains(userId)) {
      savedBy.remove(userId);
    } else {
      savedBy.add(userId);
    }

    await _client
        .from('products')
        .update({'saved_by': savedBy})
        .eq('id', productId);
  }

  Future<void> markAsSold(String productId) async {
    await _client
        .from('products')
        .update({'status': 'terjual'})
        .eq('id', productId);
  }
}

// ============================================================
// AUCTION SERVICE
// ============================================================
class AuctionService extends ChangeNotifier {
  final _client = SupabaseConfig.client;
  final _uuid = const Uuid();

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
    required String category,
    required String condition,
    required DateTime endTime,
    required String location,
    List<File> imageFiles = const [],
  }) async {
    final auctionId = _uuid.v4();
    List<String> imageUrls = [];

    for (var i = 0; i < imageFiles.length; i++) {
      final path = 'auctions/$auctionId/img_$i.jpg';
      await _client.storage.from('media').upload(path, imageFiles[i]);
      imageUrls.add(_client.storage.from('media').getPublicUrl(path));
    }

    await _client.from('auctions').insert({
      'id': auctionId,
      'seller_id': sellerId,
      'seller_name': sellerName,
      'seller_photo': sellerPhoto,
      'seller_anonymous': sellerAnonymous,
      'title': title,
      'description': description,
      'images': imageUrls,
      'category': category,
      'condition': condition,
      'start_price': startPrice,
      'current_price': startPrice,
      if (buyNowPrice != null) 'buy_now_price': buyNowPrice,
      'min_bid_increment': minBidIncrement,
      'status': 'berlangsung',
      'end_time': endTime.toIso8601String(),
      'location': location,
    });

    return auctionId;
  }

  Future<String> placeBid({
    required String auctionId,
    required String bidderId,
    required String bidderName,
    required bool bidderAnonymous,
    required double bidAmount,
  }) async {
    // Get current auction
    final auction = await _client
        .from('auctions')
        .select()
        .eq('id', auctionId)
        .single();

    final currentPrice = (auction['current_price'] as num).toDouble();
    final minIncrement = (auction['min_bid_increment'] as num).toDouble();

    if (bidAmount < currentPrice + minIncrement) {
      return 'tooLow';
    }

    if (auction['seller_id'] == bidderId) {
      return 'ownAuction';
    }

    // Place bid
    await _client.from('bids').insert({
      'auction_id': auctionId,
      'bidder_id': bidderId,
      'bidder_name': bidderName,
      'bidder_anonymous': bidderAnonymous,
      'amount': bidAmount,
    });

    // Update auction
    await _client.from('auctions').update({
      'current_price': bidAmount,
      'highest_bidder_id': bidderId,
      'highest_bidder_name': bidderName,
      'highest_bidder_anonymous': bidderAnonymous,
      'total_bids': (auction['total_bids'] ?? 0) + 1,
    }).eq('id', auctionId);

    return 'success';
  }

  Stream<List<Map<String, dynamic>>> activeAuctionsStream() {
    return _client
        .from('auctions')
        .stream(primaryKey: ['id'])
        .eq('status', 'berlangsung')
        .order('end_time')
        .map((list) => List<Map<String, dynamic>>.from(list));
  }

  Stream<Map<String, dynamic>> auctionStream(String auctionId) {
    return _client
        .from('auctions')
        .stream(primaryKey: ['id'])
        .eq('id', auctionId)
        .map((list) => list.isNotEmpty ? list.first : {});
  }

  Stream<List<Map<String, dynamic>>> bidsStream(String auctionId) {
    return _client
        .from('bids')
        .stream(primaryKey: ['id'])
        .eq('auction_id', auctionId)
        .order('created_at', ascending: false)
        .map((list) => List<Map<String, dynamic>>.from(list));
  }

  Stream<List<Map<String, dynamic>>> myAuctionsStream(String sellerId) {
    return _client
        .from('auctions')
        .stream(primaryKey: ['id'])
        .eq('seller_id', sellerId)
        .order('created_at', ascending: false)
        .map((list) => List<Map<String, dynamic>>.from(list));
  }
}
