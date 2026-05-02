class StatusModel {
  final String id;
  final String userId;
  final String userName;
  final String userPhoto;
  final String type; // 'text', 'image', 'video'
  final String content; // text atau URL media
  final String? caption;
  final String backgroundColor;
  final String fontColor;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> viewedBy;
  final bool isAnonymous;

  StatusModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhoto,
    required this.type,
    required this.content,
    this.caption,
    this.backgroundColor = '#1565C0',
    this.fontColor = '#FFFFFF',
    required this.createdAt,
    required this.expiresAt,
    this.viewedBy = const [],
    this.isAnonymous = false,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isActive => !isExpired;
  String get displayName => isAnonymous ? 'Pengguna Anonim' : userName;
  String get displayPhoto => isAnonymous ? '' : userPhoto;

  factory StatusModel.fromMap(Map<String, dynamic> map, String id) {
    return StatusModel(
      id: id,
      userId: map['user_id'] ?? '',
      userName: map['user_name'] ?? '',
      userPhoto: map['user_photo'] ?? '',
      type: map['type'] ?? 'text',
      content: map['content'] ?? '',
      caption: map['caption'],
      backgroundColor: map['background_color'] ?? '#1565C0',
      fontColor: map['font_color'] ?? '#FFFFFF',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now().toLocal(),
      expiresAt: DateTime.tryParse(map['expires_at']?.toString() ?? '')?.toLocal() ?? DateTime.now().toLocal().add(const Duration(hours: 24)),
      viewedBy: List<String>.from(map['viewed_by'] ?? []),
      isAnonymous: map['is_anonymous'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'user_name': userName,
    'user_photo': userPhoto,
    'type': type,
    'content': content,
    'caption': caption,
    'background_color': backgroundColor,
    'font_color': fontColor,
    'created_at': createdAt.toIso8601String(),
    'expires_at': expiresAt.toIso8601String(),
    'viewed_by': viewedBy,
    'is_anonymous': isAnonymous,
  };
}
