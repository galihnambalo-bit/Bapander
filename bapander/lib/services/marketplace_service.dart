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
