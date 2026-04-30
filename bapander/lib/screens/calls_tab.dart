import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../services/auth_service.dart';
import '../localization/app_localizations.dart';
import '../utils/app_theme.dart';
import '../widgets/avatar_widget.dart';

class CallsTab extends StatelessWidget {
  const CallsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final loc = context.watch<LocalizationProvider>();
    final myUid = auth.currentUid ?? '';
    final client = Supabase.instance.client;

    return Scaffold(
      appBar: AppBar(title: Text(loc.t('calls'))),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: client
            .from('calls')
            .stream(primaryKey: ['id'])
            .eq('caller', myUid)
            .order('started_at', ascending: false)
            .map((list) => List<Map<String, dynamic>>.from(list)),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.call_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('Belum ada riwayat panggilan',
                      style: TextStyle(color: Color(0xFF888780))),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = docs[i];
              final receiverId = data['receiver']?.toString() ?? '';
              final status = data['status'] ?? 'ended';
              final ts = data['started_at'];

              return FutureBuilder<Map<String, dynamic>?>(
                future: auth.getUserData(receiverId),
                builder: (ctx2, userSnap) {
                  final name = userSnap.data?['name'] ?? 'User';
                  final photo = userSnap.data?['photo'] ?? '';
                  return ListTile(
                    leading: AvatarWidget(name: name, photoUrl: photo),
                    title: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Row(
                      children: [
                        Icon(
                          status == 'ended'
                              ? Icons.call_made_rounded
                              : Icons.call_missed_rounded,
                          size: 14,
                          color: status == 'missed'
                              ? AppTheme.dangerRed
                              : AppTheme.primaryLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          status == 'ended' ? 'Selesai' : status,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                    trailing: ts != null
                        ? Text(
                            timeago.format(DateTime.parse(ts), locale: 'id'),
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF888780)),
                          )
                        : null,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
