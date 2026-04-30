import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../utils/supabase_config.dart';
import '../models/status_model.dart';

class StatusService extends ChangeNotifier {
  final _client = SupabaseConfig.client;
  final _uuid = const Uuid();

  // ─── CREATE TEXT STATUS ───────────────────────────────────
  Future<void> createTextStatus({
    required String userId,
    required String userName,
    required String userPhoto,
    required String text,
    required String backgroundColor,
    required String fontColor,
    bool isAnonymous = false,
  }) async {
    final now = DateTime.now();
    await _client.from('statuses').insert({
      'id': _uuid.v4(),
      'user_id': userId,
      'user_name': userName,
      'user_photo': userPhoto,
      'type': 'text',
      'content': text,
      'background_color': backgroundColor,
      'font_color': fontColor,
      'created_at': now.toIso8601String(),
      'expires_at': now.add(const Duration(hours: 24)).toIso8601String(),
      'viewed_by': [],
      'is_anonymous': isAnonymous,
    });
    notifyListeners();
  }

  // ─── CREATE IMAGE STATUS ──────────────────────────────────
  Future<void> createImageStatus({
    required String userId,
    required String userName,
    required String userPhoto,
    required File imageFile,
    String? caption,
    bool isAnonymous = false,
  }) async {
    final id = _uuid.v4();
    final path = 'statuses/$userId/$id.jpg';

    await _client.storage.from('media').upload(path, imageFile);
    final imageUrl = _client.storage.from('media').getPublicUrl(path);

    final now = DateTime.now();
    await _client.from('statuses').insert({
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_photo': userPhoto,
      'type': 'image',
      'content': imageUrl,
      'caption': caption,
      'created_at': now.toIso8601String(),
      'expires_at': now.add(const Duration(hours: 24)).toIso8601String(),
      'viewed_by': [],
      'is_anonymous': isAnonymous,
    });
    notifyListeners();
  }

  // ─── GET ALL ACTIVE STATUSES ──────────────────────────────
  Stream<List<StatusModel>> statusesStream() {
    return _client
        .from('statuses')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((list) => list
            .map((d) => StatusModel.fromMap(d, d['id']))
            .where((s) => s.isActive)
            .toList());
  }

  // ─── GET MY STATUSES ──────────────────────────────────────
  Stream<List<StatusModel>> myStatusesStream(String userId) {
    return _client
        .from('statuses')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((list) => list
            .map((d) => StatusModel.fromMap(d, d['id']))
            .where((s) => s.isActive)
            .toList());
  }

  // ─── MARK AS VIEWED ──────────────────────────────────────
  Future<void> markAsViewed(String statusId, String viewerId) async {
    final status = await _client
        .from('statuses')
        .select('viewed_by')
        .eq('id', statusId)
        .maybeSingle();

    if (status == null) return;
    final viewedBy = List<String>.from(status['viewed_by'] ?? []);
    if (!viewedBy.contains(viewerId)) {
      viewedBy.add(viewerId);
      await _client.from('statuses')
          .update({'viewed_by': viewedBy}).eq('id', statusId);
    }
  }

  // ─── DELETE STATUS ────────────────────────────────────────
  Future<void> deleteStatus(String statusId) async {
    await _client.from('statuses').delete().eq('id', statusId);
    notifyListeners();
  }

  // ─── GROUP STATUSES BY USER ───────────────────────────────
  Map<String, List<StatusModel>> groupByUser(List<StatusModel> statuses) {
    final map = <String, List<StatusModel>>{};
    for (var s in statuses) {
      map.putIfAbsent(s.userId, () => []).add(s);
    }
    return map;
  }
}
