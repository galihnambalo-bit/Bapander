import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../utils/supabase_config.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/sticker_picker.dart';
import '../models/sticker_model.dart';

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
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  bool _hasText = false;

  bool _isRecording = false;
  bool _showStickers = false;
  String? _playingUrl;

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(() {
      setState(() => _hasText = _textCtrl.text.isNotEmpty);
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();

    final auth = context.read<AuthService>();
    final chat = context.read<ChatService>();
    await chat.sendMessage(
      chatId: widget.chatId,
      senderId: auth.currentUid ?? '',
      text: text,
      type: 'text',
    );
    _scrollToBottom();
  }

  Future<void> _sendImage({bool fromCamera = false}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked == null) return;

    final auth = context.read<AuthService>();
    final chat = context.read<ChatService>();

    final url = await chat.uploadImage(File(picked.path), widget.chatId);
    await chat.sendMessage(
      chatId: widget.chatId,
      senderId: auth.currentUid ?? '',
      text: '',
      type: 'image',
      mediaUrl: url,
    );
    _scrollToBottom();
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Kirim', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachItem(
                  icon: Icons.photo_rounded,
                  label: 'Galeri',
                  color: const Color(0xFF7C4DFF),
                  onTap: () { Navigator.pop(ctx); _sendImage(); },
                ),
                _AttachItem(
                  icon: Icons.camera_alt_rounded,
                  label: 'Kamera',
                  color: const Color(0xFFE91E63),
                  onTap: () { Navigator.pop(ctx); _sendImage(fromCamera: true); },
                ),
                _AttachItem(
                  icon: Icons.insert_drive_file_rounded,
                  label: 'Dokumen',
                  color: const Color(0xFF2196F3),
                  onTap: () { Navigator.pop(ctx); _sendDocument(); },
                ),
                _AttachItem(
                  icon: Icons.location_on_rounded,
                  label: 'Lokasi',
                  color: const Color(0xFF4CAF50),
                  onTap: () { Navigator.pop(ctx); _sendLocation(); },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _sendDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'zip'],
        withData: false,
        withReadStream: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final fileName = file.name;
      final fileSize = file.size;
      final filePath = file.path;

      if (filePath == null) return;

      setState(() => _isLoading = true);

      final auth = context.read<AuthService>();
      final chat = context.read<ChatService>();
      final uid = auth.currentUid ?? '';

      // Upload ke Supabase Storage
      final fileBytes = File(filePath).readAsBytesSync();
      final path = 'documents/$uid/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      
      await SupabaseConfig.client.storage
          .from('media')
          .uploadBinary(path, fileBytes);
      
      final fileUrl = SupabaseConfig.client.storage
          .from('media')
          .getPublicUrl(path);

      // Format ukuran file
      String sizeStr;
      if (fileSize < 1024) {
        sizeStr = '\${fileSize}B';
      } else if (fileSize < 1024 * 1024) {
        sizeStr = '\${(fileSize / 1024).toStringAsFixed(1)}KB';
      } else {
        sizeStr = '\${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
      }

      await chat.sendMessage(
        chatId: widget.chatId,
        senderId: uid,
        text: '📄 $fileName ($sizeStr)',
        type: 'document',
        mediaUrl: fileUrl,
      );

      setState(() => _isLoading = false);
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal kirim dokumen: \$e')));
    }
  }

  Future<void> _sendLocation() async {
    try {
      final auth = context.read<AuthService>();
      final chat = context.read<ChatService>();
      
      // Minta izin lokasi
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin lokasi ditolak')));
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      final lat = position.latitude.toStringAsFixed(6);
      final lng = position.longitude.toStringAsFixed(6);
      final mapsUrl = 'https://maps.google.com/?q=$lat,$lng';
      
      await chat.sendMessage(
        chatId: widget.chatId,
        senderId: auth.currentUid ?? '',
        text: '📍 Lokasi saya: $mapsUrl',
        type: 'text',
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal kirim lokasi: $e')));
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature segera hadir!'), backgroundColor: AppTheme.primaryGreen));
  }

  Future<void> _sendSticker(Sticker sticker) async {
    final auth = context.read<AuthService>();
    final chat = context.read<ChatService>();
    setState(() => _showStickers = false);
    await chat.sendMessage(
      chatId: widget.chatId,
      senderId: auth.currentUid ?? '',
      text: sticker.emoji,
      type: 'sticker',
    );
    _scrollToBottom();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) return;
    final dir = await getTemporaryDirectory();
    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac',
    );
    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);
    if (path == null) return;

    final auth = context.read<AuthService>();
    final chat = context.read<ChatService>();
    final url = await chat.uploadVoiceNote(File(path), widget.chatId);
    await chat.sendMessage(
      chatId: widget.chatId,
      senderId: auth.currentUid ?? '',
      text: '',
      type: 'voice',
      mediaUrl: url,
    );
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final chat = context.watch<ChatService>();
    final myUid = auth.currentUid ?? '';

    return Scaffold(
      // Background chat seperti WA
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        leading: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ],
        ),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () => context.push('/user/\${widget.receiverUid}'),
          child: Row(
          children: [
            AvatarWidget(name: widget.receiverName, photoUrl: widget.receiverPhoto, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.receiverName,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  StreamBuilder<Map<String, dynamic>?>(
                    stream: auth.userStream(widget.receiverUid),
                    builder: (ctx, snap) {
                      final online = snap.data?['online'] ?? false;
                      return Text(
                        online ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: online ? Colors.greenAccent[100] : Colors.white60,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_rounded, color: Colors.white),
            onPressed: () async {
              final callSvc = context.read();
              final callId = await callSvc.startCall(
                callerUid: myUid,
                receiverUid: widget.receiverUid,
              );
              if (context.mounted) {
                context.push('/call/$callId', extra: {
                  'name': widget.receiverName,
                  'photo': widget.receiverPhoto,
                  'isCaller': true,
                });
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onSelected: (val) {
              if (val == 'profile') {
                context.push('/user/\${widget.receiverUid}');
              } else if (val == 'clear') {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Hapus Pesan?'),
                    content: const Text('Semua pesan akan dihapus'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await context.read<ChatService>().deleteChat(widget.chatId);
                          if (context.mounted) context.pop();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Hapus'),
                      ),
                    ],
                  ),
                );
              } else if (val == 'search') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cari pesan segera hadir!')));
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'profile', child: Row(children: [
                Icon(Icons.person_rounded), SizedBox(width: 12), Text('Lihat Profil'),
              ])),
              const PopupMenuItem(value: 'search', child: Row(children: [
                Icon(Icons.search_rounded), SizedBox(width: 12), Text('Cari Pesan'),
              ])),
              const PopupMenuItem(value: 'clear', child: Row(children: [
                Icon(Icons.delete_rounded, color: Colors.red), SizedBox(width: 12),
                Text('Hapus Chat', style: TextStyle(color: Colors.red)),
              ])),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ── PESAN ──────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: chat.messagesStream(widget.chatId),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snap.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text('Mulai percakapan dengan ${widget.receiverName}',
                            style: const TextStyle(color: Color(0xFF888780))),
                      ],
                    ),
                  );
                }

                _scrollToBottom();

                // Balik urutan pesan - terbaru di bawah
                final reversed = messages.reversed.toList();
                return ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  itemCount: reversed.length,
                  itemBuilder: (ctx, i) {
                    final messages = reversed;
                    final msg = messages[i];
                    final isMe = (msg['sender']?.toString() ?? '') == myUid;
                    final prevMsg = i > 0 ? messages[i - 1] : null;
                    final showDate = prevMsg == null ||
                        !_isSameDay(
                          DateTime.tryParse(prevMsg['timestamp']?.toString() ?? '') ?? DateTime.now(),
                          DateTime.tryParse(msg['timestamp']?.toString() ?? '') ?? DateTime.now(),
                        );

                    return Column(
                      children: [
                        if (showDate) _DateDivider(timestamp: msg['timestamp']?.toString() ?? ''),
                        _MessageBubble(
                          msg: msg,
                          isMe: isMe,
                          playingUrl: _playingUrl,
                          onPlayAudio: (url) async {
                            if (_playingUrl == url) {
                              await _audioPlayer.stop();
                              setState(() => _playingUrl = null);
                            } else {
                              setState(() => _playingUrl = url);
                              await _audioPlayer.play(UrlSource(url));
                              _audioPlayer.onPlayerComplete.listen((_) {
                                setState(() => _playingUrl = null);
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

          // ── STICKER PICKER ──────────────────────────────────
          if (_showStickers)
            StickerPicker(onStickerSelected: _sendSticker),

          // ── INPUT BAR ─────────────────────────────────────
          Container(
            color: const Color(0xFFF0F0F0),
            padding: EdgeInsets.only(
              left: 8, right: 8, top: 6,
              bottom: MediaQuery.of(context).padding.bottom + 6,
            ),
            child: Row(
              children: [
                // Sticker/Emoji button
                IconButton(
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _showStickers ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
                      key: ValueKey(_showStickers),
                      color: _showStickers ? AppTheme.primaryGreen : const Color(0xFF888780),
                    ),
                  ),
                  onPressed: () {
                    setState(() => _showStickers = !_showStickers);
                    if (_showStickers) FocusScope.of(context).unfocus();
                  },
                ),

                // Text input
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textCtrl,
                            maxLines: 4,
                            minLines: 1,
                            decoration: const InputDecoration(
                              hintText: 'Ketik pesan...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            onSubmitted: (_) => _sendText(),
                          ),
                        ),
                        // Attachment button
                        IconButton(
                          icon: const Icon(Icons.attach_file_rounded, color: Color(0xFF888780)),
                          onPressed: _showAttachmentMenu,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Camera button
                IconButton(
                  icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFF888780)),
                  onPressed: () => _sendImage(fromCamera: true),
                ),
                const SizedBox(width: 2),
                // Send / Record button
                GestureDetector(
                  onTap: _hasText ? _sendText : null,
                  onLongPressStart: !_hasText ? (_) => _startRecording() : null,
                  onLongPressEnd: !_hasText ? (_) => _stopRecording() : null,
                  child: Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.red : AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isRecording
                          ? Icons.stop_rounded
                          : _hasText
                              ? Icons.send_rounded
                              : Icons.mic_rounded,
                      color: Colors.white,
                      size: 22,
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

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── MESSAGE BUBBLE ────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final String? playingUrl;
  final Function(String) onPlayAudio;

  const _MessageBubble({
    required this.msg,
    required this.isMe,
    required this.playingUrl,
    required this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
    final type = msg['type'] ?? 'text';
    final text = msg['text'] ?? '';
    final mediaUrl = msg['media_url'] ?? '';
    final timestamp = msg['timestamp']?.toString() ?? '';
    final status = msg['status'] ?? 'sent';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isMe ? 60 : 4,
          right: isMe ? 4 : 60,
          bottom: 2,
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF0084FF) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 1)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Content
                  if (type == 'text' || type == 'sticker')
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Text(
                        text.isEmpty ? '...' : text,
                        style: TextStyle(
                          fontSize: type == 'sticker' ? 36 : 15,
                          color: isMe ? Colors.white : const Color(0xFF111111),
                          height: 1.3,
                        ),
                      ),
                    )
                  else if (type == 'image' && mediaUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                      child: GestureDetector(
                        onTap: () => context.push('/media', extra: {'url': mediaUrl, 'type': 'image'}),
                        child: CachedNetworkImage(
                          imageUrl: mediaUrl,
                          width: 200, height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else if (type == 'document' && mediaUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: GestureDetector(
                        onTap: () async {
                          // Buka dokumen
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Membuka: $text')));
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: isMe ? Colors.white24 : const Color(0xFF0084FF).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.insert_drive_file_rounded,
                                color: isMe ? Colors.white : const Color(0xFF0084FF), size: 26),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    text.replaceAll('📄 ', ''),
                                    style: TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w500,
                                      color: isMe ? Colors.white : const Color(0xFF111111),
                                    ),
                                    maxLines: 2, overflow: TextOverflow.ellipsis,
                                  ),
                                  Text('Ketuk untuk buka',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isMe ? Colors.white60 : const Color(0xFF888780),
                                    )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (type == 'voice' && mediaUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => onPlayAudio(mediaUrl),
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: isMe ? AppTheme.primaryGreen : const Color(0xFF888780),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                playingUrl == mediaUrl ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                color: Colors.white, size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 100, height: 2,
                                decoration: BoxDecoration(
                                  color: isMe ? AppTheme.primaryGreen.withOpacity(0.5) : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text('Voice note', style: TextStyle(fontSize: 11, color: Color(0xFF888780))),
                            ],
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),

                  // Timestamp & status
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(timestamp),
                          style: const TextStyle(fontSize: 10, color: Color(0xFF888780)),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 3),
                          Icon(
                            status == 'read' ? Icons.done_all_rounded : Icons.done_rounded,
                            size: 14,
                            color: status == 'read' ? Colors.lightBlueAccent : Colors.white60,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

// ── DATE DIVIDER ──────────────────────────────────────────
class _DateDivider extends StatelessWidget {
  final String timestamp;
  const _DateDivider({required this.timestamp});

  @override
  Widget build(BuildContext context) {
    String label = '';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        label = 'Hari ini';
      } else if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) {
        label = 'Kemarin';
      } else {
        label = DateFormat('d MMMM yyyy', 'id').format(dt);
      }
    } catch (_) {
      label = '';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFD9FDD3),
            borderRadius: BorderRadius.circular(100),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)],
          ),
          child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF54656F), fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}

// ── ATTACHMENT ITEM ────────────────────────────────────────
class _AttachItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
