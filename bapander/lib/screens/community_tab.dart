// ============================================================
// COMMUNITY TAB
// ============================================================
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../models/models.dart';
import '../localization/app_localizations.dart';
import '../utils/app_theme.dart';
import '../widgets/avatar_widget.dart';

class CommunityTab extends StatelessWidget {
  const CommunityTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final chat = context.watch<ChatService>();
    final loc = context.watch<LocalizationProvider>();
    final myUid = auth.currentUid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('community')),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_rounded),
            onPressed: () => context.push('/create-group'),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: chat.groupsStream(myUid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snap.data ?? <Map<String, dynamic>>[];
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.groups_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('Belum ada komunitas',
                      style: TextStyle(color: Color(0xFF888780))),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/create-group'),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(loc.t('create_group')),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (ctx, i) {
              final g = groups[i] as Map<String, dynamic>;
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: AvatarWidget(
                    name: g['name'] ?? '', photoUrl: g['photo'] ?? '', size: 50),
                title: Text(g['name'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: Text(
                  '${(g["members"] as List? ?? []).length} anggota',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF888780)),
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFCCCCCC)),
                onTap: () => context.push('/group/${g['id']}'),
              );
            },
          );
        },
      ),
    );
  }
}
