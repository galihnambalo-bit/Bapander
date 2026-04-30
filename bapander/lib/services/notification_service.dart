import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../utils/supabase_config.dart';

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message: ${message.notification?.title}');
}

class NotificationService {
  static const String _oneSignalAppId = '256088f4-4a3c-4636-a036-968379c7e406';

  static Future<void> initialize() async {
    try {
      OneSignal.initialize(_oneSignalAppId);
      await OneSignal.Notifications.requestPermission(true);
    } catch (e) {
      print('OneSignal error: $e');
    }

    try {
      final fcm = FirebaseMessaging.instance;
      await fcm.requestPermission(alert: true, badge: true, sound: true);
      FirebaseMessaging.onMessage.listen((message) {
        print('FCM message: ${message.notification?.title}');
      });
    } catch (e) {
      print('FCM error: $e');
    }
  }

  static Future<void> setUserId(String userId) async {
    try { await OneSignal.login(userId); } catch (e) {}
  }

  static Future<void> logout() async {
    try { await OneSignal.logout(); } catch (e) {}
  }

  static Future<void> sendPushNotification({
    required String toUserId,
    required String title,
    required String body,
  }) async {
    try {
      await SupabaseConfig.client.functions.invoke('send-notification', body: {
        'to_user_id': toUserId,
        'title': title,
        'body': body,
      });
    } catch (e) {
      print('Send notification error: $e');
    }
  }
}
