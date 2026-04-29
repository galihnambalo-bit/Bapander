// ============================================================
// MARKETPLACE MODELS
// ============================================================

enum ProductCategory {
  elektronik,
  fashion,
  makanan,
  kendaraan,
  properti,
  jasa,
  seni,
  lainnya,
}

enum ProductCondition { baru, bekasLayak, bekasRusak }
enum ProductStatus { aktif, terjual, dihapus }

class ProductModel {
  final String id;
  final String sellerId;
  final String sellerName;
  final String sellerPhoto;
  final bool sellerAnonymous;
  final String title;
  final String description;
  final double price;
  final List<String> images;
  final ProductCategory category;
  final ProductCondition condition;
  final ProductStatus status;
  final String location;
  final double? latitude;
  final double? longitude;
  final int createdAt;
  final int viewCount;
  final List<String> savedBy;

  ProductModel({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    this.sellerPhoto = '',
    this.sellerAnonymous = false,
    required this.title,
    required this.description,
    required this.price,
    this.images = const [],
    required this.category,
    this.condition = ProductCondition.baru,
    this.status = ProductStatus.aktif,
    this.location = '',
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.viewCount = 0,
    this.savedBy = const [],
  });

  String get displaySellerName => sellerAnonymous ? 'Penjual Anonim' : sellerName;
  String get displaySellerPhoto => sellerAnonymous ? '' : sellerPhoto;

  factory ProductModel.fromMap(Map<String, dynamic> map, String id) {
    return ProductModel(
      id: id,
      sellerId: map['seller_id'] ?? '',
      sellerName: map['seller_name'] ?? '',
      sellerPhoto: map['seller_photo'] ?? '',
      sellerAnonymous: map['seller_anonymous'] ?? false,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      images: List<String>.from(map['images'] ?? []),
      category: ProductCategory.values.firstWhere(
        (e) => e.name == (map['category'] ?? 'lainnya'),
        orElse: () => ProductCategory.lainnya,
      ),
      condition: ProductCondition.values.firstWhere(
        (e) => e.name == (map['condition'] ?? 'baru'),
        orElse: () => ProductCondition.baru,
      ),
      status: ProductStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'aktif'),
        orElse: () => ProductStatus.aktif,
      ),
      location: map['location'] ?? '',
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      createdAt: map['created_at'] ?? 0,
      viewCount: map['view_count'] ?? 0,
      savedBy: List<String>.from(map['saved_by'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'seller_id': sellerId,
    'seller_name': sellerName,
    'seller_photo': sellerPhoto,
    'seller_anonymous': sellerAnonymous,
    'title': title,
    'description': description,
    'price': price,
    'images': images,
    'category': category.name,
    'condition': condition.name,
    'status': status.name,
    'location': location,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    'created_at': createdAt,
    'view_count': viewCount,
    'saved_by': savedBy,
  };
}

// ============================================================
// AUCTION MODELS
// ============================================================

enum AuctionStatus { menunggu, berlangsung, selesai, dibatalkan }

class AuctionModel {
  final String id;
  final String sellerId;
  final String sellerName;
  final String sellerPhoto;
  final bool sellerAnonymous;
  final String title;
  final String description;
  final List<String> images;
  final ProductCategory category;
  final ProductCondition condition;
  final double startPrice;       // Harga awal
  final double currentPrice;     // Harga penawaran tertinggi saat ini
  final double? buyNowPrice;     // Beli langsung (opsional)
  final double minBidIncrement;  // Minimal kenaikan bid
  final String? highestBidderId;
  final String? highestBidderName;
  final bool highestBidderAnonymous;
  final AuctionStatus status;
  final int startTime;
  final int endTime;
  final int createdAt;
  final String location;
  final int totalBids;

  AuctionModel({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    this.sellerPhoto = '',
    this.sellerAnonymous = false,
    required this.title,
    required this.description,
    this.images = const [],
    required this.category,
    this.condition = ProductCondition.baru,
    required this.startPrice,
    required this.currentPrice,
    this.buyNowPrice,
    this.minBidIncrement = 1000,
    this.highestBidderId,
    this.highestBidderName,
    this.highestBidderAnonymous = false,
    required this.status,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
    this.location = '',
    this.totalBids = 0,
  });

  bool get isActive => status == AuctionStatus.berlangsung &&
      DateTime.now().millisecondsSinceEpoch < endTime;

  Duration get timeLeft => DateTime.fromMillisecondsSinceEpoch(endTime)
      .difference(DateTime.now());

  String get displaySellerName => sellerAnonymous ? 'Penjual Anonim' : sellerName;
  String get displayBidderName =>
      highestBidderAnonymous ? 'Penawar Anonim' : (highestBidderName ?? '-');

