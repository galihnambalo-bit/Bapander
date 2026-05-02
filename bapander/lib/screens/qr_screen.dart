import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../utils/app_theme.dart';
import '../utils/supabase_config.dart';
import '../widgets/avatar_widget.dart';

class QrScreen extends StatefulWidget {
  const QrScreen({super.key});
  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Map<String, dynamic>? _userData;
  bool _isScanning = false;
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadUser();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final auth = context.read<AuthService>();
    final data = await auth.getUserData(auth.currentUid ?? '');
    setState(() => _userData = data);
  }

  Future<void> _onQrDetected(String scannedData) async {
    if (_scanned) return;
    _scanned = true;

    // Format QR: bapander://user/{uid}
    if (!scannedData.startsWith('bapander://user/')) {
      _showError('QR Code tidak valid');
      _scanned = false;
      return;
    }

    final scannedUid = scannedData.replaceFirst('bapander://user/', '');
    final auth = context.read<AuthService>();
    final myUid = auth.currentUid ?? '';

    if (scannedUid == myUid) {
      _showError('Tidak bisa scan QR sendiri!');
      _scanned = false;
      return;
    }

    // Ambil data user yang di-scan
    final scannedUser = await auth.getUserData(scannedUid);
    if (scannedUser == null) {
      _showError('User tidak ditemukan');
      _scanned = false;
      return;
    }

    // Tampilkan dialog konfirmasi
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Tambah Teman?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvatarWidget(
                name: scannedUser['name'] ?? '',
                photoUrl: scannedUser['photo'] ?? '',
                size: 70,
              ),
              const SizedBox(height: 12),
              Text(
                scannedUser['name'] ?? '',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              if ((scannedUser['nickname'] ?? '').isNotEmpty)
                Text(
                  '@${scannedUser['nickname']}',
                  style: const TextStyle(color: AppTheme.primaryBlue, fontSize: 14),
                ),
              if ((scannedUser['bio'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  scannedUser['bio'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF888780), fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _scanned = false);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                // Follow user
                await auth.followUser(myUid, scannedUid);
                // Langsung chat
                final chatSvc = context.read<ChatService>();
                final chatId = await chatSvc.getOrCreateChat(myUid, scannedUid);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${scannedUser['name']} ditambahkan! 🎉'),
                      backgroundColor: AppTheme.primaryBlue,
                    ),
                  );
                  context.pushReplacement('/chat/$chatId', extra: {
                    'name': scannedUser['name'] ?? '',
                    'photo': scannedUser['photo'] ?? '',
                    'uid': scannedUid,
                  });
                }
              },
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Tambah & Chat'),
            ),
          ],
        ),
      );
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final myUid = auth.currentUid ?? '';
    final qrData = 'bapander://user/$myUid';
    final name = _userData?['name'] ?? '';
    final photo = _userData?['photo'] ?? '';
    final nickname = _userData?['nickname'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Teman via QR'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_rounded), text: 'QR Saya'),
            Tab(icon: Icon(Icons.qr_code_scanner_rounded), text: 'Scan QR'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // ── TAB 1: QR SAYA ────────────────────────────────
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 24),
                AvatarWidget(name: name, photoUrl: photo, size: 70),
                const SizedBox(height: 8),
                Text(name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                if (nickname.isNotEmpty)
                  Text('@$nickname',
                    style: const TextStyle(color: AppTheme.primaryBlue, fontSize: 14)),
                const SizedBox(height: 24),

                // QR Code
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.08),
                        blurRadius: 16, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                      ),
                      const SizedBox(height: 12),
                      const Text('Scan QR ini untuk menambah saya sebagai teman',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF888780))),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Tombol salin link
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: qrData));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link disalin! ✅'),
                        backgroundColor: AppTheme.primaryBlue));
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Salin Link Profil'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryBlue,
                    side: const BorderSide(color: AppTheme.primaryBlue)),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),

          // ── TAB 2: SCAN QR ────────────────────────────────
          Column(
            children: [
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Arahkan kamera ke QR Code teman kamu',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF888780))),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: MobileScanner(
                    onDetect: (capture) {
                      final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
                      if (barcode?.rawValue != null) {
                        _onQrDetected(barcode!.rawValue!);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ],
      ),
    );
  }
}
