import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';


import '../services/auth_service.dart';
import '../localization/app_localizations.dart';
import '../utils/app_theme.dart';
import '../widgets/avatar_widget.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final loc = context.watch<LocalizationProvider>();
    final myUid = auth.currentUid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('profile')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: auth.getUserData(myUid),
        builder: (context, snap) {
          final data = snap.data;
          final name = data?['name'] ?? '';
          final phone = data?['phone'] ?? '';
          final photo = data?['photo'] ?? '';

          return ListView(
            children: [
              // Profile header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        AvatarWidget(name: name, photoUrl: photo, size: 80),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.edit_rounded,
                                size: 13, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: const TextStyle(
                          color: Color(0xFF888780), fontSize: 14),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Menu items
              _MenuItem(
                icon: Icons.language_rounded,
                title: loc.t('language'),
                subtitle: AppLanguage.values
                    .firstWhere(
                      (l) => l.code == loc.languageCode,
                      orElse: () => AppLanguage.id,
                    )
                    .label,
                onTap: () => context.push('/settings'),
              ),
              _MenuItem(
                icon: Icons.notifications_outlined,
                title: 'Notifikasi',
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.privacy_tip_outlined,
                title: 'Privasi',
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.help_outline_rounded,
                title: 'Bantuan',
                onTap: () {},
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await auth.signOut();
                    if (context.mounted) context.go('/login');
                  },
                  icon: const Icon(Icons.logout_rounded,
                      color: AppTheme.dangerRed),
                  label: const Text('Keluar',
                      style: TextStyle(color: AppTheme.dangerRed)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.dangerRed),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Bapander v1.0.0',
                  style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.primaryGreen, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF888780)))
          : null,
      trailing: const Icon(Icons.chevron_right_rounded,
          color: Color(0xFFCCCCCC)),
      onTap: onTap,
    );
  }
}
