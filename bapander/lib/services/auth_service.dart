import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/supabase_config.dart';

class AuthService extends ChangeNotifier {
  final _client = SupabaseConfig.client;

  User? get currentUser => _client.auth.currentUser;
  String? get currentUid => _client.auth.currentUser?.id;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  AuthService() {
    _client.auth.onAuthStateChange.listen((_) => notifyListeners());
  }

  // DAFTAR
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _client.auth.signUp(email: email, password: password);
      if (res.user != null) {
        await _client.from('users').insert({
          'id': res.user!.id,
          'name': name,
          'phone': '',
          'photo': '',
          'online': true,
          'last_seen': DateTime.now().toIso8601String(),
          'language': 'id',
        });
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  // LOGIN
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.user != null) {
        await _client.from('users').update({
          'online': true,
          'last_seen': DateTime.now().toIso8601String(),
        }).eq('id', res.user!.id);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      return await _client.from('users').select().eq('id', uid).maybeSingle();
    } catch (_) { return null; }
  }

  Stream<Map<String, dynamic>?> userStream(String uid) {
    return _client.from('users').stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((list) => list.isNotEmpty ? list.first : null);
  }

  Future<void> setOnlineStatus(bool online) async {
    if (currentUid == null) return;
    await _client.from('users').update({
      'online': online,
      'last_seen': DateTime.now().toIso8601String(),
    }).eq('id', currentUid!);
  }

  Future<void> signOut() async {
    await setOnlineStatus(false);
    await _client.auth.signOut();
    notifyListeners();
  }

  // ─── SEARCH USERS ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> searchUsers(String query, String excludeUid) async {
    try {
      final data = await _client
          .from('users')
          .select()
          .neq('id', excludeUid)
          .or('name.ilike.%$query%')
          .limit(20);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllUsers(String excludeUid) async {
    final data = await _client.from('users').select().neq('id', excludeUid).limit(50);
    return List<Map<String, dynamic>>.from(data);
  }
}
