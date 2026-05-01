import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:file_picker/file_picker.dart';

import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/call_service.dart';
import '../utils/app_theme.dart';
import '../utils/supabase_config.dart';
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

  bool _isRecording = false;
  bool _showStickers = false;
  bool _hasText = false;
  bool _isUploading = false;
  String? _playingUrl;
  final List<Map<String, dynamic>> _localMessages = [];

  // Reply state
  Map<String, dynamic>? _replyingTo;

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(() => setState(() => _hasText = _textCtrl.text.isNotEmpty));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthService>();
      context.read<ChatService>().markMessagesAsRead(widget.chatId, auth.currentUid ?? '');
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

  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    final auth = context.read<AuthService>();
    final chat = context.read<ChatService>();
    final myUid = auth.currentUid ?? '';
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      _localMessages.insert(0, {
        'id': tempId, 'sender': myUid, 'text': text,
        'type': 'text', 'media_url': '',
        'timestamp': DateTime.now().toIso8601String(), 'status': 'sending',
        'reply_to': _replyingTo != null ? {
          'id': _replyingTo!['id'],
          'text': _replyingTo!['text'],
          'sender': _replyingTo!['sender'],
        } : null,
      });
      _replyingTo = null;
    });

    // Kirim ke server
    chat.sendMessage(
      chatId: widget.chatId, senderId: myUid, text: text, type: 'text',
      replyTo: _replyingTo,
    ).then((_) {
      // Hapus optimistic message setelah server confirm
      if (mounted) setState(() => _localMessages.removeWhere((m) => m['id'] == tempId));
    }).catchError((e) {
      // Kalau gagal, tandai error
      if (mounted) setState(() {
        final idx = _localMessages.indexWhere((m) => m['id'] == tempId);
        if (idx >= 0) _localMessages[idx] = {..._localMessages[idx], 'status': 'error'};
      });
    });
  }

  Future<void> _sendImage({bool fromCamera = false}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    setState(() => _isUploading = true);
    final auth = context.read<AuthService>();
    final chat = context.read<ChatService>();
    final url = await chat.uploadImage(File(picked.path), widget.chatId);
    await chat.sendMessage(chatId: widget.chatId, senderId: auth.currentUid ?? '',
      text: '', type: 'image', mediaUrl: url);
    setState(() => _isUploading = false);
  }

  Future<void> _sendDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'zip']);
      if (result == null || result.files.isEmpty || result.files.first.path == null) return;
      setState(() => _isUploading = true);
      final auth = context.read<AuthService>();
      final chat = context.read<ChatService>();
      final file = result.files.first;
      final bytes = await File(file.path!).readAsBytes();
      final path = 'documents/${auth.currentUid}/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      await SupabaseConfig.client.storage.from('media').uploadBinary(path, bytes);
      final url = SupabaseConfig.client.storage.from('media').getPublicUrl(path);
      final size = file.size;
      final sizeStr = size < 1024 ? '${size}B'
          : size < 1024*1024 ? '${(size/1024).toStringAsFixed(1)}KB'
          : '${(size/(1024*1024)).toStringAsFixed(1)}MB';
      await chat.sendMessage(chatId: widget.chatId, senderId: auth.currentUid ?? '',
        text: '📄 ${file.name} ($sizeStr)', type: 'document', mediaUrl: url);
      setState(() => _isUploading = false);
    } catch (e) {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _sendLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition();
      final url = 'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';
      final auth = context.read<AuthService>();
      await context.read<ChatService>().sendMessage(
        chatId: widget.chatId, senderId: auth.currentUid ?? '',
        text: '📍 Lokasi: $url', type: 'text');
    } catch (_) {}
  }

  Future<void> _sendSticker(Sticker sticker) async {
    setState(() => _showStickers = false);
    final auth = context.read<AuthService>();
    await context.read<ChatService>().sendMessage(
      chatId: widget.chatId, senderId: auth.currentUid ?? '',
      text: sticker.emoji, type: 'sticker');
  }

  Future<void> _startRecording() async {
    if (!await _audioRecorder.hasPermission()) return;
    final dir = await getTemporaryDirectory();
    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac');
    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);
    if (path == null) return;
    final auth = context.read<AuthService>();
    final chat = context.read<ChatService>();
    final url = await chat.uploadVoiceNote(File(path), widget.chatId);
    await chat.sendMessage(chatId: widget.chatId, senderId: auth.currentUid ?? '',
      text: '', type: 'voice', mediaUrl: url);
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Kirim', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _AttachItem(icon: Icons.photo_rounded, label: 'Galeri', color: const Color(0xFF7C4DFF),
              onTap: () { Navigator.pop(ctx); _sendImage(); }),
            _AttachItem(icon: Icons.camera_alt_rounded, label: 'Kamera', color: const Color(0xFFE91E63),
              onTap: () { Navigator.pop(ctx); _sendImage(fromCamera: true); }),
            _AttachItem(icon: Icons.insert_drive_file_rounded, label: 'Dokumen', color: const Color(0xFF2196F3),
              onTap: () { Navigator.pop(ctx); _sendDocument(); }),
            _AttachItem(icon: Icons.location_on_rounded, label: 'Lokasi', color: const Color(0xFF4CAF50),
              onTap: () { Navigator.pop(ctx); _sendLocation(); }),
          ]),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  void _showMessageOptions(Map<String, dynamic> msg, bool isMe) {
    final text = msg['text'] ?? '';
    final msgId = msg['id']?.toString() ?? '';
    
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          
          // Reaksi emoji cepat
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['👍','❤️','😂','😮','😢','🙏'].map((emoji) =>
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _addReaction(msgId, emoji);
                  },
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: const Color(0xFFF6F8F7), shape: BoxShape.circle),
                    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
                  ),
                )).toList()),
          ),
          const Divider(height: 1),

          // Menu aksi
          _MsgOption(icon: Icons.reply_rounded, label: 'Balas', onTap: () {
            Navigator.pop(ctx);
            setState(() => _replyingTo = msg);
          }),
          if (text.isNotEmpty)
            _MsgOption(icon: Icons.copy_rounded, label: 'Salin', onTap: () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pesan disalin'), duration: Duration(seconds: 1)));
            }),
          _MsgOption(icon: Icons.forward_rounded, label: 'Teruskan', onTap: () {
            Navigator.pop(ctx);
            _forwardMessage(msg);
          }),
          _MsgOption(icon: Icons.push_pin_rounded, label: 'Sematkan', onTap: () {
            Navigator.pop(ctx);
            _pinMessage(msgId, text);
          }),
          _MsgOption(icon: Icons.bookmark_border_rounded, label: 'Simpan', onTap: () {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pesan disimpan ✅'), backgroundColor: AppTheme.primaryGreen));
          }),
          if (isMe) ...[
            _MsgOption(icon: Icons.edit_rounded, label: 'Edit', onTap: () {
              Navigator.pop(ctx);
              _editMessage(msgId, text);
            }),
            _MsgOption(icon: Icons.delete_rounded, label: 'Hapus untuk semua',
              color: Colors.red, onTap: () {
              Navigator.pop(ctx);
              _deleteMessage(msgId);
            }),
          ],
        ]),
      ),
    );
  }

  Future<void> _addReaction(String msgId, String emoji) async {
    await SupabaseConfig.client.from('messages').update({
      'reactions': {emoji: (DateTime.now().millisecondsSinceEpoch).toString()},
    }).eq('id', msgId);
  }

  Future<void> _deleteMessage(String msgId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Pesan?'),
        content: const Text('Pesan akan dihapus untuk semua orang'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus')),
        ],
      ),
    );
    if (confirm == true) {
      await SupabaseConfig.client.from('messages')
          .update({'text': '🚫 Pesan dihapus', 'topic': 'deleted', 'media_url': ''})
          .eq('id', msgId);
    }
  }

  Future<void> _editMessage(String msgId, String currentText) async {
    final ctrl = TextEditingController(text: currentText);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Pesan'),
        content: TextField(controller: ctrl, maxLines: 4,
          decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Simpan')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await SupabaseConfig.client.from('messages')
          .update({'text': '$result ✏️'}).eq('id', msgId);
    }
  }

  Future<void> _pinMessage(String msgId, String text) async {
    await SupabaseConfig.client.from('chats')
        .update({'pinned_message': text, 'pinned_message_id': msgId})
        .eq('id', widget.chatId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pesan disematkan 📌'), backgroundColor: AppTheme.primaryGreen));
  }

  Future<void> _forwardMessage(Map<String, dynamic> msg) async {
    final auth = context.read<AuthService>();
    final users = await auth.getAllUsers(auth.currentUid ?? '');
    if (!mounted) return;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          const Text('Teruskan ke...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (ctx2, i) {
                final u = users[i];
                return ListTile(
                  leading: AvatarWidget(name: u['name'] ?? '', photoUrl: u['photo'] ?? '', size: 44),
                  title: Text(u['name'] ?? ''),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final chatSvc = context.read<ChatService>();
                    final chatId = await chatSvc.getOrCreateChat(auth.currentUid ?? '', u['id']);
                    await chatSvc.sendMessage(
                      chatId: chatId, senderId: auth.currentUid ?? '',
                      text: '↪️ ${msg['text'] ?? ''}', type: msg['topic'] ?? 'text',
                      mediaUrl: msg['media_url'] ?? '');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Diteruskan ke ${u['name']} ✅'),
                        backgroundColor: AppTheme.primaryGreen));
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final chat = context.watch<ChatService>();
    final myUid = auth.currentUid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop()),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () => context.push('/user/${widget.receiverUid}'),
          child: Row(children: [
            AvatarWidget(name: widget.receiverName, photoUrl: widget.receiverPhoto, size: 38),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.receiverName,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              StreamBuilder<Map<String, dynamic>?>(
                stream: auth.userStream(widget.receiverUid),
                builder: (ctx, snap) {
                  final online = snap.data?['online'] ?? false;
                  return Text(online ? 'Online' : 'Offline',
                    style: TextStyle(color: online ? Colors.greenAccent[100] : Colors.white60, fontSize: 12));
                }),
            ])),
          ]),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_rounded, color: Colors.white),
            onPressed: () async {
              try {
                final callSvc = context.read<CallService>();
                final callId = await callSvc.startCall(callerUid: myUid, receiverUid: widget.receiverUid);
                if (context.mounted) context.push('/call/$callId', extra: {
                  'name': widget.receiverName, 'photo': widget.receiverPhoto, 'isCaller': true});
              } catch (e) {
                if (e.toString().contains('user_offline') && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${widget.receiverName} sedang tidak aktif'),
                    backgroundColor: Colors.red));
                }
              }
            }),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onSelected: (val) {
              if (val == 'profile') context.push('/user/${widget.receiverUid}');
              else if (val == 'clear') _confirmClearChat();
              else if (val == 'search') ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cari pesan segera hadir!')));
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'profile', child: Row(children: [
                Icon(Icons.person_rounded), SizedBox(width: 12), Text('Lihat Profil')])),
              const PopupMenuItem(value: 'search', child: Row(children: [
                Icon(Icons.search_rounded), SizedBox(width: 12), Text('Cari Pesan')])),
              const PopupMenuItem(value: 'clear', child: Row(children: [
                Icon(Icons.delete_rounded, color: Colors.red), SizedBox(width: 12),
                Text('Hapus Chat', style: TextStyle(color: Colors.red))])),
            ]),
        ],
      ),
      body: Column(children: [
        if (_isUploading) const LinearProgressIndicator(color: AppTheme.primaryGreen),

        // Pinned message banner
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: SupabaseConfig.client.from('chats').stream(primaryKey: ['id'])
              .eq('id', widget.chatId)
              .map((l) => List<Map<String, dynamic>>.from(l)),
          builder: (ctx, snap) {
            final pinned = snap.data?.firstOrNull?['pinned_message']?.toString() ?? '';
            if (pinned.isEmpty) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.primaryBg,
              child: Row(children: [
                const Icon(Icons.push_pin_rounded, size: 14, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Expanded(child: Text(pinned, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppTheme.primaryGreen))),
              ]),
            );
          }),

        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: chat.messagesStream(widget.chatId),
            builder: (ctx, snap) {
              
              final messages = snap.data ?? [];
              final seen = <String>{};
              final allMsgs = [..._localMessages];
              for (final m in messages.reversed) {
                final id = m['id']?.toString() ?? '';
                if (!seen.contains(id)) { seen.add(id); allMsgs.add(m); }
              }

              if (allMsgs.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text('Mulai percakapan dengan ${widget.receiverName}',
                    style: const TextStyle(color: Color(0xFF888780))),
                ]));
              }

              return ListView.builder(
                controller: _scrollCtrl,
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                itemCount: allMsgs.length,
                itemBuilder: (ctx, i) {
                  final msg = allMsgs[i];
                  final isMe = (msg['sender']?.toString() ?? '') == myUid;
                  final nextMsg = i > 0 ? allMsgs[i - 1] : null;
                  final showDate = nextMsg == null || !_isSameDay(
                    DateTime.tryParse(msg['timestamp']?.toString() ?? '') ?? DateTime.now(),
                    DateTime.tryParse(nextMsg['timestamp']?.toString() ?? '') ?? DateTime.now());
                  return Column(children: [
                    GestureDetector(
                      onLongPress: () => _showMessageOptions(msg, isMe),
                      child: _MessageBubble(
                        msg: msg, isMe: isMe,
                        playingUrl: _playingUrl,
                        onPlayAudio: (url) async {
                          if (_playingUrl == url) {
                            await _audioPlayer.stop();
                            setState(() => _playingUrl = null);
                          } else {
                            setState(() => _playingUrl = url);
                            await _audioPlayer.play(UrlSource(url));
                            _audioPlayer.onPlayerComplete.listen((_) {
                              if (mounted) setState(() => _playingUrl = null);
                            });
                          }
                        },
                        onReply: () => setState(() => _replyingTo = msg),
                      ),
                    ),
                    if (showDate) _DateDivider(timestamp: msg['timestamp']?.toString() ?? ''),
                  ]);
                },
              );
            },
          ),
        ),

        // Reply preview bar
        if (_replyingTo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AppTheme.primaryBg,
            child: Row(children: [
              Container(width: 3, height: 36, color: AppTheme.primaryGreen,
                margin: const EdgeInsets.only(right: 8)),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Membalas', style: TextStyle(fontSize: 11, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
                Text(_replyingTo!['text']?.toString() ?? '',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF888780))),
              ])),
              IconButton(icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => setState(() => _replyingTo = null)),
            ]),
          ),

        if (_showStickers) StickerPicker(onStickerSelected: _sendSticker),

        Container(
          color: const Color(0xFFF0F0F0),
          padding: EdgeInsets.only(
            left: 8, right: 8, top: 6,
            bottom: MediaQuery.of(context).padding.bottom + 6),
          child: Row(children: [
            IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _showStickers ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
                  key: ValueKey(_showStickers),
                  color: _showStickers ? AppTheme.primaryGreen : const Color(0xFF888780))),
              onPressed: () {
                setState(() => _showStickers = !_showStickers);
                if (_showStickers) FocusScope.of(context).unfocus();
              }),
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      maxLines: 4, minLines: 1,
                      decoration: const InputDecoration(
                        hintText: 'Ketik pesan...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.attach_file_rounded, color: Color(0xFF888780)),
                    onPressed: _showAttachmentMenu),
                ]),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFF888780)),
              onPressed: () => _sendImage(fromCamera: true)),
            GestureDetector(
              onTap: _hasText ? _sendText : null,
              onLongPressStart: !_hasText ? (_) => _startRecording() : null,
              onLongPressEnd: !_hasText ? (_) => _stopRecording() : null,
              child: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.red : AppTheme.primaryGreen,
                  shape: BoxShape.circle),
                child: Icon(
                  _isRecording ? Icons.stop_rounded : _hasText ? Icons.send_rounded : Icons.mic_rounded,
                  color: Colors.white, size: 22))),
          ]),
        ),
      ]),
    );
  }

  Future<void> _confirmClearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Chat?'),
        content: const Text('Semua pesan akan dihapus permanen'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus')),
        ],
      ),
    );
    if (confirm == true) {
      await context.read<ChatService>().deleteChat(widget.chatId);
      if (mounted) context.pop();
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  final String? playingUrl;
  final Function(String) onPlayAudio;
  final VoidCallback onReply;

  const _MessageBubble({
    required this.msg, required this.isMe,
    required this.playingUrl, required this.onPlayAudio,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final type = msg['topic'] ?? 'text';
    final text = msg['text'] ?? '';
    final mediaUrl = msg['media_url'] ?? '';
    final timestamp = msg['timestamp']?.toString() ?? '';
    final status = msg['status'] ?? 'sent';
    final replyTo = msg['reply_to'] as Map<String, dynamic>?;
    final reactions = msg['reactions'] as Map<String, dynamic>?;
    final isDeleted = type == 'deleted';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(left: isMe ? 60 : 4, right: isMe ? 4 : 60, bottom: 2),
            decoration: BoxDecoration(
              color: isDeleted ? Colors.grey[200] : (isMe ? const Color(0xFF0084FF) : Colors.white),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 1))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Reply preview
              if (replyTo != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.white24 : const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(left: BorderSide(
                      color: isMe ? Colors.white : AppTheme.primaryGreen, width: 3))),
                  child: Text(
                    replyTo['text']?.toString() ?? '',
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12,
                      color: isMe ? Colors.white70 : const Color(0xFF888780))),
                ),

              // Content
              if (isDeleted)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.block_rounded, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text('Pesan dihapus',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500], fontStyle: FontStyle.italic)),
                  ]))
              else if (type == 'text' || type == 'sticker')
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Text(
                    text.isEmpty ? '...' : text,
                    style: TextStyle(
                      fontSize: type == 'sticker' ? 36 : 15,
                      color: isMe ? Colors.white : const Color(0xFF111111), height: 1.3)))
              else if (type == 'image' && mediaUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16)),
                  child: GestureDetector(
                    onTap: () => context.push('/media', extra: {'url': mediaUrl, 'type': 'image'}),
                    child: CachedNetworkImage(imageUrl: mediaUrl, width: 200, height: 200, fit: BoxFit.cover)))
              else if (type == 'document' && mediaUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: isMe ? Colors.white24 : const Color(0xFF0084FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.insert_drive_file_rounded,
                        color: isMe ? Colors.white : const Color(0xFF0084FF), size: 26)),
                    const SizedBox(width: 10),
                    Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(text.replaceAll('📄 ', ''),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                          color: isMe ? Colors.white : const Color(0xFF111111)),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text('Ketuk untuk buka',
                        style: TextStyle(fontSize: 11, color: isMe ? Colors.white60 : const Color(0xFF888780))),
                    ])),
                  ]))
              else if (type == 'voice' && mediaUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    GestureDetector(
                      onTap: () => onPlayAudio(mediaUrl),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: isMe ? Colors.white24 : AppTheme.primaryGreen, shape: BoxShape.circle),
                        child: Icon(
                          playingUrl == mediaUrl ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          color: Colors.white, size: 20))),
                    const SizedBox(width: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 100, height: 2,
                        decoration: BoxDecoration(
                          color: isMe ? Colors.white38 : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 4),
                      Text('Voice note',
                        style: TextStyle(fontSize: 11,
                          color: isMe ? Colors.white70 : const Color(0xFF888780))),
                    ]),
                    const SizedBox(width: 8),
                  ])),

              // Timestamp + status
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_formatTime(timestamp),
                    style: TextStyle(fontSize: 10,
                      color: isMe ? Colors.white70 : const Color(0xFF888780))),
                  if (isMe) ...[
                    const SizedBox(width: 3),
                    if (status == 'sending')
                      const Icon(Icons.access_time_rounded, size: 12, color: Colors.white60)
                    else if (status == 'read')
                      const Icon(Icons.done_all_rounded, size: 14, color: Colors.lightBlueAccent)
                    else if (status == 'delivered')
                      const Icon(Icons.done_all_rounded, size: 14, color: Colors.white60)
                    else
                      const Icon(Icons.done_rounded, size: 14, color: Colors.white60),
                  ],
                ])),
            ]),
          ),

          // Reactions
          if (reactions != null && reactions.isNotEmpty)
            Container(
              margin: EdgeInsets.only(left: isMe ? 0 : 4, right: isMe ? 4 : 0, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)]),
              child: Row(mainAxisSize: MainAxisSize.min,
                children: reactions.keys.map((e) => Text(e, style: const TextStyle(fontSize: 14))).toList())),
        ],
      ),
    );
  }

  String _formatTime(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return ''; }
  }
}

class _DateDivider extends StatelessWidget {
  final String timestamp;
  const _DateDivider({required this.timestamp});

  @override
  Widget build(BuildContext context) {
    String label = '';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) label = 'Hari ini';
      else if (dt.year == now.year && dt.month == now.month && dt.day == now.day - 1) label = 'Kemarin';
      else label = DateFormat('d MMMM yyyy', 'id').format(dt);
    } catch (_) { label = ''; }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Center(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]),
        child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF54656F), fontWeight: FontWeight.w500)))));
  }
}

class _AttachItem extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _AttachItem({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      Container(width: 56, height: 56,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 26)),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
    ]));
}

class _MsgOption extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap; final Color? color;
  const _MsgOption({required this.icon, required this.label, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: color ?? const Color(0xFF444444), size: 22),
    title: Text(label, style: TextStyle(color: color ?? const Color(0xFF444444), fontSize: 15)),
    onTap: onTap,
  );
}
