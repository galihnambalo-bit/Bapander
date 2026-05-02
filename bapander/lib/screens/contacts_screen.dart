import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../utils/app_theme.dart';
import '../widgets/avatar_widget.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final auth = context.read<AuthService>();
    final users = await auth.getAllUsers(auth.currentUid ?? '');
    setState(() { _allUsers = users; _filtered = users; _loading = false; });
  }

  void _filter(String q) {
    setState(() {
      _filtered = q.isEmpty ? _allUsers : _allUsers.where((u) =>
          (u['name'] ?? '').toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final myUid = auth.currentUid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kontak & Follow'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [Tab(text: 'Following'), Tab(text: 'Cari Pengguna')],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // ── TAB 1: FOLLOWING ──────────────────────────────
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: auth.followingStream(myUid),
            builder: (ctx, snap) {
              final follows = snap.data ?? [];
              if (follows.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline_rounded, size: 72, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text('Belum mengikuti siapapun', style: TextStyle(color: Color(0xFF888780), fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text('Pergi ke tab "Cari Pengguna" untuk follow teman', style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13), textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => _tabCtrl.animateTo(1),
                        child: const Text('Cari Pengguna'),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                itemCount: follows.length,
                itemBuilder: (ctx, i) {
                  final followingId = follows[i]['following_id']?.toString() ?? '';
                  return FutureBuilder<Map<String, dynamic>?>(
                    future: auth.getUserData(followingId),
                    builder: (ctx, userSnap) {
                      final user = userSnap.data;
                      final name = user?['name'] ?? 'User';
                      final photo = user?['photo'] ?? '';
                      final online = user?['online'] ?? false;
                      return _UserTile(
                        name: name, photo: photo, online: online,
                        uid: followingId, myUid: myUid,
                        isFollowing: true,
                        onFollow: () async {
                          await auth.unfollowUser(myUid, followingId);
                          if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Berhenti mengikuti $name')));
                        },
                        onChat: () async {
                          final chatSvc = context.read<ChatService>();
                          final chatId = await chatSvc.getOrCreateChat(myUid, followingId);
                          if (ctx.mounted) context.push('/chat/$chatId', extra: {
                            'name': name, 'photo': photo, 'uid': followingId,
                          });
                        },
                      );
                    },
                  );
                },
              );
            },
          ),

          // ── TAB 2: CARI PENGGUNA ──────────────────────────
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _filter,
                  decoration: InputDecoration(
                    hintText: 'Cari nama...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true, fillColor: const Color(0xFFF0F2F1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _filtered.isEmpty
                        ? const Center(child: Text('Tidak ada pengguna', style: TextStyle(color: Color(0xFF888780))))
                        : ListView.builder(
                            itemCount: _filtered.length,
                            itemBuilder: (ctx, i) {
                              final u = _filtered[i];
                              final uid = u['id']?.toString() ?? '';
                              final name = u['name'] ?? '';
                              final photo = u['photo'] ?? '';
                              final online = u['online'] ?? false;
                              return FutureBuilder<bool>(
                                future: auth.isFollowing(myUid, uid),
                                builder: (ctx, snap) {
                                  final isFollowing = snap.data ?? false;
                                  return _UserTile(
                                    name: name, photo: photo, online: online,
                                    uid: uid, myUid: myUid,
                                    isFollowing: isFollowing,
                                    onFollow: () async {
                                      if (isFollowing) {
                                        await auth.unfollowUser(myUid, uid);
                                        if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Berhenti mengikuti $name')));
                                      } else {
                                        await auth.followUser(myUid, uid);
                                        if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Mengikuti $name! 🎉'), backgroundColor: AppTheme.primaryBlue));
                                      }
                                      setState(() {});
                                    },
                                    onChat: () async {
                                      final chatSvc = context.read<ChatService>();
                                      final chatId = await chatSvc.getOrCreateChat(myUid, uid);
                                      if (ctx.mounted) context.push('/chat/$chatId', extra: {
                                        'name': name, 'photo': photo, 'uid': uid,
                                      });
                                    },
                                  );
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final String name, photo, uid, myUid;
  final bool online, isFollowing;
  final VoidCallback onFollow, onChat;

  const _UserTile({
    required this.name, required this.photo, required this.online,
    required this.uid, required this.myUid, required this.isFollowing,
    required this.onFollow, required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          AvatarWidget(name: name, photoUrl: photo, size: 50),
          if (online) Positioned(right: 0, bottom: 0,
            child: Container(width: 13, height: 13,
              decoration: BoxDecoration(color: AppTheme.primaryLight, shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2)))),
        ],
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(online ? 'Online' : 'Offline',
          style: TextStyle(fontSize: 12, color: online ? AppTheme.primaryBlue : const Color(0xFF888780))),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tombol Follow/Unfollow
          GestureDetector(
            onTap: onFollow,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isFollowing ? const Color(0xFFF0F2F1) : AppTheme.primaryBlue,
                borderRadius: BorderRadius.circular(100),
                border: isFollowing ? Border.all(color: const Color(0xFFDDDDD8)) : null,
              ),
              child: Text(
                isFollowing ? 'Following' : 'Follow',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: isFollowing ? const Color(0xFF888780) : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Tombol Chat
          IconButton(
            icon: const Icon(Icons.chat_bubble_rounded, color: AppTheme.primaryBlue, size: 20),
            onPressed: onChat,
          ),
        ],
      ),
    );
  }
}
