import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

class ChatService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  // ─── GET OR CREATE PRIVATE CHAT ───────────────────────────
  Future<String> getOrCreateChat(String myUid, String otherUid) async {
    final members = [myUid, otherUid]..sort();
    final chatId = members.join('_');

    final doc = await _db.collection('chats').doc(chatId).get();
    if (!doc.exists) {
      await _db.collection('chats').doc(chatId).set({
        'type': 'private',
        'members': members,
        'last_message': '',
        'last_timestamp': 0,
        'unread_count': {myUid: 0, otherUid: 0},
      });
    }
    return chatId;
  }

  // ─── SEND MESSAGE ─────────────────────────────────────────
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    MessageType type = MessageType.text,
    String mediaUrl = '',
    int? duration,
  }) async {
    final msgId = _uuid.v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final msgData = {
      'sender': senderId,
      'text': text,
      'type': type.name,
      'media_url': mediaUrl,
      'timestamp': timestamp,
      'status': 'sent',
      if (duration != null) 'duration': duration,
    };

    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(msgId)
        .set(msgData);

    await _db.collection('chats').doc(chatId).update({
      'last_message': type == MessageType.text ? text : '[${type.name}]',
      'last_timestamp': timestamp,
    });
  }

  // ─── MESSAGES STREAM ──────────────────────────────────────
  Stream<List<MessageModel>> messagesStream(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ─── CHAT LIST STREAM ────────────────────────────────────
  Stream<List<ChatModel>> chatListStream(String uid) {
    return _db
        .collection('chats')
        .where('members', arrayContains: uid)
        .orderBy('last_timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ChatModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ─── UPLOAD IMAGE ─────────────────────────────────────────
  Future<String> uploadImage(File imageFile, String chatId) async {
    // Compress image
    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return '';

    final resized = img.copyResize(decoded, width: 800);
    final compressed = img.encodeJpg(resized, quality: 75);

    final tmpDir = await getTemporaryDirectory();
    final tmpFile = File('${tmpDir.path}/compressed_${_uuid.v4()}.jpg');
    await tmpFile.writeAsBytes(compressed);

    final ref = _storage.ref('chats/$chatId/${_uuid.v4()}.jpg');
    await ref.putFile(tmpFile);
    return await ref.getDownloadURL();
  }

  // ─── UPLOAD VOICE NOTE ───────────────────────────────────
  Future<String> uploadVoiceNote(File audioFile, String chatId) async {
    final ref = _storage.ref('voices/$chatId/${_uuid.v4()}.aac');
    await ref.putFile(audioFile);
    return await ref.getDownloadURL();
  }

  // ─── UPDATE MESSAGE STATUS ───────────────────────────────
  Future<void> updateMessageStatus(
      String chatId, String msgId, MessageStatus status) async {
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(msgId)
        .update({'status': status.name});
  }

  // ─── CREATE GROUP ─────────────────────────────────────────
  Future<String> createGroup({
    required String name,
    required String creatorUid,
    required List<String> memberUids,
    String description = '',
    String language = 'id',
  }) async {
    final groupId = _uuid.v4();
    final members = [creatorUid, ...memberUids];

    await _db.collection('groups').doc(groupId).set({
      'name': name,
      'photo': '',
      'description': description,
      'members': members,
      'admin': [creatorUid],
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'language': language,
    });

    // Create group chat
    await _db.collection('chats').doc(groupId).set({
      'type': 'group',
      'group_id': groupId,
      'members': members,
      'last_message': '',
      'last_timestamp': 0,
      'unread_count': {for (var m in members) m: 0},
    });

    return groupId;
  }

  // ─── GROUP STREAM ─────────────────────────────────────────
  Stream<List<GroupModel>> groupsStream(String uid) {
    return _db
        .collection('groups')
        .where('members', arrayContains: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => GroupModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ─── CONTACTS / SEARCH USERS ─────────────────────────────
  Future<List<Map<String, dynamic>>> searchUsers(String phone) async {
    final snap = await _db
        .collection('users')
        .where('phone', isEqualTo: phone)
        .limit(5)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> getAllUsers(String excludeUid) async {
    final snap = await _db.collection('users').limit(50).get();
    return snap.docs
        .where((d) => d.id != excludeUid)
        .map((d) => {'id': d.id, ...d.data()})
        .toList();
  }
}
