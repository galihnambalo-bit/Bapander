import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/models.dart';
import '../utils/app_theme.dart';

class MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final VoidCallback? onMediaTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onMediaTap,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  double _progress = 0;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;
    final isMe = widget.isMe;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              decoration: BoxDecoration(
                color: isMe
                    ? AppTheme.primaryBlue
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildContent(msg, isMe),
                  Padding(
                    padding:
                        const EdgeInsets.only(right: 8, bottom: 5, left: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(msg.timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? Colors.white60
                                : const Color(0xFFAAAAAA),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          _statusIcon(msg.status),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildContent(MessageModel msg, bool isMe) {
    switch (msg.type) {
      case MessageType.image:
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          child: GestureDetector(
            onTap: widget.onMediaTap,
            child: CachedNetworkImage(
              imageUrl: msg.mediaUrl,
              width: 220,
              height: 180,
              fit: BoxFit.cover,
              placeholder: (ctx, url) => Container(
                width: 220,
                height: 180,
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
        );

      case MessageType.voice:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _togglePlay(msg.mediaUrl),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isMe ? Colors.white24 : AppTheme.primaryBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: isMe ? Colors.white : AppTheme.primaryBlue,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor:
                          isMe ? Colors.white24 : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(
                        isMe ? Colors.white : AppTheme.primaryBlue,
                      ),
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${msg.duration ?? 0}s',
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe ? Colors.white70 : const Color(0xFF888780),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      default:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            msg.text,
            style: TextStyle(
              fontSize: 15,
              color: isMe ? Colors.white : Theme.of(context).colorScheme.onSurface,
              height: 1.4,
            ),
          ),
        );
    }
  }

  Future<void> _togglePlay(String url) async {
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      await _player.play(UrlSource(url));
      setState(() => _isPlaying = true);

      _player.onPositionChanged.listen((pos) {});
      _player.onPlayerComplete.listen((_) {
        setState(() {
          _isPlaying = false;
          _progress = 0;
        });
      });
    }
  }

  Widget _statusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
              strokeWidth: 1.5, color: Colors.white60),
        );
      case MessageStatus.sent:
        return const Icon(Icons.check_rounded, size: 14, color: Colors.white60);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all_rounded,
            size: 14, color: Colors.white60);
      case MessageStatus.read:
        return const Icon(Icons.done_all_rounded,
            size: 14, color: Colors.lightBlueAccent);
    }
  }

  String _formatTime(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
