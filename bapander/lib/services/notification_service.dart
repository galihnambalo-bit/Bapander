import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../utils/supabase_config.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message: ${message.notification?.title}');
}

class NotificationService {
  static const String _oneSignalAppId = '256088f4-4a3c-4636-a036-968379c7e406';

  static Future<void> initialize() async {
    try {
      OneSignal.initialize(_oneSignalAppId);
      OneSignal.Notifications.requestPermission(true);
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        print('OneSignal foreground notification: ${event.notification.body}');
      });
      OneSignal.Notifications.addClickListener((event) {
        print('OneSignal notification clicked: ${event.notification.title}');
      });
    } catch (e) {
      print('OneSignal error: $e');
    }

    try {
      final fcm = FirebaseMessaging.instance;
      await fcm.requestPermission(alert: true, badge: true, sound: true);
      FirebaseMessaging.onMessage.listen((message) {
        print('FCM message: ${message.notification?.title}');
      });
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        print('FCM opened app via notification: ${message.notification?.title}');
      });
    } catch (e) {
      print('FCM error: $e');
    }
  }

  static Future<void> setUserId(String userId) async {
    try {
      await OneSignal.login(userId);
      print('OneSignal login: $userId');
    } catch (e) {
      print('OneSignal login error: $e');
    }
  }

  static Future<void> logout() async {
    try {
      await OneSignal.logout();
    } catch (e) {
      print('OneSignal logout error: $e');
    }
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