  factory AuctionModel.fromMap(Map<String, dynamic> map, String id) {
    return AuctionModel(
      id: id,
      sellerId: map['seller_id'] ?? '',
      sellerName: map['seller_name'] ?? '',
      sellerPhoto: map['seller_photo'] ?? '',
      sellerAnonymous: map['seller_anonymous'] ?? false,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      category: ProductCategory.values.firstWhere(
        (e) => e.name == (map['category'] ?? 'lainnya'),
        orElse: () => ProductCategory.lainnya,
      ),
      condition: ProductCondition.values.firstWhere(
        (e) => e.name == (map['condition'] ?? 'baru'),
        orElse: () => ProductCondition.baru,
      ),
      startPrice: (map['start_price'] ?? 0).toDouble(),
      currentPrice: (map['current_price'] ?? 0).toDouble(),
      buyNowPrice: map['buy_now_price']?.toDouble(),
      minBidIncrement: (map['min_bid_increment'] ?? 1000).toDouble(),
      highestBidderId: map['highest_bidder_id'],
      highestBidderName: map['highest_bidder_name'],
      highestBidderAnonymous: map['highest_bidder_anonymous'] ?? false,
      status: AuctionStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'menunggu'),
        orElse: () => AuctionStatus.menunggu,
      ),
      startTime: map['start_time'] ?? 0,
      endTime: map['end_time'] ?? 0,
      createdAt: map['created_at'] ?? 0,
      location: map['location'] ?? '',
      totalBids: map['total_bids'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'seller_id': sellerId,
    'seller_name': sellerName,
    'seller_photo': sellerPhoto,
    'seller_anonymous': sellerAnonymous,
    'title': title,
    'description': description,
    'images': images,
    'category': category.name,
    'condition': condition.name,
    'start_price': startPrice,
    'current_price': currentPrice,
    if (buyNowPrice != null) 'buy_now_price': buyNowPrice,
    'min_bid_increment': minBidIncrement,
    'highest_bidder_id': highestBidderId,
    'highest_bidder_name': highestBidderName,
    'highest_bidder_anonymous': highestBidderAnonymous,
    'status': status.name,
    'start_time': startTime,
    'end_time': endTime,
    'created_at': createdAt,
    'location': location,
    'total_bids': totalBids,
  };
}

// ============================================================
// BID HISTORY MODEL
// ============================================================
class BidModel {
  final String id;
  final String auctionId;
  final String bidderId;
  final String bidderName;
  final bool bidderAnonymous;
  final double amount;
  final int timestamp;

  BidModel({
    required this.id,
    required this.auctionId,
    required this.bidderId,
    required this.bidderName,
    this.bidderAnonymous = false,
    required this.amount,
    required this.timestamp,
  });

  String get displayName => bidderAnonymous ? 'Penawar Anonim' : bidderName;

  factory BidModel.fromMap(Map<String, dynamic> map, String id) => BidModel(
    id: id,
    auctionId: map['auction_id'] ?? '',
    bidderId: map['bidder_id'] ?? '',
    bidderName: map['bidder_name'] ?? '',
    bidderAnonymous: map['bidder_anonymous'] ?? false,
    amount: (map['amount'] ?? 0).toDouble(),
    timestamp: map['timestamp'] ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'auction_id': auctionId,
    'bidder_id': bidderId,
    'bidder_name': bidderName,
    'bidder_anonymous': bidderAnonymous,
    'amount': amount,
    'timestamp': timestamp,
  };
}

// ============================================================
// NEARBY USER MODEL
// ============================================================
class NearbyUserModel {
  final String uid;
  final String name;
  final String photo;
  final String gender; // 'L' or 'P'
  final int age;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final bool isAnonymous;
  final bool online;
  final String bio;
  final String interest;

  NearbyUserModel({
    required this.uid,
    required this.name,
    required this.photo,
    required this.gender,
    required this.age,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    this.isAnonymous = false,
    this.online = false,
    this.bio = '',
    this.interest = '',
  });

  String get displayName => isAnonymous ? 'Pengguna Anonim' : name;
  String get genderLabel => gender == 'L' ? 'Laki-laki' : 'Perempuan';
  String get genderIcon => gender == 'L' ? '👨' : '👩';

  factory NearbyUserModel.fromMap(Map<String, dynamic> map, String uid, double dist) =>
      NearbyUserModel(
        uid: uid,
        name: map['name'] ?? '',
        photo: map['photo'] ?? '',
        gender: map['gender'] ?? 'L',
        age: map['age'] ?? 0,
        latitude: (map['latitude'] ?? 0).toDouble(),
        longitude: (map['longitude'] ?? 0).toDouble(),
        distanceKm: dist,
        isAnonymous: map['anonymous_mode'] ?? false,
        online: map['online'] ?? false,
        bio: map['bio'] ?? '',
        interest: map['interest'] ?? '',
      );
}
