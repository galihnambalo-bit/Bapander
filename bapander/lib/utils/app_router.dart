import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/otp_screen.dart';
import '../screens/home_screen.dart';
import '../screens/chat_room_screen.dart';
import '../screens/group_screen.dart';
import '../screens/create_group_screen.dart';
import '../screens/call_screen.dart';
import '../screens/incoming_call_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/media_viewer_screen.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final auth = context.read<AuthService>();
      final isLoggedIn = auth.currentUser != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/otp' ||
          state.matchedLocation == '/splash';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && state.matchedLocation == '/login') return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final phone = state.extra as String? ?? '';
          return OtpScreen(phoneNumber: phone);
        },
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/chat/:chatId',
        builder: (context, state) {
          final chatId = state.pathParameters['chatId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ChatRoomScreen(
            chatId: chatId,
            receiverName: extra['name'] ?? '',
            receiverPhoto: extra['photo'] ?? '',
            receiverUid: extra['uid'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/group/:groupId',
        builder: (context, state) {
          final groupId = state.pathParameters['groupId']!;
          return GroupScreen(groupId: groupId);
        },
      ),
      GoRoute(
        path: '/create-group',
        builder: (context, state) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: '/call/:callId',
        builder: (context, state) {
          final callId = state.pathParameters['callId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CallScreen(
            callId: callId,
            receiverName: extra['name'] ?? '',
            receiverPhoto: extra['photo'] ?? '',
            isCaller: extra['isCaller'] ?? true,
          );
        },
      ),
      GoRoute(
        path: '/incoming-call/:callId',
        builder: (context, state) {
          final callId = state.pathParameters['callId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return IncomingCallScreen(
            callId: callId,
            callerName: extra['callerName'] ?? '',
            callerPhoto: extra['callerPhoto'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/media',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return MediaViewerScreen(
            mediaUrl: extra['url'] ?? '',
            mediaType: extra['type'] ?? 'image',
          );
        },
      ),
    ],
  );
}
