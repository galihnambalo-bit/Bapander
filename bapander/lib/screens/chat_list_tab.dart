import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../utils/app_theme.dart';
import '../widgets/avatar_widget.dart';

class ChatListTab extends StatefulWidget {
  const ChatListTab({super.key});

  @override
  State<ChatListTab> createState() => _ChatListTabState();
}

class _ChatListTabState extends State<ChatListTab> {
  final _searchCtrl = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoadingSearch = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoadingSearch = false;
      });
      return;
    }

    setState(() => _isLoadingSearch = true);

    final auth = context.read<AuthService>();
    final myUid = auth.currentUid ?? '';

    // Cari user berdasarkan nama atau email
    try {
      final data = await auth.searchUsers(query, myUid);
      setState(() {
        _searchResults = data;
        _isLoadingSearch = false;
      });
    } catch (e) {
      setState(() => _isLoadingSearch = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final chat = context.watch<ChatService>();
    final myUid = auth.currentUid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Cari nama atau email...',
                  hintStyle: TextStyle(color: Colors.white60),
                  border: InputBorder.none,
                ),
                onChanged: _search,
              )
            : const Text('Pesan'),
        actions: [
          IconButton(
            icon: Icon(_isSearching
                ? Icons.close_rounded
                : Icons.search_rounded),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchCtrl.clear();
                  _searchResults = [];
                }
              });
            },
          ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.edit_square),
              onPressed: () => _showNewChatSheet(context),
            ),
        ],
      ),
      body: _isSearching
          ? _buildSearchResults(context, myUid)
          : _buildChatList(context, chat, myUid),
    );
  }

  Widget _buildSearchResults(BuildContext context, String myUid) {
    if (_isLoadingSearch) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchCtrl.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text('Ketik nama atau email untuk mencari',
                style: TextStyle(color: Color(0xFF888780))),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Tidak ada hasil untuk "${_searchCtrl.text}"',
                style: const TextStyle(color: Color(0xFF888780))),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (ctx, i) {
        final user = _searchResults[i];
        final name = user['name'] ?? '';
        final photo = user['photo'] ?? '';
        final email = user['email'] ?? '';
        final online = user['online'] ?? false;
        final uid = user['id'] ?? '';

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(email,
              style: const TextStyle(fontSize: 12, color: Color(0xFF888780))),
          trailing: ElevatedButton(
            onPressed: () async {
              final chatSvc = context.read<ChatService>();
              final chatId = await chatSvc.getOrCreateChat(myUid, uid);
              if (context.mounted) {
                setState(() {
                  _isSearching = false;
                  _searchCtrl.clear();
                  _searchResults = [];
                });
                context.push('/chat/$chatId', extra: {
                  'name': name,
                  'photo': photo,
                  'uid': uid,
                });
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
            ),
            child: const Text('Chat', style: TextStyle(fontSize: 13)),
          ),
        );
      },
    );
  }

  Widget _buildChatList(BuildContext context, ChatService chat, String myUid) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: chat.chatListStream(myUid),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final chats = snap.data ?? [];
        if (chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text('Belum ada pesan',
                    style: TextStyle(color: Color(0xFF888780))),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _showNewChatSheet(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Pesan Baru'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (ctx, i) {
            final c = chats[i];
            final members = List<String>.from(c['members'] ?? []);
            final otherId = members.firstWhere(
              (m) => m != myUid,
              orElse: () => '',
            );
            return _ChatListItemMap(
              chat: c,
              myUid: myUid,
              otherId: otherId,
            );
          },
        );
      },
    );
  }

  void _showNewChatSheet(BuildContext context) {
    final auth = context.read<AuthService>();
    final myUid = auth.currentUid ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _NewChatSheet(myUid: myUid),
    );
  }
}

class _ChatListItemMap extends StatelessWidget {
  final Map<String, dynamic> chat;
  final String myUid;
  final String otherId;

  const _ChatListItemMap({
    required this.chat,
    required this.myUid,
    required this.otherId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: context.read<AuthService>().getUserData(otherId),
      builder: (context, snap) {
        final userData = snap.data;
        final name = userData?['name'] ?? 'User';
        final photo = userData?['photo'] ?? '';
        final online = userData?['online'] ?? false;
        final lastMsg = chat['last_message'] ?? '';
        final lastTs = chat['last_timestamp'];

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 15)),
          subtitle: Text(
            lastMsg.isEmpty ? 'Mulai percakapan...' : lastMsg,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF888780)),
          ),
          trailing: lastTs != null
              ? Text(
                  timeago.format(
                    DateTime.tryParse(lastTs.toString()) ?? DateTime.now(),
                    locale: 'id',
                  ),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF888780)),
                )
              : null,
          onTap: () {
            context.push('/chat/${chat['id']}', extra: {
              'name': name,
              'photo': photo,
              'uid': otherId,
            });
          },
        );
      },
    );
  }
}

class _NewChatSheet extends StatefulWidget {
  final String myUid;
  const _NewChatSheet({required this.myUid});

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final auth = context.read<AuthService>();
    final users = await auth.getAllUsers(widget.myUid);
    setState(() {
      _users = users;
      _filtered = users;
      _loading = false;
    });
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = _users;
      } else {
        _filtered = _users.where((u) {
          final name = (u['name'] ?? '').toLowerCase();
          final email = (u['email'] ?? '').toLowerCase();
          return name.contains(query.toLowerCase()) ||
              email.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Pesan Baru',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          // Search box
          TextField(
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
          const SizedBox(height: 12),

          if (_loading)
            const Expanded(
                child: Center(child: CircularProgressIndicator()))
          else if (_filtered.isEmpty)
            const Expanded(
              child: Center(
                child: Text('Tidak ada pengguna ditemukan',
                    style: TextStyle(color: Color(0xFF888780))),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (ctx, i) {
                  final u = _filtered[i];
                  final name = u['name'] ?? '';
                  final photo = u['photo'] ?? '';
                  final online = u['online'] ?? false;

                  return ListTile(
                    leading: Stack(
                      children: [
                        AvatarWidget(name: name, photoUrl: photo),
                        if (online)
                          Positioned(
                            right: 0, bottom: 0,
                            child: Container(
                              width: 12, height: 12,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(u['email'] ?? '',
                        style: const TextStyle(fontSize: 12)),
                    onTap: () async {
                      final chatSvc = context.read<ChatService>();
                      final chatId = await chatSvc.getOrCreateChat(
                          widget.myUid, u['id']);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      context.push('/chat/$chatId', extra: {
                        'name': name,
                        'photo': photo,
                        'uid': u['id'],
                      });
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
