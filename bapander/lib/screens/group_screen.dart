import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../utils/supabase_config.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/sticker_picker.dart';
import '../models/sticker_model.dart';

class GroupScreen extends StatefulWidget {
  final String groupId;
  const GroupScreen({super.key, required this.groupId});
  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  
  bool _hasText = false;
  bool _showStickers = false;
  bool _isRecording = false;
  bool _isUploading = false;
  String? _playingUrl;
  final List<Map<String, dynamic>> _localMessages = [];

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(() => setState(() => _hasText = _textCtrl.text.isNotEmpty));
  }

  @override
  void dispose() { 
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _audioRecorder.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose(); 
  }

  Future<void> _sendImage({bool fromCamera = false}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 80);
    if (picked == null) return;
    try {
      setState(() => _isUploading = true);
      final auth = context.read<AuthService>();
      final file = File(picked.path);
      final bytes = await file.readAsBytes();
      final ext = picked.path.split('.').last;
      final fileName = 'images/${auth.currentUid}/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await SupabaseConfig.client.storage.from('media').uploadBinary(fileName, bytes);
      final url = SupabaseConfig.client.storage.from('media').getPublicUrl(fileName);
      final userData = await auth.getUserData(auth.currentUid ?? '');
      await SupabaseConfig.client.from('group_messages').insert({
        'group_id': widget.groupId,
        'sender_id': auth.currentUid ?? '',
        'sender_name': userData?['name'] ?? '',
        'text': '📷 Foto',
        'type': 'image',
        'media_url': url,
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim foto: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _sendDocument() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    try {
      setState(() => _isUploading = true);
      final auth = context.read<AuthService>();
      final file = result.files.first;
      final bytes = await File(file.path!).readAsBytes();
      final fileName = 'documents/${auth.currentUid}/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      await SupabaseConfig.client.storage.from('media').uploadBinary(fileName, bytes);
      final url = SupabaseConfig.client.storage.from('media').getPublicUrl(fileName);
      final size = file.size;
      final sizeStr = size < 1024 ? '${size}B'
          : size < 1024*1024 ? '${(size/1024).toStringAsFixed(1)}KB'
          : '${(size/(1024*1024)).toStringAsFixed(1)}MB';
      final userData = await auth.getUserData(auth.currentUid ?? '');
      await SupabaseConfig.client.from('group_messages').insert({
        'group_id': widget.groupId,
        'sender_id': auth.currentUid ?? '',
        'sender_name': userData?['name'] ?? '',
        'text': '📄 ${file.name} ($sizeStr)',
        'type': 'document',
        'media_url': url,
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim dokumen: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _sendSticker(Sticker sticker) async {
    setState(() => _showStickers = false);
    final auth = context.read<AuthService>();
    final userData = await auth.getUserData(auth.currentUid ?? '');
    await SupabaseConfig.client.from('group_messages').insert({
      'group_id': widget.groupId,
      'sender_id': auth.currentUid ?? '',
      'sender_name': userData?['name'] ?? '',
      'text': sticker.emoji,
      'type': 'sticker',
    });
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
          ]),
          const SizedBox(height: 20),
        ]),
      ),
    );
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
    try {
      final path = await _audioRecorder.stop();
      if (mounted) setState(() => _isRecording = false);
      if (path == null) return;
      setState(() => _isUploading = true);
      final auth = context.read<AuthService>();
      final file = File(path);
      final bytes = await file.readAsBytes();
      final fileName = 'voice/${auth.currentUid}/${DateTime.now().millisecondsSinceEpoch}.aac';
      await SupabaseConfig.client.storage.from('media').uploadBinary(fileName, bytes);
      final url = SupabaseConfig.client.storage.from('media').getPublicUrl(fileName);
      final userData = await auth.getUserData(auth.currentUid ?? '');
      await SupabaseConfig.client.from('group_messages').insert({
        'group_id': widget.groupId,
        'sender_id': auth.currentUid ?? '',
        'sender_name': userData?['name'] ?? '',
        'text': '🎤 Pesan suara',
        'type': 'voice',
        'media_url': url,
      });
    } catch (e) {
      if (mounted) setState(() => _isRecording = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim voice note: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _sendMessage(String myUid, String myName, List<String> members) async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    final tempId = 'temp_\${DateTime.now().millisecondsSinceEpoch}';
    setState(() => _localMessages.insert(0, {
      'id': tempId, 'sender_id': myUid, 'sender_name': myName,
      'text': text, 'type': 'text', 'created_at': DateTime.now().toIso8601String(),
    }));
    try {
      await SupabaseConfig.client.from('group_messages').insert({
        'group_id': widget.groupId, 'sender_id': myUid,
        'sender_name': myName, 'text': text, 'type': 'text',
      });
      // Kirim notifikasi ke semua anggota kecuali pengirim
      for (final memberId in members) {
        if (memberId != myUid) {
          try {
            await SupabaseConfig.client.functions.invoke('send-notification', body: {
              'to_user_id': memberId,
              'title': myName,
              'body': text,
            });
          } catch (_) {}
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal kirim pesan: \$e'),
          backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _localMessages.removeWhere((m) => m['id'] == tempId));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final myUid = auth.currentUid ?? '';

    return FutureBuilder<Map<String, dynamic>?>(
      future: SupabaseConfig.client.from('groups').select().eq('id', widget.groupId).maybeSingle(),
      builder: (ctx, groupSnap) {
        final group = groupSnap.data;
        final groupName = group?['name'] ?? 'Grup';
        final members = List<String>.from(group?['members'] ?? []);
        final isAdmin = List<String>.from(group?['admin'] ?? []).contains(myUid);

        return Scaffold(
          backgroundColor: const Color(0xFFF0F2F5),
          appBar: AppBar(
            backgroundColor: AppTheme.primaryBlue,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.pop()),
            titleSpacing: 0,
            title: GestureDetector(
              onTap: () => _showGroupInfo(context, group, members, isAdmin, myUid),
              child: Row(children: [
                CircleAvatar(
                  radius: 19, backgroundColor: Colors.white24,
                  child: Text(groupName.isNotEmpty ? groupName[0].toUpperCase() : 'G',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(groupName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  Text('${members.length} anggota',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
              ]),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
                onPressed: () => _showGroupInfo(context, group, members, isAdmin, myUid)),
            ],
          ),
          body: Column(children: [
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: SupabaseConfig.client.from('group_messages').stream(primaryKey: ['id'])
                    .eq('group_id', widget.groupId)
                    .order('created_at', ascending: true)
                    .map((l) => List<Map<String, dynamic>>.from(l)),
                builder: (ctx, snap) {
                  final messages = snap.data ?? [];
                  final seen = <String>{};
                  final allMsgs = [..._localMessages];
                  for (final m in messages.reversed) {
                    final id = m['id']?.toString() ?? '';
                    if (!seen.contains(id)) { seen.add(id); allMsgs.add(m); }
                  }
                  if (allMsgs.isEmpty) return Center(
                    child: Text('Belum ada pesan di $groupName',
                      style: const TextStyle(color: Color(0xFF888780))));
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    itemCount: allMsgs.length,
                    itemBuilder: (ctx, i) {
                      final msg = allMsgs[i];
                      final isMe = msg['sender_id']?.toString() == myUid;
                      final nextMsg = i > 0 ? allMsgs[i - 1] : null;
                      final showDate = nextMsg == null || !_isSameDay(
                        DateTime.tryParse(msg['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
                        DateTime.tryParse(nextMsg['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now());
                      return Column(children: [
                        if (showDate) _DateDivider(timestamp: msg['created_at']?.toString() ?? ''),
                        _GroupBubble(msg: msg, isMe: isMe),
                      ]);
                    });
                }),
            ),
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
                      color: _showStickers ? AppTheme.primaryBlue : const Color(0xFF888780))),
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
                            hintText: 'Ketik pesan ke grup...',
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
                  onTap: _hasText ? () async {
                    final userData = await context.read<AuthService>().getUserData(context.read<AuthService>().currentUid ?? '');
                    _sendMessage(context.read<AuthService>().currentUid ?? '', userData?['name'] ?? '', (await SupabaseConfig.client.from('groups').select().eq('id', widget.groupId).maybeSingle())['members'] ?? []);
                  } : null,
                  onLongPressStart: !_hasText ? (_) => _startRecording() : null,
                  onLongPressEnd: !_hasText ? (_) => _stopRecording() : null,
                  child: Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: _hasText ? AppTheme.primaryBlue : Colors.grey[300],
                      shape: BoxShape.circle),
                    child: Icon(
                      _hasText ? Icons.send_rounded : (_isRecording ? Icons.stop_rounded : Icons.mic_rounded),
                      color: Colors.white, size: 22))),
              ]),
            ),
            if (_showStickers) StickerPicker(onStickerSelected: _sendSticker),
          ]),
        );
      },
    );
  }

  Future<void> _changeGroupPhoto(String groupId) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    try {
      final file = File(picked.path);
      final bytes = await file.readAsBytes();
      final ext = picked.path.split('.').last;
      final fileName = 'groups/$groupId/avatar.$ext';
      await SupabaseConfig.client.storage
          .from('media')
          .uploadBinary(fileName, bytes,
              fileOptions: FileOptions(upsert: true, contentType: 'image/$ext'));
      final url = SupabaseConfig.client.storage
          .from('media')
          .getPublicUrl(fileName);
      await SupabaseConfig.client
          .from('groups')
          .update({'photo': url}).eq('id', groupId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Foto grup berhasil diubah')));
        setState(() {});
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal upload foto: $e')));
    }
  }

  void _showGroupInfo(BuildContext context, Map<String, dynamic>? group, List<String> members, bool isAdmin, String myUid) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7, maxChildSize: 0.9, minChildSize: 0.4,
        expand: false,
        builder: (ctx, scroll) {
          final groupName = group?['name']?.toString() ?? '';
          final groupPhoto = group?['photo']?.toString() ?? '';
          return Column(children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 8, bottom: 12),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: isAdmin ? () => _changeGroupPhoto(group?['id'] ?? '') : null,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2))],
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: groupPhoto.isNotEmpty
                          ? NetworkImage(groupPhoto) as ImageProvider
                          : null,
                      child: groupPhoto.isEmpty
                          ? Text(groupName.isNotEmpty ? groupName[0].toUpperCase() : 'G',
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue))
                          : null,
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 12),
                    Text('Ketuk untuk ubah foto grup', style: TextStyle(color: AppTheme.primaryBlue, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                  const SizedBox(height: 20),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Text(group?['name'] ?? 'Grup',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${members.length} anggota', style: const TextStyle(color: Color(0xFF888780))),
              ]),
            ),
            const SizedBox(height: 16),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
              const Text('Anggota', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const Spacer(),
              if (isAdmin) TextButton.icon(
                onPressed: () => _addMember(context, members, group?['id'] ?? ''),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Tambah')),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: members.length,
              itemBuilder: (ctx2, i) {
                final uid = members[i];
                return FutureBuilder<Map<String, dynamic>?>(
                  future: context.read<AuthService>().getUserData(uid),
                  builder: (ctx3, snap) {
                    final u = snap.data;
                    return ListTile(
                      leading: AvatarWidget(name: u?['name'] ?? '', photoUrl: u?['photo'] ?? ''),
                      title: Text(u?['name'] ?? 'User'),
                      subtitle: Text(uid == myUid ? 'Kamu' : (u?['nickname'] != null ? '@${u!['nickname']}' : '')),
                      trailing: isAdmin && uid != myUid
                          ? IconButton(
                              icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red),
                              onPressed: () => _removeMember(context, uid, members, group?['id'] ?? ''))
                          : null,
                    );
                  });
              }),
          ),
          if (!isAdmin)
            Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16, left: 16, right: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _leaveGroup(context, myUid, members, group?['id'] ?? ''),
                  icon: const Icon(Icons.exit_to_app_rounded, color: Colors.red),
                  label: const Text('Keluar dari Grup', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red))),
              ),
            ),
        ]);
      },
    ),
  );
  }

  Future<void> _addMember(BuildContext context, List<String> current, String groupId) async {
    final auth = context.read<AuthService>();
    final users = await auth.getAllUsers(auth.currentUid ?? '');
    final available = users.where((u) => !current.contains(u['id']?.toString())).toList();
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tambah Anggota'),
        content: SizedBox(
          width: 300, height: 300,
          child: ListView.builder(
            itemCount: available.length,
            itemBuilder: (ctx, i) {
              final u = available[i];
              return ListTile(
                leading: AvatarWidget(name: u['name'] ?? '', photoUrl: u['photo'] ?? ''),
                title: Text(u['name'] ?? ''),
                onTap: () async {
                  Navigator.pop(context);
                  final newMembers = [...current, u['id'].toString()];
                  await SupabaseConfig.client.from('groups')
                      .update({'members': newMembers}).eq('id', groupId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${u['name']} ditambahkan ✅'),
                      backgroundColor: AppTheme.primaryBlue));
                });
            }),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
      ),
    );
  }

  Future<void> _removeMember(BuildContext context, String uid, List<String> members, String groupId) async {
    final newMembers = members.where((m) => m != uid).toList();
    await SupabaseConfig.client.from('groups').update({'members': newMembers}).eq('id', groupId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Anggota dihapus'), backgroundColor: Colors.orange));
  }

  Future<void> _leaveGroup(BuildContext context, String myUid, List<String> members, String groupId) async {
    final newMembers = members.where((m) => m != myUid).toList();
    await SupabaseConfig.client.from('groups').update({'members': newMembers}).eq('id', groupId);
    if (context.mounted) context.pop();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _GroupBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  const _GroupBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final text = msg['text'] ?? '';
    final senderName = msg['sender_name'] ?? 'User';
    final timestamp = msg['created_at']?.toString() ?? '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(left: isMe ? 60 : 4, right: isMe ? 4 : 60, bottom: 4),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF0084FF) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!isMe)
            Text(senderName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
          Text(text, style: TextStyle(fontSize: 15, color: isMe ? Colors.white : const Color(0xFF111111))),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(_fmt(timestamp),
              style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : const Color(0xFF888780)))),
        ]),
      ),
    );
  }

  String _fmt(String ts) {
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
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      
      String dateText;
      if (dt.year == today.year && dt.month == today.month && dt.day == today.day) {
        dateText = 'Hari ini';
      } else if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
        dateText = 'Kemarin';
      } else {
        dateText = DateFormat('d MMM yyyy', 'id_ID').format(dt);
      }
      
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Expanded(child: Container(height: 1, color: const Color(0xFFE0E0E0))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(dateText, style: const TextStyle(fontSize: 11, color: Color(0xFF888780))),
          ),
          Expanded(child: Container(height: 1, color: const Color(0xFFE0E0E0))),
        ]),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}

