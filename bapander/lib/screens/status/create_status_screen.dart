import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/status_service.dart';
import '../../utils/app_theme.dart';

class CreateStatusScreen extends StatefulWidget {
  const CreateStatusScreen({super.key});
  @override
  State<CreateStatusScreen> createState() => _CreateStatusScreenState();
}

class _CreateStatusScreenState extends State<CreateStatusScreen> {
  final _textCtrl = TextEditingController();
  String _bgColor = '#0F6E56';
  String _fontColor = '#FFFFFF';
  File? _imageFile;
  bool _isLoading = false;
  bool _isAnonymous = false;
  String _mode = 'text';

  final _bgColors = [
    ['#0F6E56', '#FFFFFF'], ['#1A1A2E', '#FFFFFF'], ['#E24B4A', '#FFFFFF'],
    ['#BA7517', '#FFFFFF'], ['#4A90E2', '#FFFFFF'], ['#9B59B6', '#FFFFFF'],
    ['#FFFFFF', '#000000'], ['#FFF3CD', '#633806'],
  ];

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() { _imageFile = File(picked.path); _mode = 'image'; });
  }

  Future<void> _post() async {
    if (_mode == 'text' && _textCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tulis sesuatu dulu!')));
      return;
    }
    setState(() => _isLoading = true);
    final auth = context.read<AuthService>();
    final svc = context.read<StatusService>();
    final userData = await auth.getUserData(auth.currentUid ?? '');
    try {
      if (_mode == 'image' && _imageFile != null) {
        await svc.createImageStatus(userId: auth.currentUid ?? '', userName: userData?['name'] ?? '',
          userPhoto: userData?['photo'] ?? '', imageFile: _imageFile!,
          caption: _textCtrl.text.trim().isEmpty ? null : _textCtrl.text.trim(), isAnonymous: _isAnonymous);
      } else {
        await svc.createTextStatus(userId: auth.currentUid ?? '', userName: userData?['name'] ?? '',
          userPhoto: userData?['photo'] ?? '', text: _textCtrl.text.trim(),
          backgroundColor: _bgColor, fontColor: _fontColor, isAnonymous: _isAnonymous);
      }
      if (mounted) { context.pop(); ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status berhasil! (24 jam)'), backgroundColor: AppTheme.primaryGreen)); }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _mode == 'text' ? Color(int.parse(_bgColor.replaceAll('#', '0xFF'))) : Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => context.pop()),
        actions: [
          IconButton(icon: const Icon(Icons.image_rounded, color: Colors.white), onPressed: _pickImage),
          TextButton(onPressed: _isLoading ? null : _post,
            child: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('POSTING', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _mode == 'image' && _imageFile != null
                ? Image.file(_imageFile!, width: double.infinity, height: double.infinity, fit: BoxFit.cover)
                : Center(child: Padding(padding: const EdgeInsets.all(32),
                    child: TextField(controller: _textCtrl, maxLines: null, textAlign: TextAlign.center,
                      autofocus: true,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600,
                          color: Color(int.parse(_fontColor.replaceAll('#', '0xFF')))),
                      decoration: InputDecoration(
                      hintText: 'Tulis sesuatu...',
                      hintStyle: TextStyle(
                        color: Color(int.parse(_fontColor.replaceAll('#', '0xFF'))).withOpacity(0.5),
                        fontSize: 24,
                      ),
                      border: InputBorder.none,
                      filled: false,
                    )))),
          ),
          Container(
            color: Colors.black54, padding: const EdgeInsets.all(12),
            child: Column(children: [
              if (_mode == 'text') SizedBox(height: 40,
                child: ListView(scrollDirection: Axis.horizontal,
                  children: _bgColors.map((c) => GestureDetector(
                    onTap: () => setState(() { _bgColor = c[0]; _fontColor = c[1]; }),
                    child: Container(width: 36, height: 36, margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(color: Color(int.parse(c[0].replaceAll('#', '0xFF'))),
                        shape: BoxShape.circle,
                        border: Border.all(color: _bgColor == c[0] ? Colors.white : Colors.white30, width: _bgColor == c[0] ? 3 : 1))),
                  )).toList())),
              const SizedBox(height: 8),
              Row(children: [
                Switch(value: _isAnonymous, onChanged: (v) => setState(() => _isAnonymous = v), activeColor: AppTheme.primaryGreen),
                const Text('Posting anonim', style: TextStyle(color: Colors.white, fontSize: 13)),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}
