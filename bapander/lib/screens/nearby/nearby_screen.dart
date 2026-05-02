import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/chat_service.dart';
import '../../services/admob_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/avatar_widget.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});
  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  String? _genderFilter;
  double _radiusKm = 10.0;
  List<Map<String, dynamic>> _nearbyUsers = [];
  bool _isLoading = false;
  bool _locationGranted = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final loc = context.read<LocationService>();
    final auth = context.read<AuthService>();
    setState(() => _isLoading = true);
    final granted = await loc.getCurrentLocation();
    if (granted && auth.currentUid != null) {
      await loc.updateUserLocation(auth.currentUid!);
      setState(() => _locationGranted = true);
      await _loadNearby();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadNearby() async {
    final loc = context.read<LocationService>();
    final auth = context.read<AuthService>();
    if (auth.currentUid == null) return;
    setState(() => _isLoading = true);
    final users = await loc.getNearbyUsers(myUid: auth.currentUid!, radiusKm: _radiusKm, genderFilter: _genderFilter);
    setState(() { _nearbyUsers = users; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final myUid = context.read<AuthService>().currentUid ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari Teman Terdekat'),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadNearby)],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white, padding: const EdgeInsets.all(12),
            child: Column(children: [
              Row(children: [
                const Text('Filter: ', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                ...[
                  (null, 'Semua', Icons.people_rounded),
                  ('L', 'Laki-laki', Icons.man_rounded),
                  ('P', 'Perempuan', Icons.woman_rounded),
                ].map((f) => GestureDetector(
                  onTap: () { setState(() => _genderFilter = f.$1); _loadNearby(); },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _genderFilter == f.$1 ? AppTheme.primaryBlue : const Color(0xFFF0F2F1),
                      borderRadius: BorderRadius.circular(100)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(f.$3, size: 14, color: _genderFilter == f.$1 ? Colors.white : const Color(0xFF888780)),
                      const SizedBox(width: 4),
                      Text(f.$2, style: TextStyle(fontSize: 12, color: _genderFilter == f.$1 ? Colors.white : const Color(0xFF888780))),
                    ]),
                  ),
                )),
              ]),
              Row(children: [
                const Icon(Icons.radar_rounded, size: 16, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                Text('Radius: ${_radiusKm.toInt()} km', style: const TextStyle(fontSize: 13)),
                Expanded(child: Slider(value: _radiusKm, min: 1, max: 100, divisions: 99,
                  activeColor: AppTheme.primaryBlue,
                  onChanged: (v) => setState(() => _radiusKm = v), onChangeEnd: (_) => _loadNearby())),
              ]),
            ]),
          ),
          const BannerAdWidget(),
          Expanded(
            child: !_locationGranted
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.location_off_rounded, size: 72, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    const Text('Izin lokasi diperlukan'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(onPressed: _init, icon: const Icon(Icons.location_on_rounded, size: 18), label: const Text('Izinkan Lokasi')),
                  ]))
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _nearbyUsers.isEmpty
                        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.people_outline_rounded, size: 72, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('Tidak ada pengguna dalam radius ${_radiusKm.toInt()} km'),
                          ]))
                        : ListView.builder(
                            itemCount: _nearbyUsers.length,
                            itemBuilder: (ctx, i) {
                              if (i > 0 && i % 5 == 0) return const BannerAdWidget();
                              final u = _nearbyUsers[i];
                              final name = u['anonymous_mode'] == true ? 'Anonim' : (u['name'] ?? '');
                              final photo = u['anonymous_mode'] == true ? '' : (u['photo'] ?? '');
                              final distKm = (u['distance_km'] as double? ?? 0);
                              return ListTile(
                                leading: AvatarWidget(name: name, photoUrl: photo, size: 50),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Row(children: [
                                  const Icon(Icons.location_on_rounded, size: 12, color: AppTheme.primaryBlue),
                                  Text(distKm < 1 ? '${(distKm * 1000).toInt()} m' : '${distKm.toStringAsFixed(1)} km',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.primaryBlue)),
                                ]),
                                trailing: ElevatedButton(
                                  onPressed: () async {
                                    final chatSvc = context.read<ChatService>();
                                    final uid = u['id']?.toString() ?? '';
                                    final chatId = await chatSvc.getOrCreateChat(myUid, uid);
                                    if (ctx.mounted) context.push('/chat/$chatId', extra: {'name': name, 'photo': photo, 'uid': uid});
                                  },
                                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), minimumSize: Size.zero),
                                  child: const Text('Chat'),
                                ),
                              );
                            }),
          ),
        ],
      ),
    );
  }
}
