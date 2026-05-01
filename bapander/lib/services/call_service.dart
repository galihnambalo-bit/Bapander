import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../utils/supabase_config.dart';
import 'notification_service.dart';

class CallService extends ChangeNotifier {
  final _client = SupabaseConfig.client;
  final _uuid = const Uuid();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  bool _isMuted = false;
  bool _inCall = false;
  bool _isRinging = false;

  bool get isMuted => _isMuted;
  bool get inCall => _inCall;
  bool get isRinging => _isRinging;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  final Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  // ─── START CALL (caller) ──────────────────────────────────
  Future<String> startCall({
    required String callerUid,
    required String receiverUid,
  }) async {
    final callId = _uuid.v4();
    
    // Cek apakah receiver online
    final receiver = await _client.from('users')
        .select('online').eq('id', receiverUid).maybeSingle();
    
    if (receiver == null || receiver['online'] != true) {
      throw Exception('user_offline');
    }

    await _client.from('calls').insert({
      'id': callId,
      'caller': callerUid,
      'receiver': receiverUid,
      'status': 'ringing',
      'offer': {},
      'answer': {},
      'started_at': DateTime.now().toIso8601String(),
    });

    // Play outgoing ringtone
    await FlutterRingtonePlayer().playRingtone();
    // Kirim notifikasi panggilan masuk
    try {
      final caller = await _client.from('users').select('name').eq('id', callerUid).maybeSingle();
      final callerName = caller?['name'] ?? 'Seseorang';
      await NotificationService.sendPushNotification(
        toUserId: receiverUid,
        title: '📞 Panggilan Masuk',
        body: '$callerName sedang menghubungi kamu',
      );
    } catch (e) {
      print('Call notif error: \$e');
    }

    setState(() => _isRinging = true);
    return callId;
  }

  // ─── SETUP WEBRTC SETELAH DITERIMA ────────────────────────
  Future<void> stopRingtone() async {
    try { await FlutterRingtonePlayer().stop(); } catch (_) {}
  }

  Future<void> setupCallerWebRTC(String callId) async {
    await _initLocalStream();
    await _createOfferConnection(callId);
    setState(() { _inCall = true; _isRinging = false; });
  }

  // ─── ACCEPT CALL (receiver) ───────────────────────────────
  Future<void> acceptCall(String callId) async {
    await FlutterRingtonePlayer().stop();
    await _client.from('calls')
        .update({'status': 'accepted'}).eq('id', callId);
    await _initLocalStream();
    await _createAnswerConnection(callId);
    setState(() => _inCall = true);
  }

  // ─── REJECT CALL ──────────────────────────────────────────
  Future<void> rejectCall(String callId) async {
    await FlutterRingtonePlayer().stop();
    await _client.from('calls')
        .update({'status': 'rejected'}).eq('id', callId);
    setState(() => _isRinging = false);
  }

  // ─── END CALL ─────────────────────────────────────────────
  Future<void> endCall(String callId) async {
    await _client.from('calls').update({
      'status': 'ended',
      'ended_at': DateTime.now().toIso8601String(),
    }).eq('id', callId);
    await _cleanup();
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !_isMuted);
    notifyListeners();
  }

  Future<void> _initLocalStream() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true, 'video': false,
    });
  }

  Future<void> _createOfferConnection(String callId) async {
    _peerConnection = await createPeerConnection(_iceConfig);

    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        notifyListeners();
      }
    };

    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) async {
      final call = await _client.from('calls').select().eq('id', callId).single();
      final candidates = List<dynamic>.from(call['caller_candidates'] ?? []);
      candidates.add(candidate.toMap());
      await _client.from('calls').update({'caller_candidates': candidates}).eq('id', callId);
    };

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    await _client.from('calls').update({
      'offer': {'type': offer.type, 'sdp': offer.sdp},
    }).eq('id', callId);

    // Listen untuk answer
    _client.from('calls').stream(primaryKey: ['id']).eq('id', callId)
        .listen((data) async {
      if (data.isEmpty) return;
      final answer = data.first['answer'] as Map<String, dynamic>?;
      if (answer != null && answer['sdp'] != null &&
          _peerConnection?.signalingState != RTCSignalingState.RTCSignalingStateStable) {
        await _peerConnection?.setRemoteDescription(
          RTCSessionDescription(answer['sdp'], answer['type']),
        );
        // Add receiver candidates
        final candidates = List<dynamic>.from(data.first['receiver_candidates'] ?? []);
        for (final c in candidates) {
          await _peerConnection?.addCandidate(RTCIceCandidate(
            c['candidate'], c['sdpMid'], c['sdpMLineIndex']));
        }
      }
    });
  }

  Future<void> _createAnswerConnection(String callId) async {
    _peerConnection = await createPeerConnection(_iceConfig);

    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        notifyListeners();
      }
    };

    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) async {
      final call = await _client.from('calls').select().eq('id', callId).single();
      final candidates = List<dynamic>.from(call['receiver_candidates'] ?? []);
      candidates.add(candidate.toMap());
      await _client.from('calls').update({'receiver_candidates': candidates}).eq('id', callId);
    };

    final callDoc = await _client.from('calls').select().eq('id', callId).single();
    final offerData = callDoc['offer'] as Map<String, dynamic>?;
    if (offerData != null && offerData['sdp'] != null) {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(offerData['sdp'], offerData['type']),
      );
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      await _client.from('calls').update({
        'answer': {'type': answer.type, 'sdp': answer.sdp},
      }).eq('id', callId);

      // Add caller candidates
      final candidates = List<dynamic>.from(callDoc['caller_candidates'] ?? []);
      for (final c in candidates) {
        await _peerConnection?.addCandidate(RTCIceCandidate(
          c['candidate'], c['sdpMid'], c['sdpMLineIndex']));
      }
    }
  }

  Stream<Map<String, dynamic>> callStream(String callId) {
    return _client.from('calls').stream(primaryKey: ['id'])
        .eq('id', callId)
        .map((list) => list.isNotEmpty ? list.first : {});
  }

  Stream<List<Map<String, dynamic>>> incomingCallStream(String myUid) {
    return _client.from('calls').stream(primaryKey: ['id'])
        .eq('receiver', myUid)
        .map((list) => list
            .where((c) => c['status'] == 'ringing')
            .toList());
  }

  Future<void> _cleanup() async {
    _localStream?.dispose();
    await _peerConnection?.close();
    _localStream = null;
    _remoteStream = null;
    _peerConnection = null;
    _inCall = false;
    _isRinging = false;
    _isMuted = false;
    notifyListeners();
  }

  void setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }
}
