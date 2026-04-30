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
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthService>();
    final data = await auth.getUserData(auth.currentUid ?? '');
    if (mounted) setState(() => _userData = data);
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400, maxHeight: 400, imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final auth = context.read<AuthService>();
      final uid = auth.currentUid ?? '';
      final file = File(picked.path);
      final path = 'profiles/$uid/avatar.jpg';

      await SupabaseConfig.client.storage.from('media').upload(
        path, file, fileOptions: const FileOptions(upsert: true));

      final photoUrl = SupabaseConfig.client.storage.from('media').getPublicUrl(path);
      final finalUrl = '$photoUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      await SupabaseConfig.client.from('users').update({'photo': finalUrl}).eq('id', uid);
      await _loadData();

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto profil diperbarui!'),
          backgroundColor: AppTheme.primaryGreen));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')));
    } finally {
      setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _editName(String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Nama'),
        content: TextField(controller: ctrl,
          decoration: const InputDecoration(hintText: 'Nama lengkap'),
          textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Simpan')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final auth = context.read<AuthService>();
      await SupabaseConfig.client.from('users')
          .update({'name': result}).eq('id', auth.currentUid ?? '');
      await _loadData();
    }
  }

  Future<void> _editBio(String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Bio'),
        content: TextField(controller: ctrl, maxLines: 3, maxLength: 100,
          decoration: const InputDecoration(hintText: 'Ceritakan tentang dirimu...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Simpan')),
        ],
      ),
    );
    if (result != null) {
      final auth = context.read<AuthService>();
      await SupabaseConfig.client.from('users')
          .update({'bio': result}).eq('id', auth.currentUid ?? '');
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final loc = context.watch<LocalizationProvider>();
    final myUid = auth.currentUid ?? '';
    final name = _userData?['name'] ?? '';
    final photo = _userData?['photo'] ?? '';
    final bio = _userData?['bio'] ?? '';
    final email = auth.currentUser?.email ?? '';
    final isAnon = _userData?['anonymous_mode'] ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      body: CustomScrollView(
        slivers: [
          // ── HEADER ─────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppTheme.primaryGreen,
            title: Text(loc.t('profile'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                onPressed: () => context.push('/settings'),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primaryGreen, Color(0xFF0A4F3E)],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                // ── PROFILE CARD ───────────────────────────────
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.06),
                        blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Avatar
                      Stack(
                        children: [
                          _uploadingPhoto
                              ? Container(
                                  width: 90, height: 90,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppTheme.primaryGreen)),
                                )
                              : AvatarWidget(name: name, photoUrl: photo, size: 90),
                          Positioned(
                            right: 0, bottom: 0,
                            child: GestureDetector(
                              onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                              child: Container(
                                width: 30, height: 30,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt_rounded,
                                  size: 15, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Nama
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(name.isEmpty ? 'Pengguna' : name,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _editName(name),
                            child: const Icon(Icons.edit_rounded,
                              size: 16, color: AppTheme.primaryGreen),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(email,
                        style: const TextStyle(color: Color(0xFF888780), fontSize: 13)),

                      // Bio
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _editBio(bio),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F8F7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit_note_rounded,
                                size: 16, color: AppTheme.primaryGreen),
                              const SizedBox(width: 6),
                              Text(
                                bio.isEmpty ? 'Tambah bio...' : bio,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: bio.isEmpty
                                      ? const Color(0xFF888780)
                                      : const Color(0xFF333333),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Stats followers
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
                                  Text('$followers',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                                  const Text('Pengikut',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF888780))),
                                ]),
                              ),
                              Container(width: 1, height: 30, color: const Color(0xFFEEEEEE),
                                margin: const EdgeInsets.symmetric(horizontal: 24)),
                              GestureDetector(
                                onTap: () => context.push('/contacts'),
                                child: Column(children: [
                                  Text('$following',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                                  const Text('Mengikuti',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF888780))),
                                ]),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // ── MENU LIST ──────────────────────────────────
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04),
                        blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    children: [
                      _MenuItem(
                        icon: Icons.people_alt_rounded,
                        iconColor: const Color(0xFF4CAF50),
                        title: 'Cari Teman Terdekat',
                        subtitle: 'Temukan teman di sekitarmu',
                        onTap: () => context.push('/nearby'),
                      ),
                      const Divider(height: 1, indent: 56),
                      _MenuItem(
                        icon: Icons.person_outlined,
                        iconColor: const Color(0xFF9C27B0),
                        title: 'Mode Anonim',
                        subtitle: isAnon ? 'Aktif' : 'Nonaktif',
                        trailing: Switch(
                          value: isAnon,
                          onChanged: (v) async {
                            await SupabaseConfig.client.from('users')
                                .update({'anonymous_mode': v})
                                .eq('id', myUid);
                            await _loadData();
                          },
                          activeColor: AppTheme.primaryGreen,
                        ),
                        onTap: () {},
                      ),
                      const Divider(height: 1, indent: 56),
                      _MenuItem(
                        icon: Icons.notifications_outlined,
                        iconColor: const Color(0xFFFF9800),
                        title: 'Notifikasi',
                        subtitle: 'Push notification aktif',
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Notifikasi'),
                            content: const Text('Notifikasi push aktif via OneSignal + Firebase FCM'),
                            actions: [TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'))],
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 56),
                      _MenuItem(
                        icon: Icons.privacy_tip_outlined,
                        iconColor: const Color(0xFF2196F3),
                        title: 'Privasi',
                        subtitle: 'Data tersimpan aman di Supabase',
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Privasi'),
                            content: const Text(
                              'Data kamu tersimpan aman di Supabase.\nMode anonim tersedia di marketplace, lelang, dan status.'),
                            actions: [TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'))],
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 56),
                      _MenuItem(
                        icon: Icons.help_outline_rounded,
                        iconColor: const Color(0xFF607D8B),
                        title: 'Bantuan',
                        subtitle: 'FAQ dan hubungi kami',
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
                                Text('💬 Chat: Hubungi admin'),
                                SizedBox(height: 8),
                                Text('🔖 Versi: 1.0.0'),
                              ],
                            ),
                            actions: [TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'))],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Logout
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await auth.signOut();
                        if (context.mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.logout_rounded, color: AppTheme.dangerRed),
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
                ),

                const SizedBox(height: 8),
                const Center(
                  child: Text('Bapander v1.0.0',
                    style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA))),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: const TextStyle(fontSize: 12, color: Color(0xFF888780)))
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: Color(0xFFCCCCCC)),
      onTap: onTap,
    );
  }
}
