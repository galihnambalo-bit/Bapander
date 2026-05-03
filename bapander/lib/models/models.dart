// ============================================================
// USER MODEL
// ============================================================
class UserModel {
  final String id;
  final String name;
  final String phone;
  final String photo;
  final bool online;
  final int lastSeen;
  final String language;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.photo = '',
    this.online = false,
    required this.lastSeen,
    this.language = 'id',
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      photo: map['photo'] ?? '',
      online: map['online'] ?? false,
      lastSeen: map['last_seen'] ?? 0,
      language: map['language'] ?? 'id',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'photo': photo,
      'online': online,
      'last_seen': lastSeen,
      'language': language,
    };
  }
}

// ============================================================
// MESSAGE MODEL
// ============================================================
enum MessageType { text, image, voice, sticker, system }
enum MessageStatus { sending, sent, delivered, read }

class MessageModel {
  final String id;
  final String sender;
  final String text;
  final MessageType type;
  final String mediaUrl;
  final int timestamp;
  final MessageStatus status;
  final int? duration; // for voice notes in seconds

  MessageModel({
    required this.id,
    required this.sender,
    required this.text,
    this.type = MessageType.text,
    this.mediaUrl = '',
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.duration,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      sender: map['sender'] ?? '',
      text: map['text'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      mediaUrl: map['media_url'] ?? '',
    timestamp: map["timestamp"] is String ? DateTime.parse(map["timestamp"]).toLocal() : (map["timestamp"] as DateTime).toLocal(),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'sent'),
        orElse: () => MessageStatus.sent,
      ),
      duration: map['duration'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender': sender,
      'text': text,
      'type': type.name,
      'media_url': mediaUrl,
      'timestamp': timestamp,
      'status': status.name,
      if (duration != null) 'duration': duration,
    };
  }
}

// ============================================================
// CHAT MODEL
// ============================================================
class ChatModel {
  final String chatId;
  final String type; // 'private' or 'group'
  final List<String> members;
  final String lastMessage;
  final int lastTimestamp;
  final Map<String, int> unreadCount;

  ChatModel({
    required this.chatId,
    required this.type,
    required this.members,
    this.lastMessage = '',
    this.lastTimestamp = 0,
    this.unreadCount = const {},
  });

  factory ChatModel.fromMap(Map<String, dynamic> map, String id) {
    return ChatModel(
      chatId: id,
      type: map['type'] ?? 'private',
      members: List<String>.from(map['members'] ?? []),
      lastMessage: map['last_message'] ?? '',
      lastTimestamp: map['last_timestamp'] ?? 0,
      unreadCount: Map<String, int>.from(map['unread_count'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'members': members,
      'last_message': lastMessage,
      'last_timestamp': lastTimestamp,
      'unread_count': unreadCount,
    };
  }
}

// ============================================================
// GROUP MODEL
// ============================================================
class GroupModel {
  final String groupId;
  final String name;
  final String photo;
  final String description;
  final List<String> members;
  final List<String> admins;
  final int createdAt;
  final String language;

  GroupModel({
    required this.groupId,
    required this.name,
    this.photo = '',
    this.description = '',
    required this.members,
    required this.admins,
    required this.createdAt,
    this.language = 'id',
  });

  factory GroupModel.fromMap(Map<String, dynamic> map, String id) {
    return GroupModel(
      groupId: id,
      name: map['name'] ?? '',
      photo: map['photo'] ?? '',
      description: map['description'] ?? '',
      members: List<String>.from(map['members'] ?? []),
      admins: List<String>.from(map['admin'] ?? []),
      createdAt: map['created_at'] ?? 0,
      language: map['language'] ?? 'id',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'photo': photo,
      'description': description,
      'members': members,
      'admin': admins,
      'created_at': createdAt,
      'language': language,
    };
  }
}

// ============================================================
// CALL MODEL
// ============================================================
enum CallStatus { ringing, accepted, rejected, ended, missed }

class CallModel {
  final String callId;
  final String caller;
  final String receiver;
  final CallStatus status;
  final Map<String, dynamic> offer;
  final Map<String, dynamic> answer;
  final int startedAt;
  final int? endedAt;

  CallModel({
    required this.callId,
    required this.caller,
    required this.receiver,
    required this.status,
    this.offer = const {},
    this.answer = const {},
    required this.startedAt,
    this.endedAt,
  });

  factory CallModel.fromMap(Map<String, dynamic> map, String id) {
    return CallModel(
      callId: id,
      caller: map['caller'] ?? '',
      receiver: map['receiver'] ?? '',
      status: CallStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'ringing'),
        orElse: () => CallStatus.ringing,
      ),
      offer: Map<String, dynamic>.from(map['offer'] ?? {}),
      answer: Map<String, dynamic>.from(map['answer'] ?? {}),
      startedAt: map['started_at'] ?? 0,
      endedAt: map['ended_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'caller': caller,
      'receiver': receiver,
      'status': status.name,
      'offer': offer,
      'answer': answer,
      'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
    };
  }
}
