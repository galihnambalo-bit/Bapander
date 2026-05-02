import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/status_service.dart';
import '../../services/admob_service.dart';
import '../../models/status_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/avatar_widget.dart';

class StatusTab extends StatelessWidget {
  const StatusTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final svc = context.read<StatusService>();
    final myUid = auth.currentUid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(title: const Text('Status')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/status/create'),
        backgroundColor: AppTheme.primaryBlue,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: StreamBuilder<List<StatusModel>>(
        stream: svc.statusesStream(),
        builder: (ctx, snap) {
          final allStatuses = snap.data ?? [];
          final grouped = svc.groupByUser(allStatuses);
          final myStatuses = grouped[myUid] ?? [];
          final othersEntries = grouped.entries.where((e) => e.key != myUid).toList();

          return ListView(
            children: [
              // My status
              ListTile(
                leading: Stack(
                  children: [
                    FutureBuilder<Map<String, dynamic>?>(
                      future: auth.getUserData(myUid),
                      builder: (ctx, snap) => AvatarWidget(
                          name: snap.data?['name'] ?? '',
                          photoUrl: snap.data?['photo'] ?? '',
                          size: 50),
                    ),
                    Positioned(
                      right: 0, bottom: 0,
                      child: Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.add_rounded, size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                title: const Text('Status saya', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(myStatuses.isEmpty ? 'Ketuk untuk tambah status' : '${myStatuses.length} status aktif'),
                onTap: () {
              if (myStatuses.isNotEmpty) {
                context.push('/status/view', extra: {'statuses': myStatuses, 'index': 0});
              } else {
                context.push('/status/create');
              }
            },
              ),
              const BannerAdWidget(),
              const Divider(),
              if (othersEntries.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('Belum ada status dari teman', style: TextStyle(color: Color(0xFF888780))),
                  ),
                ),
              ...othersEntries.asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                final statuses = e.value;
                final latest = statuses.first;
                final allViewed = statuses.every((s) => s.viewedBy.contains(myUid));

                return Column(
                  children: [
                    if (i > 0 && i % 4 == 0) const BannerAdWidget(),
                    ListTile(
                      leading: Container(
                        width: 54, height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: allViewed ? Colors.grey[300]! : AppTheme.primaryBlue,
                            width: 2.5,
                          ),
                        ),
                        child: ClipOval(
                          child: latest.type == 'image'
                              ? Image.network(latest.content, fit: BoxFit.cover)
                              : Container(
                                  color: Color(int.parse(latest.backgroundColor.replaceAll('#', '0xFF'))),
                                  child: Center(
                                    child: Text(
                                      latest.content.isNotEmpty ? latest.content[0] : '?',
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      title: Text(latest.displayName, style: TextStyle(fontWeight: allViewed ? FontWeight.normal : FontWeight.w600)),
                      subtitle: Text(_timeAgo(latest.createdAt), style: const TextStyle(fontSize: 12)),
                      onTap: () {
                        for (var s in statuses) svc.markAsViewed(s.id, myUid);
                        context.push('/status/view', extra: {'statuses': statuses, 'index': 0});
                      },
                    ),
                  ],
                );
              }),
            ],
          );
        },
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }
}
