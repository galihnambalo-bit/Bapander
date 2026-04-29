import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../models/models.dart';
import '../localization/app_localizations.dart';
import '../utils/app_theme.dart';
import '../widgets/avatar_widget.dart';

class ChatListTab extends StatelessWidget {
  const ChatListTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final chat = context.watch<ChatService>();
    final loc = context.watch<LocalizationProvider>();
    final myUid = auth.currentUid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('chat')),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.edit_square),
            onPressed: () => _showNewChatDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<List<ChatModel>>(
        stream: chat.chatListStream(myUid),
        builder: (context, snap) {
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
                  Text(
                    loc.t('no_chats'),
                    style: const TextStyle(color: Color(0xFF888780)),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showNewChatDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(loc.t('new_message')),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, i) {
              final c = chats[i];
              final otherId = c.members.firstWhere(
                (m) => m != myUid,
                orElse: () => '',
              );
              return _ChatListItem(
                chat: c,
                myUid: myUid,
                otherId: otherId,
              );
            },
          );
        },
      ),
    );
  }

  void _showNewChatDialog(BuildContext context) {
    final auth = context.read<AuthService>();
    final chatSvc = context.read<ChatService>();
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

class _ChatListItem extends StatelessWidget {
  final ChatModel chat;
  final String myUid;
  final String otherId;

  const _ChatListItem({
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

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Stack(
            children: [
              AvatarWidget(name: name, photoUrl: photo, size: 50),
              if (online)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Text(
            chat.lastMessage.isEmpty ? 'Mulai percakapan...' : chat.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Color(0xFF888780)),
          ),
          trailing: chat.lastTimestamp > 0
              ? Text(
                  timeago.format(
                    DateTime.fromMillisecondsSinceEpoch(chat.lastTimestamp),
                    locale: 'id',
                  ),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF888780)),
                )
              : null,
          onTap: () {
            context.push('/chat/${chat.chatId}', extra: {
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final chatSvc = context.read<ChatService>();
    final users = await chatSvc.getAllUsers(widget.myUid);
    setState(() {
      _users = users;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Pesan Baru',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _users.length,
                itemBuilder: (ctx, i) {
                  final u = _users[i];
                  return ListTile(
                    leading: AvatarWidget(
                        name: u['name'] ?? '', photoUrl: u['photo'] ?? ''),
                    title: Text(u['name'] ?? ''),
                    subtitle: Text(u['phone'] ?? ''),
                    onTap: () async {
                      final chatSvc = context.read<ChatService>();
                      final chatId = await chatSvc.getOrCreateChat(
                          widget.myUid, u['id']);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      context.push('/chat/$chatId', extra: {
                        'name': u['name'],
                        'photo': u['photo'],
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
