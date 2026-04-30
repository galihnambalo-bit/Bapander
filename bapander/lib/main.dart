import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';

import 'utils/supabase_config.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/call_service.dart';
import 'services/location_service.dart';
import 'services/status_service.dart';
import 'services/admob_service.dart';
import 'services/notification_service.dart';
import 'services/marketplace_service.dart';
import 'services/auction_service.dart';
import 'localization/app_localizations.dart';
import 'utils/app_router.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AdMobService().initialize();
  await NotificationService.initialize();

  await Firebase.initializeApp();
  
  // FCM background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const BapanderApp());
}

class BapanderApp extends StatelessWidget {
  const BapanderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ChatService()),
        ChangeNotifierProvider(create: (_) => CallService()),
        ChangeNotifierProvider(create: (_) => MarketplaceService()),
        ChangeNotifierProvider(create: (_) => AuctionService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
        ChangeNotifierProvider(create: (_) => StatusService()),
        ChangeNotifierProvider(create: (_) => LocalizationProvider()),
      ],
      child: Consumer<LocalizationProvider>(
        builder: (context, locProvider, _) {
          return MaterialApp.router(
            title: 'Bapander',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}
