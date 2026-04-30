import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';

import '../screens/home_screen.dart';
import '../screens/chat_room_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/contacts_screen.dart';
import '../screens/status/status_tab.dart';
import '../screens/status/status_viewer_screen.dart';
import '../screens/status/create_status_screen.dart';
import '../screens/nearby/nearby_screen.dart';
import '../screens/other_screens.dart';
import '../screens/marketplace/marketplace_tab.dart';
import '../screens/marketplace/create_product_screen.dart';
import '../screens/auction/auction_tab.dart';
import '../screens/auction/auction_detail_screen.dart';
import '../screens/auction/create_auction_screen.dart';

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
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(
        path: '/otp',
      ),
      GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
      GoRoute(
        path: '/chat/:chatId',
        builder: (c, s) {
          final chatId = s.pathParameters['chatId']!;
          final extra = s.extra as Map<String, dynamic>? ?? {};
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
        builder: (c, s) => GroupScreen(groupId: s.pathParameters['groupId']!),
      ),
      GoRoute(path: '/create-group', builder: (c, s) => const CreateGroupScreen()),
      GoRoute(
        path: '/call/:callId',
        builder: (c, s) {
          final extra = s.extra as Map<String, dynamic>? ?? {};
          return CallScreen(
            callId: s.pathParameters['callId']!,
            receiverName: extra['name'] ?? '',
            receiverPhoto: extra['photo'] ?? '',
            isCaller: extra['isCaller'] ?? true,
          );
        },
      ),
      GoRoute(
        path: '/incoming-call/:callId',
        builder: (c, s) {
          final extra = s.extra as Map<String, dynamic>? ?? {};
          return IncomingCallScreen(
            callId: s.pathParameters['callId']!,
            callerName: extra['callerName'] ?? '',
            callerPhoto: extra['callerPhoto'] ?? '',
          );
        },
      ),
      GoRoute(path: '/status/create', builder: (c, s) => const CreateStatusScreen()),
      GoRoute(
        path: '/status/view',
        builder: (c, s) {
          final extra = s.extra as Map<String, dynamic>? ?? {};
          final statuses = extra['statuses'] as List? ?? [];
          final index = extra['index'] as int? ?? 0;
          return StatusViewerScreen(
            statuses: statuses.cast(),
            initialIndex: index,
          );
        },
      ),
      GoRoute(path: '/nearby', builder: (c, s) => const NearbyScreen()),
      GoRoute(path: '/contacts', builder: (c, s) => const ContactsScreen()),
      GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
      GoRoute(
        path: '/media',
        builder: (c, s) {
          final extra = s.extra as Map<String, dynamic>? ?? {};
          return MediaViewerScreen(
            mediaUrl: extra['url'] ?? '',
            mediaType: extra['type'] ?? 'image',
          );
        },
      ),
      GoRoute(path: '/marketplace/create', builder: (c, s) => const CreateProductScreen()),
      GoRoute(
        path: '/marketplace/product/:productId',
        builder: (c, s) => const Scaffold(body: Center(child: Text('Detail Produk'))),
      ),
      GoRoute(path: '/auction/create', builder: (c, s) => const CreateAuctionScreen()),
      GoRoute(
        path: '/auction/:auctionId',
        builder: (c, s) => AuctionDetailScreen(auctionId: s.pathParameters['auctionId']!),
      ),
    ],
  );
}