// ─── CREATE GROUP SCREEN ──────────────────────────────────
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});
  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameCtrl = TextEditingController();
  final List<Map<String, dynamic>> _selectedMembers = [];
  bool _isLoading = false;

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _createGroup() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi nama grup dulu!')));
      return;
    }
    setState(() => _isLoading = true);
    final auth = context.read<AuthService>();
    final myUid = auth.currentUid ?? '';
    final members = [myUid, ..._selectedMembers.map((m) => m['id'].toString())];

    await SupabaseConfig.client.from('groups').insert({
      'name': _nameCtrl.text.trim(),
      'members': members,
      'admin': [myUid],
      'photo': '',
    });

    setState(() => _isLoading = false);
    if (mounted) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grup berhasil dibuat! 🎉'),
          backgroundColor: AppTheme.primaryBlue));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final myUid = auth.currentUid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Grup'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createGroup,
            child: _isLoading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Buat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              hintText: 'Nama Grup',
              prefixIcon: Icon(Icons.group_rounded),
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(alignment: Alignment.centerLeft,
            child: Text('Pilih Anggota', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
        ),
        if (_selectedMembers.isNotEmpty)
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _selectedMembers.length,
              itemBuilder: (ctx, i) {
                final m = _selectedMembers[i];
                return Stack(children: [
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(children: [
                      AvatarWidget(name: m['name'] ?? '', photoUrl: m['photo'] ?? '', size: 48),
                      Text(m['name']?.toString().split(' ').first ?? '',
                        style: const TextStyle(fontSize: 11)),
                    ]),
                  ),
                  Positioned(right: 10, top: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedMembers.removeAt(i)),
                      child: Container(
                        width: 18, height: 18,
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 12, color: Colors.white)))),
                ]);
              }),
          ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: auth.getAllUsers(myUid),
            builder: (ctx, snap) {
              final users = snap.data ?? [];
              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (ctx, i) {
                  final u = users[i];
                  final uid = u['id']?.toString() ?? '';
                  final selected = _selectedMembers.any((m) => m['id'] == uid);
                  return ListTile(
                    leading: AvatarWidget(name: u['name'] ?? '', photoUrl: u['photo'] ?? ''),
                    title: Text(u['name'] ?? ''),
                    subtitle: u['nickname'] != null ? Text('@${u['nickname']}') : null,
                    trailing: selected
                        ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryBlue)
                        : const Icon(Icons.circle_outlined, color: Color(0xFFCCCCCC)),
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _selectedMembers.removeWhere((m) => m['id'] == uid);
                        } else {
                          _selectedMembers.add(u);
                        }
                      });
                    },
                  );
                });
            }),
        ),
      ]),
    );
  }
}

// ─── ATTACHMENT ITEM ─────────────────────────────────
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
