import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../utils/supabase_config.dart';

class NicknameScreen extends StatefulWidget {
  const NicknameScreen({super.key});
  @override
  State<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends State<NicknameScreen> {
  final _ctrl = TextEditingController();
  bool _isChecking = false;
  bool _isAvailable = false;
  bool _isTaken = false;
  bool _isSaving = false;
  String _currentNickname = '';

  @override
  void initState() {
    super.initState();
    _loadCurrent();
    _ctrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrent() async {
    final auth = context.read<AuthService>();
    final data = await auth.getUserData(auth.currentUid ?? '');
    final nickname = data?['nickname'] ?? '';
    setState(() => _currentNickname = nickname);
    _ctrl.text = nickname;
  }

  void _onChanged() {
    final val = _ctrl.text.trim().toLowerCase();
    if (val.isEmpty) {
      setState(() { _isAvailable = false; _isTaken = false; });
      return;
    }
    if (val == _currentNickname) {
      setState(() { _isAvailable = true; _isTaken = false; });
      return;
    }
    // Validasi format
    final regex = RegExp(r'^[a-z0-9_.]{3,20}$');
    if (!regex.hasMatch(val)) {
      setState(() { _isAvailable = false; _isTaken = false; });
      return;
    }
    _checkAvailability(val);
  }

  Future<void> _checkAvailability(String nickname) async {
    setState(() { _isChecking = true; _isAvailable = false; _isTaken = false; });
    
    // Debounce 500ms
    await Future.delayed(const Duration(milliseconds: 500));
    if (_ctrl.text.trim().toLowerCase() != nickname) return;

    try {
      final auth = context.read<AuthService>();
      final data = await SupabaseConfig.client
          .from('users')
          .select('id')
          .eq('nickname', nickname)
          .neq('id', auth.currentUid ?? '')
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isChecking = false;
          _isTaken = data != null;
          _isAvailable = data == null;
        });
      }
    } catch (e) {
      setState(() => _isChecking = false);
    }
  }

  Future<void> _save() async {
    final nickname = _ctrl.text.trim().toLowerCase();
    if (!_isAvailable) return;

    setState(() => _isSaving = true);
    final auth = context.read<AuthService>();

    await SupabaseConfig.client.from('users')
        .update({'nickname': nickname}).eq('id', auth.currentUid ?? '');

    setState(() { _isSaving = false; _currentNickname = nickname; });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nickname berhasil disimpan! ✅'),
        backgroundColor: AppTheme.primaryBlue,
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final val = _ctrl.text.trim();
    final regex = RegExp(r'^[a-z0-9_.]{3,20}$');
    final isValidFormat = val.isEmpty || regex.hasMatch(val.toLowerCase());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Nickname'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isAvailable && !_isSaving ? _save : null,
            child: _isSaving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Simpan', style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nickname', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              'Nickname unik untuk identifikasi akun kamu. Bisa dipakai orang lain untuk menemukanmu.',
              style: TextStyle(fontSize: 13, color: Color(0xFF888780)),
            ),
            const SizedBox(height: 16),

            // Input nickname
            TextField(
              controller: _ctrl,
              maxLength: 20,
              decoration: InputDecoration(
                hintText: 'contoh: budi_123',
                prefixText: '@',
                prefixStyle: const TextStyle(
                  color: AppTheme.primaryBlue, fontWeight: FontWeight.w600),
                suffixIcon: _isChecking
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2,
                            color: AppTheme.primaryBlue)))
                    : _isAvailable
                        ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryBlue)
                        : _isTaken
                            ? const Icon(Icons.cancel_rounded, color: Colors.red)
                            : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _isAvailable ? AppTheme.primaryBlue
                        : _isTaken ? Colors.red : AppTheme.primaryBlue,
                    width: 2,
                  ),
                ),
              ),
            ),

            // Status pesan
            if (_isTaken)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(children: [
                  Icon(Icons.cancel_rounded, color: Colors.red, size: 16),
                  SizedBox(width: 6),
                  Text('Nickname sudah dipakai orang lain',
                    style: TextStyle(color: Colors.red, fontSize: 13)),
                ]),
              )
            else if (_isAvailable)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(children: [
                  Icon(Icons.check_circle_rounded, color: AppTheme.primaryBlue, size: 16),
                  SizedBox(width: 6),
                  Text('Nickname tersedia!',
                    style: TextStyle(color: AppTheme.primaryBlue, fontSize: 13)),
                ]),
              )
            else if (!isValidFormat && val.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, color: Colors.orange, size: 16),
                  SizedBox(width: 6),
                  Flexible(child: Text(
                    'Hanya huruf kecil, angka, titik, underscore. Min 3 karakter.',
                    style: TextStyle(color: Colors.orange, fontSize: 13))),
                ]),
              ),

            const SizedBox(height: 24),

            // Aturan nickname
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aturan Nickname:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  SizedBox(height: 8),
                  _RuleItem(text: 'Hanya huruf kecil (a-z), angka (0-9), titik (.), underscore (_)'),
                  _RuleItem(text: 'Minimal 3 karakter, maksimal 20 karakter'),
                  _RuleItem(text: 'Harus unik - tidak boleh sama dengan pengguna lain'),
                  _RuleItem(text: 'Bisa diubah kapan saja'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  final String text;
  const _RuleItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppTheme.primaryBlue,
            fontWeight: FontWeight.w700)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13,
            color: Color(0xFF444444)))),
        ],
      ),
    );
  }
}
