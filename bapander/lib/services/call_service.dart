import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';

import '../utils/supabase_config.dart';

class CallService extends ChangeNotifier {
  final _client = SupabaseConfig.client;
  final _uuid = const Uuid();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  bool _isMuted = false;
  bool _inCall = false;

  bool get isMuted => _isMuted;
  bool get inCall => _inCall;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  final Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  Future<String> startCall({
    required String callerUid,
    required String receiverUid,
  }) async {
    final callId = _uuid.v4();

    await _client.from('calls').insert({
      'id': callId,
      'caller': callerUid,
      'receiver': receiverUid,
      'status': 'ringing',
      'offer': {},
      'answer': {},
      'started_at': DateTime.now().toIso8601String(),
    });

    await _initLocalStream();
    await _createPeerConnection(callId, isOffer: true);
    return callId;
  }

  Future<void> acceptCall(String callId) async {
    await _client.from('calls')
        .update({'status': 'accepted'}).eq('id', callId);
    await _initLocalStream();
    await _createPeerConnection(callId, isOffer: false);
  }

  Future<void> rejectCall(String callId) async {
    await _client.from('calls')
        .update({'status': 'rejected'}).eq('id', callId);
  }

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
    _localStream = await navigator.mediaDevices
        .getUserMedia({'audio': true, 'video': false});
  }

  Future<void> _createPeerConnection(String callId, {required bool isOffer}) async {
    _peerConnection = await createPeerConnection(_iceConfig);
    _inCall = true;
    notifyListeners();

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
      final key = isOffer ? 'caller_candidates' : 'receiver_candidates';
      final candidates = List<dynamic>.from(call[key] ?? []);
      candidates.add(candidate.toMap());
      await _client.from('calls').update({key: candidates}).eq('id', callId);
    };

    if (isOffer) {
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      await _client.from('calls').update({
        'offer': {'type': offer.type, 'sdp': offer.sdp},
      }).eq('id', callId);

      _client.from('calls').stream(primaryKey: ['id']).eq('id', callId)
          .listen((data) async {
        if (data.isEmpty) return;
        final answer = data.first['answer'] as Map<String, dynamic>?;
        if (answer != null && answer['sdp'] != null) {
          if (_peerConnection?.signalingState !=
              RTCSignalingState.RTCSignalingStateStable) {
            await _peerConnection?.setRemoteDescription(
              RTCSessionDescription(answer['sdp'], answer['type']),
            );
          }
        }
      });
    } else {
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
      }
    }
  }

  Stream<Map<String, dynamic>> callStream(String callId) {
    return _client
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('id', callId)
        .map((list) => list.isNotEmpty ? list.first : {});
  }

  Stream<List<Map<String, dynamic>>> incomingCallStream(String myUid) {
    return _client
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('receiver', myUid)
        .map((list) => list
            .where((c) => c['status'] == 'ringing' && c['receiver'] == myUid)
            .toList());
  }

  Future<void> _cleanup() async {
    _localStream?.dispose();
    await _peerConnection?.close();
    _localStream = null;
    _remoteStream = null;
    _peerConnection = null;
    _inCall = false;
    _isMuted = false;
    notifyListeners();
  }
}
