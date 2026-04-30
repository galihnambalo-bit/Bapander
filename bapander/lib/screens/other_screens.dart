// ─── CALL SCREEN ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/call_service.dart';
import '../utils/app_theme.dart';
import '../widgets/avatar_widget.dart';
import '../services/chat_service.dart';
import '../localization/app_localizations.dart';

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
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _seconds++);
      return true;
    });
  }

  String get _duration {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final call = context.watch<CallService>();

    return Scaffold(
      backgroundColor: AppTheme.primaryGreen,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            AvatarWidget(
                name: widget.receiverName,
                photoUrl: widget.receiverPhoto,
                size: 100),
            const SizedBox(height: 20),
            Text(
              widget.receiverName,
              style: const TextStyle(
                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _duration,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CallBtn(
                  icon: call.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  label: call.isMuted ? 'Buka Suara' : 'Matikan',
                  color: Colors.white24,
                  onTap: call.toggleMute,
                ),
                _CallBtn(
                  icon: Icons.call_end_rounded,
                  label: 'Tutup',
                  color: AppTheme.dangerRed,
                  size: 64,
                  onTap: () async {
                    await call.endCall(widget.callId);
                    if (context.mounted) context.pop();
                  },
                ),
                _CallBtn(
                  icon: Icons.volume_up_rounded,
                  label: 'Speaker',
                  color: Colors.white24,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _CallBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _CallBtn({
    required this.icon,
    required this.label,
    required this.color,
    this.size = 56,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: size * 0.42),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── INCOMING CALL SCREEN ────────────────────────────────────

class IncomingCallScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final call = context.read<CallService>();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            const Text(
              'Panggilan Masuk',
              style: TextStyle(color: Colors.white60, fontSize: 16),
            ),
            const SizedBox(height: 32),
            AvatarWidget(name: callerName, photoUrl: callerPhoto, size: 110),
            const SizedBox(height: 24),
            Text(
              callerName,
              style: const TextStyle(
                  color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () async {
                    await call.rejectCall(callId);
                    if (context.mounted) context.pop();
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: const BoxDecoration(
                            color: AppTheme.dangerRed, shape: BoxShape.circle),
                        child: const Icon(Icons.call_end_rounded,
                            color: Colors.white, size: 30),
                      ),
                      const SizedBox(height: 10),
                      const Text('Tolak',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    context.replace('/call/$callId', extra: {
                      'name': callerName,
                      'photo': callerPhoto,
                      'isCaller': false,
                    });
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: const BoxDecoration(
                            color: AppTheme.primaryLight, shape: BoxShape.circle),
                        child: const Icon(Icons.call_rounded,
                            color: Colors.white, size: 30),
                      ),
                      const SizedBox(height: 10),
                      const Text('Terima',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
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

// ─── GROUP SCREEN ────────────────────────────────────────────

class GroupScreen extends StatelessWidget {
  final String groupId;
  const GroupScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Komunitas')),
      body: ChatRoomProxy(chatId: groupId),
    );
  }
}

class ChatRoomProxy extends StatelessWidget {
  final String chatId;
  const ChatRoomProxy({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Group chat'));
  }
}

// ─── CREATE GROUP SCREEN ─────────────────────────────────────

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _language = 'id';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Komunitas'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _create,
            child: const Text('Buat', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryBg,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryLight, width: 1.5),
              ),
              child: const Icon(Icons.add_a_photo_rounded,
                  color: AppTheme.primaryGreen, size: 32),
            ),
          ),
          const SizedBox(height: 24),
          const Text('NAMA KOMUNITAS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF888780),
                  letterSpacing: 0.7)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            decoration:
                const InputDecoration(hintText: 'Contoh: Komunitas Banjar Raya'),
          ),
          const SizedBox(height: 16),
          const Text('DESKRIPSI',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF888780),
                  letterSpacing: 0.7)),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            decoration:
                const InputDecoration(hintText: 'Ceritakan tentang komunitas ini'),
          ),
          const SizedBox(height: 16),
          const Text('BAHASA UTAMA',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF888780),
                  letterSpacing: 0.7)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _language,
            decoration: const InputDecoration(),
            items: AppLanguage.values
                .map((l) => DropdownMenuItem(
                    value: l.code, child: Text('${l.flag} ${l.label}')))
                .toList(),
            onChanged: (v) => setState(() => _language = v ?? 'id'),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final auth = context.read<AuthService>();
    final chatSvc = context.read<ChatService>();

    final groupId = await chatSvc.createGroup(
      name: name,
      creatorUid: auth.currentUid ?? '',
      memberUids: [],
      description: _descCtrl.text.trim(),
      language: _language,
    );

    if (context.mounted) {
      context.pop();
      context.push('/group/$groupId');
    }
  }
}

// ─── PROFILE SCREEN ──────────────────────────────────────────

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: const Center(child: Text('Edit Profil')),
    );
  }
}

// ─── MEDIA VIEWER ────────────────────────────────────────────

class MediaViewerScreen extends StatelessWidget {
  final String mediaUrl;
  final String mediaType;

  const MediaViewerScreen(
      {super.key, required this.mediaUrl, required this.mediaType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(mediaUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
