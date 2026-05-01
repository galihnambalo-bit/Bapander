import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/supabase_config.dart';
import 'notification_service.dart';

class AuthService extends ChangeNotifier {
  final _client = SupabaseConfig.client;
  final _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

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
      final msg = e.toString().toLowerCase();
      if (msg.contains('already registered') || msg.contains('already exists')) {
        _errorMessage = 'Email ini sudah terdaftar. Silakan login.';
      } else if (msg.contains('invalid email')) {
        _errorMessage = 'Format email tidak valid.';
      } else if (msg.contains('password')) {
        _errorMessage = 'Password minimal 6 karakter.';
      } else { _errorMessage = e.toString(); }
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
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) { _isLoading = false; notifyListeners(); return false; }
      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) throw Exception('Gagal mendapat token Google');
      final res = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );
      if (res.user != null) {
        final uid = res.user!.id;
        final existing = await _client.from('users').select().eq('id', uid).maybeSingle();
        if (existing == null) {
          final gname = googleUser.displayName ?? 'User';
          final baseNick = gname.toLowerCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
          final nick = '${baseNick.length > 12 ? baseNick.substring(0, 12) : baseNick}_${uid.substring(0, 4)}';
          await _client.from('users').insert({
            'id': uid, 'name': gname, 'email': googleUser.email, 'nickname': nick,
            'photo': googleUser.photoUrl ?? '', 'phone': '', 'online': true,
            'last_seen': DateTime.now().toIso8601String(), 'language': 'id', 'anonymous_mode': false,
          });
        } else {
          await _client.from('users').update({'online': true, 'last_seen': DateTime.now().toIso8601String()}).eq('id', uid);
        }
        try { await NotificationService.setUserId(uid); } catch (_) {}
        _isLoading = false; notifyListeners(); return true;
      }
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
    try { await _googleSignIn.signOut(); } catch (_) {}
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
