import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';

class CallService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
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

  // ─── START CALL (CALLER) ──────────────────────────────────
  Future<String> startCall({
    required String callerUid,
    required String receiverUid,
  }) async {
    final callId = _uuid.v4();

    await _db.collection('calls').doc(callId).set({
      'caller': callerUid,
      'receiver': receiverUid,
      'status': 'ringing',
      'offer': {},
      'answer': {},
      'started_at': DateTime.now().millisecondsSinceEpoch,
    });

    await _initLocalStream();
    await _createPeerConnection(callId, isOffer: true);

    return callId;
  }

  // ─── ACCEPT CALL (RECEIVER) ───────────────────────────────
  Future<void> acceptCall(String callId) async {
    await _db.collection('calls').doc(callId).update({'status': 'accepted'});
    await _initLocalStream();
    await _createPeerConnection(callId, isOffer: false);
  }

  // ─── REJECT CALL ─────────────────────────────────────────
  Future<void> rejectCall(String callId) async {
    await _db.collection('calls').doc(callId).update({'status': 'rejected'});
  }

  // ─── END CALL ────────────────────────────────────────────
  Future<void> endCall(String callId) async {
    await _db.collection('calls').doc(callId).update({
      'status': 'ended',
      'ended_at': DateTime.now().millisecondsSinceEpoch,
    });
    await _cleanup();
  }

  // ─── TOGGLE MUTE ─────────────────────────────────────────
  void toggleMute() {
    _isMuted = !_isMuted;
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !_isMuted);
    notifyListeners();
  }

  // ─── INIT LOCAL STREAM ───────────────────────────────────
  Future<void> _initLocalStream() async {
    final constraints = {
      'audio': true,
      'video': false,
    };
    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
  }

  // ─── CREATE PEER CONNECTION ───────────────────────────────
  Future<void> _createPeerConnection(String callId, {required bool isOffer}) async {
    _peerConnection = await createPeerConnection(_iceConfig);
    _inCall = true;
    notifyListeners();

    // Add local tracks
    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    // Handle remote stream
    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        notifyListeners();
      }
    };

    // ICE candidate handling
    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      _db
          .collection('calls')
          .doc(callId)
          .collection(isOffer ? 'callerCandidates' : 'receiverCandidates')
          .add(candidate.toMap());
    };

    if (isOffer) {
      // Create offer
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      await _db.collection('calls').doc(callId).update({
        'offer': {'type': offer.type, 'sdp': offer.sdp},
      });

      // Listen for answer
      _db.collection('calls').doc(callId).snapshots().listen((snap) async {
        final data = snap.data();
        if (data == null) return;
        final answer = data['answer'] as Map<String, dynamic>?;
        if (answer != null && answer['sdp'] != null) {
          final desc = RTCSessionDescription(answer['sdp'], answer['type']);
          if (_peerConnection?.signalingState !=
              RTCSignalingState.RTCSignalingStateStable) {
            await _peerConnection?.setRemoteDescription(desc);
          }
        }
      });

      // Listen for receiver ICE candidates
      _db
          .collection('calls')
          .doc(callId)
          .collection('receiverCandidates')
          .snapshots()
          .listen((snap) {
        for (var doc in snap.docChanges) {
          if (doc.type == DocumentChangeType.added) {
            final data = doc.doc.data()!;
            _peerConnection?.addCandidate(RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ));
          }
        }
      });
    } else {
      // Get offer and create answer
      final callDoc = await _db.collection('calls').doc(callId).get();
      final offerData = callDoc.data()?['offer'] as Map<String, dynamic>?;
      if (offerData != null) {
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(offerData['sdp'], offerData['type']),
        );
        final answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);
        await _db.collection('calls').doc(callId).update({
          'answer': {'type': answer.type, 'sdp': answer.sdp},
        });
      }

      // Listen for caller ICE candidates
      _db
          .collection('calls')
          .doc(callId)
          .collection('callerCandidates')
          .snapshots()
          .listen((snap) {
        for (var doc in snap.docChanges) {
          if (doc.type == DocumentChangeType.added) {
            final data = doc.doc.data()!;
            _peerConnection?.addCandidate(RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ));
          }
        }
      });
    }
  }

  // ─── CALL STATUS STREAM ───────────────────────────────────
  Stream<CallModel> callStream(String callId) {
    return _db.collection('calls').doc(callId).snapshots().map(
          (doc) => CallModel.fromMap(doc.data()!, doc.id),
        );
  }

  // ─── INCOMING CALL STREAM ─────────────────────────────────
  Stream<List<CallModel>> incomingCallStream(String myUid) {
    return _db
        .collection('calls')
        .where('receiver', isEqualTo: myUid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CallModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ─── CLEANUP ─────────────────────────────────────────────
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
