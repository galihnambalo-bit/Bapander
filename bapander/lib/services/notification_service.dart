import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class NotificationService extends ChangeNotifier {
  // Daftar di https://onesignal.com (GRATIS)
  // Ganti dengan App ID kamu dari OneSignal
  static const String _oneSignalAppId = 'YOUR_ONESIGNAL_APP_ID';

  static Future<void> initialize() async {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(_oneSignalAppId);
    await OneSignal.Notifications.requestPermission(true);
  }

  static Future<void> setUserId(String userId) async {
    await OneSignal.login(userId);
  }

  static Future<void> logout() async {
    await OneSignal.logout();
  }

  static Future<void> sendNotification({
    required String toUserId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    // Kirim via Supabase Edge Function
    // (setup di Supabase dashboard)
    print('Send notif to: $toUserId - $title: $message');
  }
}
