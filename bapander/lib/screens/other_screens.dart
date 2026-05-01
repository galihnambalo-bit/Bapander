// ignore_for_file: unused_import
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/call_service.dart';
import '../localization/app_localizations.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../utils/app_theme.dart';
import '../widgets/avatar_widget.dart';

// ─── CALL SCREEN ──────────────────────────────────────────
class CallScreen extends StatefulWidget {
  final String callId;
  final String receiverName;
  final String receiverPhoto;
  final bool isCaller;

  const CallScreen({
    super.key,
    required this.callId,
    required this.receiverName,
    required this.receiverPhoto,
    required this.isCaller,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  String _status = 'ringing'; // ringing, accepted, ended, rejected
  int _seconds = 0;
  Timer? _timer;
  bool _webrtcSetup = false;

  @override
  void initState() {
    super.initState();
    _listenCallStatus();
  }

  StreamSubscription<Map<String, dynamic>>? _statusSub;

  void _listenCallStatus() {
    final callSvc = context.read<CallService>();
    _statusSub = callSvc.callStream(widget.callId).listen((data) async {
      if (!mounted) return;
      final status = data['status'] ?? 'ringing';
      setState(() => _status = status);

      if (status == 'accepted' && !_webrtcSetup) {
        _webrtcSetup = true;
        await callSvc.stopRingtone();
        if (widget.isCaller) {
          await callSvc.setupCallerWebRTC(widget.callId);
        }
        _startTimer();
      } else if (status == 'ended' || status == 'rejected') {
        await callSvc.stopRingtone();
        _timer?.cancel();
        if (mounted) context.pop();
      }
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  String _formatDuration(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final callSvc = context.read<CallService>();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            AvatarWidget(name: widget.receiverName, photoUrl: widget.receiverPhoto, size: 100),
            const SizedBox(height: 20),
            Text(widget.receiverName,
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              _status == 'ringing'
                  ? 'Memanggil...'
                  : _status == 'accepted'
                      ? _formatDuration(_seconds)
                      : _status == 'rejected'
                          ? 'Panggilan ditolak'
                          : 'Panggilan berakhir',
              style: TextStyle(
                color: _status == 'accepted' ? Colors.greenAccent : Colors.white60,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Mute button
                Column(
                  children: [
                    GestureDetector(
                      onTap: () => callSvc.toggleMute(),
                      child: Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: callSvc.isMuted
                              ? Colors.white
                              : Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          callSvc.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          color: callSvc.isMuted ? Colors.black : Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(callSvc.isMuted ? 'Unmute' : 'Mute',
                      style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),

                // End call button
                Column(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        await callSvc.endCall(widget.callId);
                        if (context.mounted) context.pop();
                      },
                      child: Container(
                        width: 72, height: 72,
                        decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 32),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Tutup', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),

                // Speaker button
                Column(
                  children: [
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Speaker', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

// ─── INCOMING CALL SCREEN ─────────────────────────────────
class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerName;
  final String callerPhoto;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerName,
    required this.callerPhoto,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  @override
  void initState() {
    super.initState();
    // Play incoming ringtone
    FlutterRingtonePlayer().playRingtone();
  }

  @override
  void dispose() {
    FlutterRingtonePlayer().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 80),
            const Text('Panggilan Masuk',
              style: TextStyle(color: Colors.white60, fontSize: 16)),
            const SizedBox(height: 20),
            // Animasi ring
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.greenAccent.withOpacity(0.3), width: 8),
              ),
              child: AvatarWidget(name: widget.callerName, photoUrl: widget.callerPhoto, size: 104),
            ),
            const SizedBox(height: 20),
            Text(widget.callerName,
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Tolak
                Column(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        await context.read<CallService>().rejectCall(widget.callId);
                        if (context.mounted) context.pop();
                      },
                      child: Container(
                        width: 72, height: 72,
                        decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 32),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Tolak', style: TextStyle(color: Colors.white60, fontSize: 14)),
                  ],
                ),

                // Terima
                Column(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final callSvc = context.read<CallService>();
                        await callSvc.acceptCall(widget.callId);
                        if (context.mounted) {
                          context.pushReplacement('/call/${widget.callId}', extra: {
                            'name': widget.callerName,
                            'photo': widget.callerPhoto,
                            'isCaller': false,
                          });
                        }
                      },
                      child: Container(
                        width: 72, height: 72,
                        decoration: const BoxDecoration(
                          color: Colors.green, shape: BoxShape.circle),
                        child: const Icon(Icons.call_rounded, color: Colors.white, size: 32),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Terima', style: TextStyle(color: Colors.white60, fontSize: 14)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}



// ─── PROFILE SCREEN ───────────────────────────────────────
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: const Center(child: Text('Profil')),
    );
  }
}

// ─── MEDIA VIEWER SCREEN ──────────────────────────────────
class MediaViewerScreen extends StatelessWidget {
  final String mediaUrl;
  final String mediaType;

  const MediaViewerScreen({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: mediaType == 'image'
            ? InteractiveViewer(
                child: Image.network(mediaUrl, fit: BoxFit.contain))
            : const Icon(Icons.play_circle_rounded, color: Colors.white, size: 72),
      ),
    );
  }
}
