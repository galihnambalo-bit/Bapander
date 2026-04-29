import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import 'chat_list_tab.dart';
import 'community_tab.dart';
import 'marketplace/marketplace_tab.dart';
import 'auction/auction_tab.dart';
import 'calls_tab.dart';
import 'profile_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final List<Widget> _tabs = const [
    ChatListTab(), CommunityTab(), MarketplaceTab(),
    AuctionTab(), CallsTab(), ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 10,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.chat_bubble_outline_rounded), activeIcon: const Icon(Icons.chat_bubble_rounded), label: loc.t('chat')),
          BottomNavigationBarItem(icon: const Icon(Icons.groups_outlined), activeIcon: const Icon(Icons.groups_rounded), label: loc.t('community')),
          const BottomNavigationBarItem(icon: Icon(Icons.storefront_outlined), activeIcon: Icon(Icons.storefront_rounded), label: 'Toko'),
          const BottomNavigationBarItem(icon: Icon(Icons.gavel_outlined), activeIcon: Icon(Icons.gavel_rounded), label: 'Lelang'),
          BottomNavigationBarItem(icon: const Icon(Icons.call_outlined), activeIcon: const Icon(Icons.call_rounded), label: loc.t('calls')),
          BottomNavigationBarItem(icon: const Icon(Icons.person_outline_rounded), activeIcon: const Icon(Icons.person_rounded), label: loc.t('profile')),
        ],
      ),
    );
  }
}
