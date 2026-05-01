import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/supabase_config.dart';
import 'notification_service.dart';

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

  Future<bool> register({required String name, required String email, required String password}) async {
    _isLoading = true; _errorMessage = ''; notifyListeners();
    try {
      final res = await _client.auth.signUp(email: email, password: password);
      if (res.user != null) {
        final baseNick = name.toLowerCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
        final nick = '${baseNick.length > 12 ? baseNick.substring(0, 12) : baseNick}_${res.user!.id.substring(0, 4)}';
        await _client.from('users').upsert({
          'id': res.user!.id, 'name': name, 'email': email, 'nickname': nick,
          'phone': '', 'photo': '', 'online': true,
          'last_seen': DateTime.now().toIso8601String(), 'language': 'id', 'anonymous_mode': false,
        });
        try { await NotificationService.setUserId(res.user!.id); } catch (_) {}
        _isLoading = false; notifyListeners(); return true;
      }
    } catch (e) {
      _isLoading = false;
      print('REGISTER ERROR: $e');
      final msg = e.toString().toLowerCase();
      if (msg.contains('already registered') || msg.contains('already exists') ||
          msg.contains('user already registered') || msg.contains('duplicate')) {
        _errorMessage = 'Email ini sudah terdaftar. Silakan login.';
      } else if (msg.contains('invalid email') || msg.contains('unable to validate')) {
        _errorMessage = 'Format email tidak valid. Gunakan email asli.';
      } else if (msg.contains('password') || msg.contains('weak')) {
        _errorMessage = 'Password terlalu lemah. Minimal 6 karakter.';
      } else if (msg.contains('network') || msg.contains('connection')) {
        _errorMessage = 'Gagal koneksi. Cek internet kamu.';
      } else {
        _errorMessage = 'Error: ${e.toString()}';
      }
      notifyListeners();
    }
    return false;
  }

  Future<bool> login({required String email, required String password}) async {
    _isLoading = true; _errorMessage = ''; notifyListeners();
    try {
      final res = await _client.auth.signInWithPassword(email: email, password: password);
      if (res.user != null) {
        await _client.from('users').update({
          'online': true, 'email': email,
          'last_seen': DateTime.now().toIso8601String(),
        }).eq('id', res.user!.id);
        try { await NotificationService.setUserId(res.user!.id); } catch (_) {}
        _isLoading = false; notifyListeners(); return true;
      }
    } catch (e) {
      _isLoading = false;
      final msg = e.toString().toLowerCase();
      if (msg.contains('invalid login') || msg.contains('invalid credentials') || msg.contains('wrong')) {
        _errorMessage = 'Email atau password salah.';
      } else if (msg.contains('not confirmed') || msg.contains('email not confirmed')) {
        _errorMessage = 'login_not_confirmed';
      } else { _errorMessage = e.toString(); }
      notifyListeners();
    }
    return false;
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true; _errorMessage = ''; notifyListeners();
    try {
      // Supabase OAuth - buka browser Google login
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.bapander://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      // Tunggu auth state berubah
      _client.auth.onAuthStateChange.listen((data) async {
        if (data.event == AuthChangeEvent.signedIn && data.session?.user != null) {
          final uid = data.session!.user.id;
          final email = data.session!.user.email ?? '';
          final meta = data.session!.user.userMetadata;
          final gname = meta?['full_name'] ?? meta?['name'] ?? 'User';
          final photo = meta?['avatar_url'] ?? meta?['picture'] ?? '';

          final existing = await _client.from('users').select().eq('id', uid).maybeSingle();
          if (existing == null) {
            final baseNick = gname.toString().toLowerCase()
                .replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
            final nick = '${baseNick.length > 12 ? baseNick.substring(0, 12) : baseNick}_${uid.substring(0, 4)}';
            await _client.from('users').insert({
              'id': uid, 'name': gname, 'nickname': nick,
              'photo': photo, 'phone': '', 'online': true,
              'last_seen': DateTime.now().toIso8601String(),
              'language': 'id', 'anonymous_mode': false,
            });
            try { await _client.from('users').update({'email': email}).eq('id', uid); } catch (_) {}
          } else {
            await _client.from('users').update({
              'online': true, 'last_seen': DateTime.now().toIso8601String(),
            }).eq('id', uid);
          }
          try { await NotificationService.setUserId(uid); } catch (_) {}
        }
      });
      _isLoading = false; notifyListeners(); return true;
    } catch (e) {
      _isLoading = false; _errorMessage = 'Login Google gagal: $e'; notifyListeners();
    }
    return false;
  }

  Future<bool> resetPassword(String email) async {
    try { await _client.auth.resetPasswordForEmail(email); return true; } catch (_) { return false; }
  }

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try { return await _client.from('users').select().eq('id', uid).maybeSingle(); } catch (_) { return null; }
  }

  Stream<Map<String, dynamic>?> userStream(String uid) {
    return _client.from('users').stream(primaryKey: ['id']).eq('id', uid)
        .map((list) => list.isNotEmpty ? list.first : null);
  }

  Future<void> setOnlineStatus(bool online) async {
    if (currentUid == null) return;
    await _client.from('users').update({'online': online, 'last_seen': DateTime.now().toIso8601String()}).eq('id', currentUid!);
  }

  Future<void> signOut() async {
    await setOnlineStatus(false);
    await _client.auth.signOut();
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query, String excludeUid) async {
    try {
      final data = await _client.from('users').select().neq('id', excludeUid)
          .or('name.ilike.%$query%,nickname.ilike.%$query%').limit(20);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) { return []; }
  }

  Future<Map<String, dynamic>?> searchByNickname(String nickname) async {
    try { return await _client.from('users').select().eq('nickname', nickname.toLowerCase()).maybeSingle(); } catch (_) { return null; }
  }

  Future<List<Map<String, dynamic>>> getAllUsers(String excludeUid) async {
    try {
      final data = await _client.from('users').select().neq('id', excludeUid).limit(100);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) { return []; }
  }

  Future<void> saveContact(String myUid, String contactUid) async {
    try { await _client.from('contacts').upsert({'user_id': myUid, 'contact_id': contactUid, 'saved_at': DateTime.now().toIso8601String()}); } catch (_) {}
  }

  Future<void> removeContact(String myUid, String contactUid) async {
    await _client.from('contacts').delete().eq('user_id', myUid).eq('contact_id', contactUid);
  }

  Future<bool> isContact(String myUid, String contactUid) async {
    final data = await _client.from('contacts').select().eq('user_id', myUid).eq('contact_id', contactUid).maybeSingle();
    return data != null;
  }

  Stream<List<Map<String, dynamic>>> contactsStream(String myUid) {
    return _client.from('contacts').stream(primaryKey: ['user_id', 'contact_id']).eq('user_id', myUid)
        .map((list) => List<Map<String, dynamic>>.from(list));
  }

  Future<void> followUser(String myUid, String targetUid) async {
    await _client.from('follows').upsert({'follower_id': myUid, 'following_id': targetUid});
  }

  Future<void> unfollowUser(String myUid, String targetUid) async {
    await _client.from('follows').delete().eq('follower_id', myUid).eq('following_id', targetUid);
  }

  Future<bool> isFollowing(String myUid, String targetUid) async {
    final data = await _client.from('follows').select().eq('follower_id', myUid).eq('following_id', targetUid).maybeSingle();
    return data != null;
  }

  Stream<List<Map<String, dynamic>>> followingStream(String myUid) {
    return _client.from('follows').stream(primaryKey: ['follower_id', 'following_id']).eq('follower_id', myUid)
        .map((list) => List<Map<String, dynamic>>.from(list));
  }

  Future<int> getFollowersCount(String uid) async {
    try { final d = await _client.from('follows').select().eq('following_id', uid); return (d as List).length; } catch (_) { return 0; }
  }

  Future<int> getFollowingCount(String uid) async {
    try { final d = await _client.from('follows').select().eq('follower_id', uid); return (d as List).length; } catch (_) { return 0; }
  }
}
