import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../models/models.dart';
import '../localization/app_localizations.dart';
import '../utils/app_theme.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/message_bubble.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chatId;
  final String receiverName;
  final String receiverPhoto;
  final String receiverUid;

  const ChatRoomScreen({
    super.key,
    required this.chatId,
    required this.receiverName,
    required this.receiverPhoto,
    required this.receiverUid,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  bool _isRecording = false;
  String? _recordingPath;
  int _recordingSeconds = 0;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendText() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();

    final auth = context.read<AuthService>();
    final chat = context.read<ChatService>();

    await chat.sendMessage(
      chatId: widget.chatId,
      senderId: auth.currentUid ?? '',
      text: text,
    );
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final auth = context.read<AuthService>();
    final chat = context.read<ChatService>();

    final url = await chat.uploadImage(File(picked.path), widget.chatId);
    if (url.isNotEmpty) {
      await chat.sendMessage(
        chatId: widget.chatId,
        senderId: auth.currentUid ?? '',
        text: '',
        type: 'image',
        mediaUrl: url,
      );
    }
    _scrollToBottom();
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;

    final dir = await getTemporaryDirectory();
    _recordingPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _recordingPath!,
    );
    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
    });

    // Count seconds
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!_isRecording) return false;
      setState(() => _recordingSeconds++);
      return true;
    });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    setState(() => _isRecording = false);

    if (path == null) return;

    final auth = context.read<AuthService>();
    final chat = context.read<ChatService>();

    final url = await chat.uploadVoiceNote(File(path), widget.chatId);
    if (url.isNotEmpty) {
      await chat.sendMessage(
        chatId: widget.chatId,
        senderId: auth.currentUid ?? '',
        text: '',
        type: 'voice',
        mediaUrl: url,
        duration: _recordingSeconds,
      );
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final chat = context.watch<ChatService>();
    final loc = context.watch<LocalizationProvider>();
    final myUid = auth.currentUid ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            AvatarWidget(
                name: widget.receiverName,
                photoUrl: widget.receiverPhoto,
                size: 36),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.receiverName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                StreamBuilder(
                  stream: context
                      .read<AuthService>()
                      .userStream(widget.receiverUid),
                  builder: (ctx, snap) {
                    final data =
                        snap.data as Map<String, dynamic>?;
                    final online = data?['online'] ?? false;
                    return Text(
                      online ? loc.t('online') : loc.t('typing'),
                      style: TextStyle(
                        fontSize: 11,
                        color: online
                            ? Colors.greenAccent[100]
                            : Colors.white60,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_rounded),
            onPressed: () async {
              final callSvc = context.read<CallService>();
              // Start call handled in CallScreen
              context.push('/call/new_${DateTime.now().millisecondsSinceEpoch}',
                  extra: {
                    'name': widget.receiverName,
                    'photo': widget.receiverPhoto,
                    'isCaller': true,
                  });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: chat.messagesStream(widget.chatId),
              builder: (context, snap) {
                final messages = snap.data ?? <Map<String, dynamic>>[];
                _scrollToBottom();

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Kirim pesan pertamamu!',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) {
                    final rawMsg = messages[i];
                    final msg = rawMsg;
                    final isMe = msg.sender == myUid;
                    final showDate = i == 0 ||
                        _isDifferentDay(messages[i - 1].timestamp,
                            msg.timestamp);

                    return Column(
                      children: [
                        if (showDate) _DateDivider(timestamp: msg.timestamp),
                        MessageBubble(
                          message: msg,
                          isMe: isMe,
                          onMediaTap: () {
                            if (msg.type == MessageType.image) {
                              context.push('/media', extra: {
                                'url': msg.mediaUrl,
                                'type': 'image',
                              });
                            }
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Recording indicator
          if (_isRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.primaryBg,
              child: Row(
                children: [
                  const Icon(Icons.mic, color: AppTheme.dangerRed, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Merekam... ${_recordingSeconds}s',
                    style: const TextStyle(
                        color: AppTheme.dangerRed, fontSize: 13),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _recorder.cancel().then(
                          (_) => setState(() => _isRecording = false),
                        ),
                    child: const Text('Batal'),
                  ),
                ],
              ),
            ),

          // Input Bar
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file_rounded),
                  onPressed: _pickImage,
                  color: const Color(0xFF888780),
                ),
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: InputDecoration(
                      hintText: loc.t('new_message'),
                      filled: true,
                      fillColor: const Color(0xFFF0F2F1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendText(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (_msgCtrl.text.isNotEmpty) {
                      _sendText();
                    } else if (_isRecording) {
                      _stopRecording();
                    } else {
                      _startRecording();
                    }
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isRecording
                          ? Icons.stop_rounded
                          : _msgCtrl.text.isEmpty
                              ? Icons.mic_rounded
                              : Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isDifferentDay(int ts1, int ts2) {
    final d1 = DateTime.fromMillisecondsSinceEpoch(ts1);
    final d2 = DateTime.fromMillisecondsSinceEpoch(ts2);
    return d1.day != d2.day || d1.month != d2.month || d1.year != d2.year;
  }
}

class _DateDivider extends StatelessWidget {
  final int timestamp;
  const _DateDivider({required this.timestamp});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    String label;
    if (dt.day == now.day) {
      label = 'Hari ini';
    } else if (dt.day == now.day - 1) {
      label = 'Kemarin';
    } else {
      label = '${dt.day}/${dt.month}/${dt.year}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF888780)),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

// Temporary import shim - CallService will be imported properly
class CallService {}
