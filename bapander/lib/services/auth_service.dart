import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/supabase_config.dart';

class AuthService extends ChangeNotifier {
  final _client = SupabaseConfig.client;

  User? get currentUser => _client.auth.currentUser;
  String? get currentUid => _client.auth.currentUser?.id;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String _errorMessage = '';
  String get errorMessage => _errorMessage;

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
    _errorMessage = '';
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
      _errorMessage = e.toString();
      final msg = e.toString().toLowerCase();
      if (msg.contains('already registered') || msg.contains('already exists') || msg.contains('duplicate')) {
        _errorMessage = 'Email ini sudah terdaftar. Silakan login.';
      } else {
        if (msg.contains('already registered') || msg.contains('already exists')) {
        _errorMessage = 'Email ini sudah terdaftar. Silakan login.';
      } else if (msg.contains('invalid email')) {
        _errorMessage = 'Format email tidak valid.';
      } else if (msg.contains('weak password') || msg.contains('password')) {
        _errorMessage = 'Password minimal 6 karakter.';
      } else {
        _errorMessage = 'Gagal daftar. Coba lagi.';
      }
      }
    }
    return false;
  }

  // ─── RESET PASSWORD ──────────────────────────────────────
  Future<bool> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      print('Reset password error: \$e');
      return false;
    }
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

  // ─── CONTACTS ─────────────────────────────────────────────
  Future<void> saveContact(String myUid, String contactUid) async {
    try {
      await _client.from('contacts').upsert({
        'user_id': myUid,
        'contact_id': contactUid,
        'saved_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Save contact error: $e');
    }
  }

  Future<void> removeContact(String myUid, String contactUid) async {
    await _client.from('contacts')
        .delete()
        .eq('user_id', myUid)
        .eq('contact_id', contactUid);
  }

  Future<bool> isContact(String myUid, String contactUid) async {
    final data = await _client.from('contacts')
        .select()
        .eq('user_id', myUid)
        .eq('contact_id', contactUid)
        .maybeSingle();
    return data != null;
  }

  Stream<List<Map<String, dynamic>>> contactsStream(String myUid) {
    return _client
        .from('contacts')
        .stream(primaryKey: ['user_id', 'contact_id'])
        .eq('user_id', myUid)
        .order('saved_at', ascending: false)
        .map((list) => List<Map<String, dynamic>>.from(list));
  }

  // ─── FOLLOW SYSTEM ───────────────────────────────────────
  Future<void> followUser(String myUid, String targetUid) async {
    await _client.from('follows').upsert({
      'follower_id': myUid,
      'following_id': targetUid,
    });
  }

  Future<void> unfollowUser(String myUid, String targetUid) async {
    await _client.from('follows').delete()
        .eq('follower_id', myUid).eq('following_id', targetUid);
  }

  Future<bool> isFollowing(String myUid, String targetUid) async {
    final data = await _client.from('follows').select()
        .eq('follower_id', myUid).eq('following_id', targetUid).maybeSingle();
    return data != null;
  }

  Stream<List<Map<String, dynamic>>> followingStream(String myUid) {
    return _client.from('follows').stream(primaryKey: ['follower_id', 'following_id'])
        .eq('follower_id', myUid)
        .map((list) => List<Map<String, dynamic>>.from(list));
  }

  Future<int> getFollowersCount(String uid) async {
    final data = await _client.from('follows').select().eq('following_id', uid);
    return (data as List).length;
  }

  Future<int> getFollowingCount(String uid) async {
    final data = await _client.from('follows').select().eq('follower_id', uid);
    return (data as List).length;
  }

  Future<List<Map<String, dynamic>>> getAllUsers(String excludeUid) async {
    final data = await _client.from('users').select().neq('id', excludeUid).limit(50);
    return List<Map<String, dynamic>>.from(data);
  }
}
