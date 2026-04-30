import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/status_model.dart';
import '../../widgets/avatar_widget.dart';

class StatusViewerScreen extends StatefulWidget {
  final List<StatusModel> statuses;
  final int initialIndex;
  const StatusViewerScreen({super.key, required this.statuses, required this.initialIndex});
  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen> with SingleTickerProviderStateMixin {
  late PageController _pageCtrl;
  late AnimationController _progressCtrl;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _currentIndex);
    _progressCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 5));
    _startProgress();
  }

  void _startProgress() {
    _progressCtrl.reset();
    _progressCtrl.forward();
    _progressCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) _next();
    });
  }

  void _next() {
    if (_currentIndex < widget.statuses.length - 1) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 200), curve: Curves.easeIn);
      setState(() => _currentIndex++);
      _startProgress();
    } else {
      context.pop();
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      _pageCtrl.previousPage(duration: const Duration(milliseconds: 200), curve: Curves.easeIn);
      setState(() => _currentIndex--);
      _startProgress();
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.statuses[_currentIndex];
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (d) {
          if (d.globalPosition.dx < MediaQuery.of(context).size.width / 2) _prev(); else _next();
        },
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.statuses.length,
              itemBuilder: (ctx, i) {
                final s = widget.statuses[i];
                if (s.type == 'image') return Image.network(s.content, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
                return Container(
                  color: Color(int.parse(s.backgroundColor.replaceAll('#', '0xFF'))),
                  child: Center(child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(s.content, textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600,
                            color: Color(int.parse(s.fontColor.replaceAll('#', '0xFF'))))),
                  )),
                );
              },
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8, left: 8, right: 8,
              child: Row(
                children: List.generate(widget.statuses.length, (i) => Expanded(
                  child: Container(
                    height: 3, margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2)),
                    child: i < _currentIndex
                        ? Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)))
                        : i == _currentIndex
                            ? AnimatedBuilder(animation: _progressCtrl, builder: (_, __) => FractionallySizedBox(
                                alignment: Alignment.centerLeft, widthFactor: _progressCtrl.value,
                                child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)))))
                            : const SizedBox.shrink(),
                  ),
                )),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 20, left: 16, right: 16,
              child: Row(
                children: [
                  AvatarWidget(name: status.displayName, photoUrl: status.displayPhoto, size: 36),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(status.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('${DateTime.now().difference(status.createdAt).inMinutes} mnt lalu',
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ])),
                  IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => context.pop()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
