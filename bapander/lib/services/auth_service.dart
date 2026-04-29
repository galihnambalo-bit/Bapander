import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  String? get currentUid => _auth.currentUser?.uid;

  String? _verificationId;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Send OTP
  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String error) onError,
    required Function() onCodeSent,
  }) async {
    _isLoading = true;
    notifyListeners();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        _isLoading = false;
        notifyListeners();
      },
      verificationFailed: (FirebaseAuthException e) {
        _isLoading = false;
        notifyListeners();
        onError(e.message ?? 'Verifikasi gagal');
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        _isLoading = false;
        notifyListeners();
        onCodeSent();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
      timeout: const Duration(seconds: 60),
    );
  }

  // Verify OTP
  Future<bool> verifyOtp({
    required String otp,
    required String name,
  }) async {
    if (_verificationId == null) return false;
    _isLoading = true;
    notifyListeners();

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      final result = await _auth.signInWithCredential(credential);
      if (result.user != null) {
        await _saveUser(result.user!, name);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
    return false;
  }

  Future<void> _saveUser(User user, String name) async {
    final docRef = _db.collection('users').doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'name': name,
        'phone': user.phoneNumber ?? '',
        'photo': '',
        'online': true,
        'last_seen': DateTime.now().millisecondsSinceEpoch,
        'language': 'id',
        'created_at': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.update({
        'online': true,
        'last_seen': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  Future<void> setOnlineStatus(bool online) async {
    if (currentUid == null) return;
    await _db.collection('users').doc(currentUid).update({
      'online': online,
      'last_seen': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> signOut() async {
    await setOnlineStatus(false);
    await _auth.signOut();
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  Stream<DocumentSnapshot> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }
}
