import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(loc.t('calls'))),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('calls')
            .where('caller', isEqualTo: myUid)
            .orderBy('started_at', descending: true)
            .limit(30)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;
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
              final data = docs[i].data() as Map<String, dynamic>;
              final receiverId = data['receiver'] ?? '';
              final status = data['status'] ?? 'ended';
              final ts = data['started_at'] ?? 0;

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
                          status == 'ended'
                              ? 'Panggilan selesai'
                              : status == 'missed'
                                  ? 'Panggilan tak terjawab'
                                  : status,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                    trailing: Text(
                      ts > 0
                          ? timeago.format(
                              DateTime.fromMillisecondsSinceEpoch(ts),
                              locale: 'id')
                          : '',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF888780)),
                    ),
                    onTap: () {},
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
