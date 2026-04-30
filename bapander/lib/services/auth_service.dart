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
    _client.auth.onAuthStateChange.listen((data) {
      notifyListeners();
    });
  }

  // ─── SEND OTP ─────────────────────────────────────────────
  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String error) onError,
    required Function() onCodeSent,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _client.auth.signInWithOtp(phone: phoneNumber);
      _isLoading = false;
      notifyListeners();
      onCodeSent();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      onError(e.toString());
    }
  }

  // ─── VERIFY OTP ───────────────────────────────────────────
  Future<bool> verifyOtp({
    required String phone,
    required String otp,
    required String name,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _client.auth.verifyOTP(
        phone: phone,
        token: otp,
        type: OtpType.sms,
      );

      if (response.user != null) {
        await _saveUserProfile(response.user!, name, phone);
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

  // ─── SAVE USER PROFILE ────────────────────────────────────
  Future<void> _saveUserProfile(User user, String name, String phone) async {
    final existing = await _client
        .from('users')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (existing == null) {
      await _client.from('users').insert({
        'id': user.id,
        'name': name,
        'phone': phone,
        'photo': '',
        'online': true,
        'last_seen': DateTime.now().toIso8601String(),
        'language': 'id',
      });
    } else {
      await _client.from('users').update({
        'online': true,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
    }
  }

  // ─── GET USER DATA ────────────────────────────────────────
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      return await _client
          .from('users')
          .select()
          .eq('id', uid)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  // ─── REALTIME USER STREAM ─────────────────────────────────
  Stream<Map<String, dynamic>?> userStream(String uid) {
    return _client
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((list) => list.isNotEmpty ? list.first : null);
  }

  // ─── SET ONLINE STATUS ────────────────────────────────────
  Future<void> setOnlineStatus(bool online) async {
    if (currentUid == null) return;
    await _client.from('users').update({
      'online': online,
      'last_seen': DateTime.now().toIso8601String(),
    }).eq('id', currentUid!);
  }

  // ─── SIGN OUT ─────────────────────────────────────────────
  Future<void> signOut() async {
    await setOnlineStatus(false);
    await _client.auth.signOut();
    notifyListeners();
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
