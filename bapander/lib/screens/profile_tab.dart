import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../localization/app_localizations.dart';
import '../utils/app_theme.dart';
import '../utils/supabase_config.dart';
import '../widgets/avatar_widget.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _uploadingPhoto = false;

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);

    try {
      final auth = context.read<AuthService>();
      final uid = auth.currentUid ?? '';
      final client = SupabaseConfig.client;

      final file = File(picked.path);
      final path = 'profiles/$uid/avatar.jpg';

      // Upload ke Supabase Storage
      await client.storage.from('media').upload(
        path,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

      final photoUrl = client.storage.from('media').getPublicUrl(path);

      // Update di database
      await client.from('users').update({
        'photo': '$photoUrl?t=${DateTime.now().millisecondsSinceEpoch}',
      }).eq('id', uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto profil berhasil diperbarui!'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal upload: $e')),
        );
      }
    } finally {
      setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _showEditNameDialog(String currentName) async {
    final ctrl = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Nama'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Nama lengkap'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final auth = context.read<AuthService>();
      await SupabaseConfig.client.from('users').update({
        'name': result,
      }).eq('id', auth.currentUid ?? '');
      setState(() {});
    }
  }

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
          final email = auth.currentUser?.email ?? '';
          final photo = data?['photo'] ?? '';
          final bio = data?['bio'] ?? '';

          return ListView(
            children: [
              // ── PROFILE HEADER ──────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                child: Column(
                  children: [
                    // Avatar dengan tombol edit
                    Stack(
                      children: [
                        _uploadingPhoto
                            ? Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                              )
                            : AvatarWidget(
                                name: name,
                                photoUrl: photo,
                                size: 90,
                              ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Nama dengan tombol edit
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name.isEmpty ? 'Pengguna' : name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _showEditNameDialog(name),
                          child: const Icon(
                            Icons.edit_rounded,
                            size: 16,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                          color: Color(0xFF888780), fontSize: 14),
                    ),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        bio,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF888780)),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Followers & Following count
                    FutureBuilder<List<int>>(
                      future: Future.wait([
                        auth.getFollowersCount(myUid),
                        auth.getFollowingCount(myUid),
                      ]),
                      builder: (ctx, snap) {
                        final followers = snap.data?[0] ?? 0;
                        final following = snap.data?[1] ?? 0;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => context.push('/contacts'),
                              child: Column(children: [
                                Text('$followers', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                const Text('Pengikut', style: TextStyle(fontSize: 12, color: Color(0xFF888780))),
                              ]),
                            ),
                            Container(width: 1, height: 30, color: const Color(0xFFEEEEEE), margin: const EdgeInsets.symmetric(horizontal: 24)),
                            GestureDetector(
                              onTap: () => context.push('/contacts'),
                              child: Column(children: [
                                Text('$following', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                const Text('Mengikuti', style: TextStyle(fontSize: 12, color: Color(0xFF888780))),
                              ]),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Tombol edit bio
                    OutlinedButton.icon(
                      onPressed: () => _showEditBioDialog(bio),
                      icon: const Icon(Icons.edit_note_rounded, size: 16),
                      label: Text(bio.isEmpty ? 'Tambah Bio' : 'Edit Bio'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryGreen,
                        side: const BorderSide(color: AppTheme.primaryGreen),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // ── MENU ITEMS ───────────────────────────────────
              _MenuItem(
                icon: Icons.people_alt_rounded,
                title: 'Cari Teman Terdekat',
                subtitle: 'Temukan teman di sekitarmu',
                onTap: () => context.push('/nearby'),
              ),
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
                icon: Icons.person_outline_rounded,
                title: 'Mode Anonim',
                subtitle: 'Sembunyikan identitasmu',
                onTap: () => _toggleAnonymous(data?['anonymous_mode'] ?? false, myUid),
              ),
              _MenuItem(
                icon: Icons.notifications_outlined,
                title: 'Notifikasi',
                onTap: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Notifikasi'),
                  content: const Text('Notifikasi push aktif via OneSignal + Firebase FCM'),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                )),
              ),
              _MenuItem(
                icon: Icons.privacy_tip_outlined,
                title: 'Privasi',
                onTap: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Privasi'),
                  content: const Text('Data kamu tersimpan aman di Supabase. Mode anonim tersedia di marketplace, lelang, dan status.'),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                )),
              ),
              _MenuItem(
                icon: Icons.help_outline_rounded,
                title: 'Bantuan',
                onTap: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Bantuan'),
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📧 Email: support@bapander.app'),
                      SizedBox(height: 8),
                      Text('💬 Chat: Hubungi admin via fitur chat'),
                      SizedBox(height: 8),
                      Text('🔖 Versi: 1.0.0'),
                    ],
                  ),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                )),
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

  Future<void> _showEditBioDialog(String currentBio) async {
    final ctrl = TextEditingController(text: currentBio);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Bio'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          maxLength: 100,
          decoration: const InputDecoration(hintText: 'Ceritakan tentang dirimu...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result != null) {
      final auth = context.read<AuthService>();
      await SupabaseConfig.client.from('users').update({
        'bio': result,
      }).eq('id', auth.currentUid ?? '');
      setState(() {});
    }
  }

  Future<void> _toggleAnonymous(bool current, String uid) async {
    await SupabaseConfig.client.from('users').update({
      'anonymous_mode': !current,
    }).eq('id', uid);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(!current
            ? 'Mode anonim aktif — identitasmu tersembunyi'
            : 'Mode anonim nonaktif'),
        backgroundColor: AppTheme.primaryGreen,
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
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.primaryGreen, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF888780)))
          : null,
      trailing: const Icon(Icons.chevron_right_rounded,
          color: Color(0xFFCCCCCC)),
      onTap: onTap,
    );
  }
}
