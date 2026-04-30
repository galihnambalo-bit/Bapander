import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/supabase_config.dart';

class LocationService extends ChangeNotifier {
  final _client = SupabaseConfig.client;
  Position? _currentPosition;
  bool _isLoading = false;

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;

  // ─── GET CURRENT LOCATION ─────────────────────────────────
  Future<bool> getCurrentLocation() async {
    _isLoading = true;
    notifyListeners();

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── UPDATE LOKASI USER DI DATABASE ──────────────────────
  Future<void> updateUserLocation(String userId) async {
    if (_currentPosition == null) return;
    await _client.from('users').update({
      'latitude': _currentPosition!.latitude,
      'longitude': _currentPosition!.longitude,
      'last_seen': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  // ─── CARI USER TERDEKAT ───────────────────────────────────
  Future<List<Map<String, dynamic>>> getNearbyUsers({
    required String myUid,
    required double radiusKm,
    String? genderFilter, // 'L' atau 'P' atau null (semua)
  }) async {
    if (_currentPosition == null) return [];

    final myLat = _currentPosition!.latitude;
    final myLng = _currentPosition!.longitude;

    // Ambil semua user yang punya lokasi
    var query = _client
        .from('users')
        .select()
        .neq('id', myUid)
        .not('latitude', 'is', null)
        .not('longitude', 'is', null)
        .eq('online', true);

    if (genderFilter != null) {
      query = query.eq('gender', genderFilter);
    }

    final data = await query;
    final users = List<Map<String, dynamic>>.from(data);

    // Hitung jarak dan filter
    final nearby = <Map<String, dynamic>>[];
    for (var user in users) {
      final lat = (user['latitude'] as num?)?.toDouble();
      final lng = (user['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      final distanceM = Geolocator.distanceBetween(myLat, myLng, lat, lng);
      final distanceKm = distanceM / 1000;

      if (distanceKm <= radiusKm) {
        nearby.add({...user, 'distance_km': distanceKm});
      }
    }

    // Sort by distance
    nearby.sort((a, b) =>
        (a['distance_km'] as double).compareTo(b['distance_km'] as double));

    return nearby;
  }
}
