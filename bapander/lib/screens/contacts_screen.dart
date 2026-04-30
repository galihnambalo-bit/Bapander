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

class _ContactsScreenState extends State<ContactsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

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
    setState(() {
      _allUsers = users;
      _filtered = users;
      _loading = false;
    });
  }

  void _filter(String query) {
    setState(() {
      _filtered = query.isEmpty
          ? _allUsers
          : _allUsers.where((u) {
              final name = (u['name'] ?? '').toLowerCase();
              return name.contains(query.toLowerCase());
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final myUid = auth.currentUid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kontak'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Tersimpan'),
            Tab(text: 'Semua Pengguna'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [

          // ── TAB 1: KONTAK TERSIMPAN ─────────────────────────
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: auth.contactsStream(myUid),
            builder: (ctx, snap) {
              final contacts = snap.data ?? [];
              if (contacts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.contacts_outlined,
                          size: 72, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text('Belum ada kontak tersimpan',
                          style: TextStyle(
                              color: Color(0xFF888780), fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text(
                          'Pergi ke tab "Semua Pengguna" untuk menyimpan kontak',
                          style: TextStyle(
                              color: Color(0xFFAAAAAA), fontSize: 13),
                          textAlign: TextAlign.center),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: contacts.length,
                itemBuilder: (ctx, i) {
                  final contactId = contacts[i]['contact_id']?.toString() ?? '';
                  return FutureBuilder<Map<String, dynamic>?>(
                    future: auth.getUserData(contactId),
                    builder: (ctx, userSnap) {
                      final user = userSnap.data;
                      final name = user?['name'] ?? 'User';
                      final photo = user?['photo'] ?? '';
                      final online = user?['online'] ?? false;

                      return _ContactTile(
                        name: name,
                        photo: photo,
                        online: online,
                        uid: contactId,
                        myUid: myUid,
                        isSaved: true,
                        onChat: () async {
                          final chatSvc = context.read<ChatService>();
                          final chatId = await chatSvc.getOrCreateChat(myUid, contactId);
                          if (ctx.mounted) {
                            context.push('/chat/$chatId', extra: {
                              'name': name,
                              'photo': photo,
                              'uid': contactId,
                            });
                          }
                        },
                        onToggleSave: () async {
                          await auth.removeContact(myUid, contactId);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Kontak dihapus')),
                            );
                          }
                        },
                      );
                    },
                  );
                },
              );
            },
          ),

          // ── TAB 2: SEMUA PENGGUNA ───────────────────────────
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
                    filled: true,
                    fillColor: const Color(0xFFF0F2F1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _filtered.isEmpty
                        ? const Center(
                            child: Text('Tidak ada pengguna',
                                style: TextStyle(color: Color(0xFF888780))))
                        : ListView.builder(
                            itemCount: _filtered.length,
                            itemBuilder: (ctx, i) {
                              final u = _filtered[i];
                              final uid = u['id']?.toString() ?? '';
                              final name = u['name'] ?? '';
                              final photo = u['photo'] ?? '';
                              final online = u['online'] ?? false;

                              return FutureBuilder<bool>(
                                future: auth.isContact(myUid, uid),
                                builder: (ctx, savedSnap) {
                                  final isSaved = savedSnap.data ?? false;
                                  return _ContactTile(
                                    name: name,
                                    photo: photo,
                                    online: online,
                                    uid: uid,
                                    myUid: myUid,
                                    isSaved: isSaved,
                                    onChat: () async {
                                      final chatSvc = context.read<ChatService>();
                                      final chatId = await chatSvc.getOrCreateChat(myUid, uid);
                                      if (ctx.mounted) {
                                        context.push('/chat/$chatId', extra: {
                                          'name': name,
                                          'photo': photo,
                                          'uid': uid,
                                        });
                                      }
                                    },
                                    onToggleSave: () async {
                                      if (isSaved) {
                                        await auth.removeContact(myUid, uid);
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Kontak dihapus')));
                                        }
                                      } else {
                                        await auth.saveContact(myUid, uid);
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Kontak tersimpan!'),
                                              backgroundColor: AppTheme.primaryGreen,
                                            ));
                                        }
                                      }
                                      setState(() {});
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

class _ContactTile extends StatelessWidget {
  final String name;
  final String photo;
  final bool online;
  final String uid;
  final String myUid;
  final bool isSaved;
  final VoidCallback onChat;
  final VoidCallback onToggleSave;

  const _ContactTile({
    required this.name,
    required this.photo,
    required this.online,
    required this.uid,
    required this.myUid,
    required this.isSaved,
    required this.onChat,
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          AvatarWidget(name: name, photoUrl: photo, size: 50),
          if (online)
            Positioned(
              right: 0, bottom: 0,
              child: Container(
                width: 13, height: 13,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(
        online ? 'Online' : 'Offline',
        style: TextStyle(
          fontSize: 12,
          color: online ? AppTheme.primaryGreen : const Color(0xFF888780),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tombol simpan/hapus kontak
          IconButton(
            icon: Icon(
              isSaved ? Icons.person_remove_rounded : Icons.person_add_rounded,
              color: isSaved ? AppTheme.dangerRed : AppTheme.primaryGreen,
              size: 22,
            ),
            onPressed: onToggleSave,
            tooltip: isSaved ? 'Hapus kontak' : 'Simpan kontak',
          ),
          // Tombol chat
          IconButton(
            icon: const Icon(Icons.chat_bubble_rounded,
                color: AppTheme.primaryGreen, size: 22),
            onPressed: onChat,
            tooltip: 'Chat',
          ),
        ],
      ),
    );
  }
}
