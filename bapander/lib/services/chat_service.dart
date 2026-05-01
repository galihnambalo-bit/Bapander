import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../utils/supabase_config.dart';
import 'notification_service.dart';
import '../models/models.dart';

class ChatService extends ChangeNotifier {
  final _client = SupabaseConfig.client;
  final _uuid = const Uuid();

  // ─── GET OR CREATE PRIVATE CHAT ───────────────────────────
  Future<String> getOrCreateChat(String myUid, String otherUid) async {
    final members = [myUid, otherUid]..sort();
    final chatId = members.join('_');

    final existing = await _client
        .from('chats')
        .select()
        .eq('id', chatId)
        .maybeSingle();

    if (existing == null) {
      await _client.from('chats').insert({
        'id': chatId,
        'type': 'private',
        'members': members,
        'last_message': '',
        'last_timestamp': DateTime.now().toIso8601String(),
      });
    }
    return chatId;
  }

  // ─── SEND MESSAGE ─────────────────────────────────────────
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    String type = 'text',
    String mediaUrl = '',
    int? duration,
    Map<String, dynamic>? replyTo,
  }) async {
    final msgId = _uuid.v4();

    await _client.from('messages').insert({
      'id': msgId,
      'chat_id': chatId,
      'sender': senderId,
        'reply_to': replyTo,
      'text': text,
      'topic': type,
      'media_url': mediaUrl,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'sent',
      if (duration != null) 'duration': duration,
    });

    // Kirim notifikasi push ke penerima
    try {
      final chatData = await _client.from('chats').select('members').eq('id', chatId).maybeSingle();
      final members = List<String>.from(chatData?['members'] ?? []);
      final receiverId = members.firstWhere((m) => m != senderId, orElse: () => '');
      if (receiverId.isNotEmpty) {
        final sender = await _client.from('users').select('name').eq('id', senderId).maybeSingle();
        final senderName = sender?['name'] ?? 'Seseorang';
        final notifBody = type == 'text' ? text
            : type == 'image' ? '📷 Foto'
            : type == 'voice' ? '🎤 Voice note'
            : type == 'sticker' ? '😊 Sticker'
            : type == 'document' ? '📄 Dokumen'
            : 'Pesan baru';
        await NotificationService.sendPushNotification(
          toUserId: receiverId,
          title: senderName,
          body: notifBody,
        );
      }
    } catch (e) {
      print('Notif error: $e');
    }

    await _client.from('chats').update({
      'last_message': type == 'text' ? text : '[$type]',
      'last_timestamp': DateTime.now().toIso8601String(),
    }).eq('id', chatId);
  }

  // ─── MESSAGES STREAM ──────────────────────────────────────
  Stream<List<Map<String, dynamic>>> messagesStream(String chatId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('timestamp', ascending: true)
        .map((list) => List<Map<String, dynamic>>.from(list));
  }

  // ─── CHAT LIST STREAM ─────────────────────────────────────
  Stream<List<Map<String, dynamic>>> chatListStream(String uid) {
    return _client
        .from('chats')
        .stream(primaryKey: ['id'])
        .order('last_timestamp', ascending: false)
        .map((list) => list
            .where((c) => (c['members'] as List).contains(uid))
            .toList());
  }

  // ─── UPLOAD IMAGE ─────────────────────────────────────────
  Future<String> uploadImage(File imageFile, String chatId) async {
    final fileName = '${_uuid.v4()}.jpg';
    final path = 'chats/$chatId/$fileName';

    await _client.storage
        .from('media')
        .upload(path, imageFile);

    return _client.storage.from('media').getPublicUrl(path);
  }

  // ─── UPLOAD VOICE NOTE ────────────────────────────────────
  Future<String> uploadVoiceNote(File audioFile, String chatId) async {
    final fileName = '${_uuid.v4()}.aac';
    final path = 'voices/$chatId/$fileName';

    await _client.storage
        .from('media')
        .upload(path, audioFile);

    return _client.storage.from('media').getPublicUrl(path);
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

    await _client.from('groups').insert({
      'id': groupId,
      'name': name,
      'photo': '',
      'description': description,
      'members': members,
      'admin': [creatorUid],
      'created_at': DateTime.now().toIso8601String(),
      'language': language,
    });

    await _client.from('chats').insert({
      'id': groupId,
      'type': 'group',
      'group_id': groupId,
      'members': members,
      'last_message': '',
      'last_timestamp': DateTime.now().toIso8601String(),
    });

    return groupId;
  }

  // ─── GROUPS STREAM ────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> groupsStream(String uid) {
    return _client
        .from('groups')
        .stream(primaryKey: ['id'])
        .map((list) => list
            .where((g) => (g['members'] as List).contains(uid))
            .toList());
  }

  // ─── DELETE CHAT ──────────────────────────────────────────
  Future<void> deleteChat(String chatId) async {
    await _client.from('messages').delete().eq('chat_id', chatId);
    await _client.from('chats').delete().eq('id', chatId);
  }

  // ─── MARK MESSAGES AS READ ───────────────────────────────
  Future<void> markMessagesAsRead(String chatId, String myUid) async {
    await _client.from('messages')
        .update({'status': 'read'})
        .eq('chat_id', chatId)
        .neq('sender', myUid)
        .neq('status', 'read');
  }

  // ─── UPDATE STATUS DELIVERED ──────────────────────────────
  Future<void> markDelivered(String chatId, String myUid) async {
    await _client.from('messages')
        .update({'status': 'delivered'})
        .eq('chat_id', chatId)
        .neq('sender', myUid)
        .eq('status', 'sent');
  }

  // ─── GET ALL USERS ────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllUsers(String excludeUid) async {
    final data = await _client
        .from('users')
        .select()
        .neq('id', excludeUid)
        .limit(50);
    return List<Map<String, dynamic>>.from(data);
  }
}
