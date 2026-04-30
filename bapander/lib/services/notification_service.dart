import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/supabase_config.dart';

class NotificationService {
  static const String _oneSignalAppId = '256088f4-4a3c-4636-a036-968379c7e406';

  static Future<void> initialize() async {
    try {
      // Init OneSignal
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize(_oneSignalAppId);
      await OneSignal.Notifications.requestPermission(true);
    } catch (e) {
      print('OneSignal init error: \$e');
    }

    // Init FCM
    final fcm = FirebaseMessaging.instance;
    await fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get FCM token
    final token = await fcm.getToken();
    print('FCM Token: $token');

    // Listen foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message: ${message.notification?.title}');
    });
  }

  static Future<void> setUserId(String userId) async {
    await OneSignal.login(userId);
  }

  static Future<void> logout() async {
    await OneSignal.logout();
  }

  // Kirim notifikasi via Supabase Edge Function
  static Future<void> sendPushNotification({
    required String toUserId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await SupabaseConfig.client.functions.invoke(
        'send-notification',
        body: {
          'to_user_id': toUserId,
          'title': title,
          'body': body,
          'data': data ?? {},
        },
      );
    } catch (e) {
      print('Send notification error: $e');
    }
  }
}
