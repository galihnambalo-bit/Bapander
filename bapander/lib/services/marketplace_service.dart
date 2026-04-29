import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/marketplace_models.dart';

class MarketplaceService extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  // ─── UPLOAD PRODUCT IMAGES ────────────────────────────────
  Future<List<String>> uploadProductImages(
      List<File> images, String productId) async {
    final urls = <String>[];
    for (var i = 0; i < images.length; i++) {
      final ref = _storage.ref('marketplace/$productId/img_$i.jpg');
      await ref.putFile(images[i]);
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

  // ─── CREATE PRODUCT ───────────────────────────────────────
  Future<String> createProduct({
    required String sellerId,
    required String sellerName,
    required String sellerPhoto,
    required bool sellerAnonymous,
    required String title,
    required String description,
    required double price,
    required ProductCategory category,
    required ProductCondition condition,
    required String location,
    double? latitude,
    double? longitude,
    List<File> imageFiles = const [],
  }) async {
    final productId = _uuid.v4();

    List<String> imageUrls = [];
    if (imageFiles.isNotEmpty) {
      imageUrls = await uploadProductImages(imageFiles, productId);
    }

    final product = ProductModel(
      id: productId,
      sellerId: sellerId,
      sellerName: sellerName,
      sellerPhoto: sellerPhoto,
      sellerAnonymous: sellerAnonymous,
      title: title,
      description: description,
      price: price,
      images: imageUrls,
      category: category,
      condition: condition,
      location: location,
      latitude: latitude,
      longitude: longitude,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await _db.collection('products').doc(productId).set(product.toMap());
    return productId;
  }

  // ─── GET PRODUCTS STREAM ──────────────────────────────────
  Stream<List<ProductModel>> productsStream({
    ProductCategory? category,
    String? searchQuery,
    String? sellerId,
  }) {
    Query query = _db
        .collection('products')
        .where('status', isEqualTo: 'aktif')
        .orderBy('created_at', descending: true);

    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }
    if (sellerId != null) {
      query = query.where('seller_id', isEqualTo: sellerId);
    }

    return query.snapshots().map((snap) => snap.docs
        .map((d) => ProductModel.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList());
  }

  // ─── GET SINGLE PRODUCT ───────────────────────────────────
  Future<ProductModel?> getProduct(String productId) async {
    final doc = await _db.collection('products').doc(productId).get();
    if (!doc.exists) return null;
    // Increment view count
    await doc.reference.update({'view_count': FieldValue.increment(1)});
    return ProductModel.fromMap(doc.data()!, doc.id);
  }

  // ─── MARK AS SOLD ─────────────────────────────────────────
  Future<void> markAsSold(String productId) async {
    await _db.collection('products').doc(productId).update(
      {'status': ProductStatus.terjual.name},
    );
  }

  // ─── DELETE PRODUCT ───────────────────────────────────────
  Future<void> deleteProduct(String productId) async {
    await _db.collection('products').doc(productId).update(
      {'status': ProductStatus.dihapus.name},
    );
  }

  // ─── SAVE / UNSAVE PRODUCT ────────────────────────────────
  Future<void> toggleSave(String productId, String userId) async {
    final doc = await _db.collection('products').doc(productId).get();
    final savedBy = List<String>.from(doc.data()?['saved_by'] ?? []);

    if (savedBy.contains(userId)) {
      savedBy.remove(userId);
    } else {
      savedBy.add(userId);
    }
    await doc.reference.update({'saved_by': savedBy});
  }

  // ─── SAVED PRODUCTS STREAM ────────────────────────────────
  Stream<List<ProductModel>> savedProductsStream(String userId) {
    return _db
        .collection('products')
        .where('saved_by', arrayContains: userId)
        .where('status', isEqualTo: 'aktif')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ProductModel.fromMap(d.data(), d.id))
            .toList());
  }

  // ─── SEARCH PRODUCTS ──────────────────────────────────────
  Future<List<ProductModel>> searchProducts(String query) async {
    final snap = await _db
        .collection('products')
        .where('status', isEqualTo: 'aktif')
        .orderBy('title')
        .startAt([query])
        .endAt(['$query\uf8ff'])
        .limit(20)
        .get();

    return snap.docs
        .map((d) => ProductModel.fromMap(d.data(), d.id))
        .toList();
  }
}
