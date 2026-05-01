import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../localization/app_localizations.dart';
import '../utils/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isRegister = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose(); _passCtrl.dispose(); _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthService>();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) { _showSnack('Isi email dan password'); return; }
    if (pass.length < 6) { _showSnack('Password minimal 6 karakter'); return; }

    bool success;
    if (_isRegister) {
      final name = _nameCtrl.text.trim();
      if (name.isEmpty) { _showSnack('Isi nama lengkap'); return; }
      success = await auth.register(name: name, email: email, password: pass);
      if (success && mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('✅ Daftar Berhasil!'),
            content: const Text('Akun berhasil dibuat. Silakan login sekarang.'),
            actions: [ElevatedButton(
              onPressed: () { Navigator.pop(context); setState(() => _isRegister = false); },
              child: const Text('Login Sekarang'),
            )],
          ),
        );
        return;
      }
    } else {
      success = await auth.login(email: email, password: pass);
    }

    if (success && mounted) {
      context.go('/home');
    } else if (mounted) {
      final err = auth.errorMessage;
      if (err == 'login_not_confirmed') {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Email Belum Dikonfirmasi'),
            content: const Text('Cek inbox/spam email kamu dan klik link konfirmasi.\n\nAtau gunakan Login dengan Google untuk masuk tanpa konfirmasi.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await auth.resetPassword(email);
                  _showSnack('Link konfirmasi dikirim ke $email');
                },
                child: const Text('Kirim Ulang'),
              ),
            ],
          ),
        );
      } else {
        _showSnack(err.isNotEmpty ? err : (_isRegister ? 'Gagal daftar.' : 'Email atau password salah.'));
      }
    }
  }

  Future<void> _googleSignIn() async {
    final auth = context.read<AuthService>();
    final success = await auth.signInWithGoogle();
    if (success && mounted) {
      context.go('/home');
    } else if (mounted && auth.errorMessage.isNotEmpty) {
      _showSnack(auth.errorMessage);
    }
  }

  Future<void> _forgotPassword() async {
    final ctrl = TextEditingController(text: _emailCtrl.text.trim());
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Masukkan email untuk menerima link reset password.',
            style: TextStyle(fontSize: 13, color: Color(0xFF888780))),
          const SizedBox(height: 12),
          TextField(controller: ctrl, keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final email = ctrl.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(ctx);
              final ok = await context.read<AuthService>().resetPassword(email);
              if (mounted) _showSnack(ok ? '✅ Link dikirim ke $email. Cek inbox/spam!' : '❌ Gagal kirim email.');
            },
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final loc = context.watch<LocalizationProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              left: 24, right: 24, bottom: 32),
            decoration: const BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                _isRegister ? 'Buat Akun Baru' : 'Selamat datang di\nBapander',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white, height: 1.3),
              ),
              const SizedBox(height: 6),
              Text(
                _isRegister ? 'Daftar untuk mulai mengobrol' : 'Chat komunitas dengan bahasa daerahmu',
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ]),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const SizedBox(height: 8),

                // Language picker
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: AppLanguage.values.map((lang) {
                    final isActive = loc.languageCode == lang.code;
                    return GestureDetector(
                      onTap: () => loc.setLanguage(lang.code),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isActive ? AppTheme.primaryBg : Colors.white,
                          border: Border.all(color: isActive ? AppTheme.primaryLight : const Color(0xFFDDDDD8)),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text('${lang.flag} ${lang.label}',
                          style: TextStyle(fontSize: 12,
                            color: isActive ? AppTheme.primaryGreen : const Color(0xFF888780),
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                if (_isRegister) ...[
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(hintText: 'Nama Lengkap', prefixIcon: Icon(Icons.person_outline)),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                ],

                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    hintText: 'Password (min. 6 karakter)',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),

                if (!_isRegister)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      child: const Text('Lupa Password?',
                        style: TextStyle(color: AppTheme.primaryGreen, fontSize: 12)),
                    ),
                  ),

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: auth.isLoading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_isRegister ? 'Daftar' : 'Masuk',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 16),

                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('atau', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 16),

                // Google Sign In Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: auth.isLoading ? null : _googleSignIn,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFDDDDD8)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF4285F4), width: 2),
                        ),
                        child: const Center(
                          child: Text('G',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF4285F4)))),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isRegister ? 'Daftar dengan Google' : 'Login dengan Google',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF444444))),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: () => setState(() => _isRegister = !_isRegister),
                  child: Text(
                    _isRegister ? 'Sudah punya akun? Masuk' : 'Belum punya akun? Daftar',
                    style: const TextStyle(color: AppTheme.primaryGreen)),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
