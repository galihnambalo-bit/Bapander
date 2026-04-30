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
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthService>();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi email dan password')));
      return;
    }

    bool success;
    if (_isRegister) {
      final name = _nameCtrl.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Isi nama lengkap')));
        return;
      }
      success = await auth.register(name: name, email: email, password: pass);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daftar berhasil! Silakan login.'),
            backgroundColor: AppTheme.primaryGreen,
          ));
        setState(() => _isRegister = false);
        return;
      }
    } else {
      success = await auth.login(email: email, password: pass);
    }

    if (success && mounted) {
      context.go('/home');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isRegister
            ? 'Gagal daftar. Coba lagi.'
            : 'Email atau password salah.')));
    }
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
              left: 24, right: 24, bottom: 32,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.chat_bubble_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  _isRegister ? 'Buat Akun Baru' : 'Selamat datang di\nBapander',
                  style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w700,
                    color: Colors.white, height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isRegister
                    ? 'Daftar untuk mulai mengobrol'
                    : 'Chat komunitas dengan bahasa daerahmu',
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // Language picker
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: AppLanguage.values.map((lang) {
                      final isActive = loc.languageCode == lang.code;
                      return GestureDetector(
                        onTap: () => loc.setLanguage(lang.code),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isActive ? AppTheme.primaryBg : Colors.white,
                            border: Border.all(
                              color: isActive
                                  ? AppTheme.primaryLight
                                  : const Color(0xFFDDDDD8),
                            ),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text('${lang.flag} ${lang.label}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isActive
                                    ? AppTheme.primaryGreen
                                    : const Color(0xFF888780),
                                fontWeight: isActive
                                    ? FontWeight.w600 : FontWeight.normal,
                              )),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  if (_isRegister) ...[
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Nama Lengkap',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      hintText: 'Password (min. 6 karakter)',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _submit,
                      child: auth.isLoading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(_isRegister ? 'Daftar' : 'Masuk'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () => setState(() => _isRegister = !_isRegister),
                    child: Text(
                      _isRegister
                          ? 'Sudah punya akun? Masuk'
                          : 'Belum punya akun? Daftar',
                      style: const TextStyle(color: AppTheme.primaryGreen),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
