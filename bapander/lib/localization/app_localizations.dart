import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── SUPPORTED LANGUAGES ─────────────────────────────────
enum AppLanguage {
  id('id', 'Bahasa Indonesia', '🇮🇩'),
  banjar('banjar', 'Bahasa Banjar', '🌿'),
  jv('jv', 'Basa Jawa', '☕'),
  bugis('bugis', 'Basa Bugis', '⛵'),
  batak('batak', 'Hata Batak', '🏔️'),
  bali('bali', 'Basa Bali', '🌺');

  const AppLanguage(this.code, this.label, this.flag);
  final String code;
  final String label;
  final String flag;
}

// ─── LOCALIZATION STRINGS ────────────────────────────────
class AppStrings {
  static const Map<String, Map<String, String>> strings = {
    'app_name': {
      'id': 'Bapander',
      'banjar': 'Bapander',
      'jv': 'Bapander',
      'bugis': 'Bapander',
    },
    'chat': {
      'id': 'Pesan',
      'banjar': 'Panderan',
      'jv': 'Obrolan',
      'bugis': 'Ugi',
    },
    'community': {
      'id': 'Komunitas',
      'banjar': 'Komunitas',
      'jv': 'Paguyuban',
      'bugis': 'Komunitas',
    },
    'calls': {
      'id': 'Panggilan',
      'banjar': 'Talapon',
      'jv': 'Telpon',
      'bugis': 'Kalippi',
    },
    'profile': {
      'id': 'Profil',
      'banjar': 'Profil',
      'jv': 'Profil',
      'bugis': 'Profil',
    },
    'send': {
      'id': 'Kirim',
      'banjar': 'Kirim',
      'jv': 'Kirim',
      'bugis': 'Kirim',
    },
    'online': {
      'id': 'Online',
      'banjar': 'Online',
      'jv': 'Online',
      'bugis': 'Online',
    },
    'typing': {
      'id': 'Sedang mengetik...',
      'banjar': 'Lagi nulis...',
      'jv': 'Lagi nulis...',
      'bugis': 'Sedang mengetik...',
    },
    'no_chats': {
      'id': 'Belum ada pesan',
      'banjar': 'Kawa ada panderan',
      'jv': 'Durung ana obrolan',
      'bugis': 'Tania na ugi',
    },
    'new_message': {
      'id': 'Pesan Baru',
      'banjar': 'Panderan Baru',
      'jv': 'Pesen Anyar',
      'bugis': 'Ugi Barú',
    },
    'create_group': {
      'id': 'Buat Grup',
      'banjar': 'Bikin Grup',
      'jv': 'Gawe Grup',
      'bugis': 'Sippo Grup',
    },
    'voice_note': {
      'id': 'Pesan Suara',
      'banjar': 'Rekaman Suara',
      'jv': 'Rekaman Swara',
      'bugis': 'Pesan Suara',
    },
    'tap_to_listen': {
      'id': 'Ketuk untuk dengarkan',
      'banjar': 'Ketuk untuk dangar',
      'jv': 'Pencet kanggo ngrungokke',
      'bugis': 'Ketuk untuk dengarkan',
    },
    'settings': {
      'id': 'Pengaturan',
      'banjar': 'Setelan',
      'jv': 'Setelan',
      'bugis': 'Setelan',
    },
    'language': {
      'id': 'Bahasa',
      'banjar': 'Bahasa',
      'jv': 'Basa',
      'bugis': 'Ogi',
    },
    'login': {
      'id': 'Masuk',
      'banjar': 'Masuk',
      'jv': 'Mlebu',
      'bugis': 'Masuk',
    },
    'phone_number': {
      'id': 'Nomor HP',
      'banjar': 'Nomor HP',
      'jv': 'Nomer HP',
      'bugis': 'Nomor HP',
    },
    'verify_otp': {
      'id': 'Verifikasi OTP',
      'banjar': 'Verifikasi OTP',
      'jv': 'Verifikasi OTP',
      'bugis': 'Verifikasi OTP',
    },
    'calling': {
      'id': 'Memanggil...',
      'banjar': 'Manalapon...',
      'jv': 'Nelpon...',
      'bugis': 'Memanggil...',
    },
    'incoming_call': {
      'id': 'Panggilan Masuk',
      'banjar': 'Ada Talapon',
      'jv': 'Ana Telpon',
      'bugis': 'Panggilan Masuk',
    },
    'accept': {
      'id': 'Terima',
      'banjar': 'Tarima',
      'jv': 'Tampa',
      'bugis': 'Terima',
    },
    'reject': {
      'id': 'Tolak',
      'banjar': 'Tulak',
      'jv': 'Tolak',
      'bugis': 'Tolak',
    },
  };

  static String get(String key, String langCode) {
    return strings[key]?[langCode] ?? strings[key]?['id'] ?? key;
  }
}

// ─── LOCALIZATION PROVIDER ───────────────────────────────
class LocalizationProvider extends ChangeNotifier {
  String _languageCode = 'id';
  String get languageCode => _languageCode;

  Locale get locale => Locale(_languageCode);

  LocalizationProvider() {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    _languageCode = prefs.getString('language') ?? 'id';
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    _languageCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', code);
    notifyListeners();
  }

  String t(String key) => AppStrings.get(key, _languageCode);
}

// ─── FLUTTER LOCALIZATION DELEGATE ───────────────────────
class AppLocalizations {
  static const List<Locale> supportedLocales = [
    Locale('id'),
    Locale('jv'),
    Locale('ban'), // Banjar
  ];

  static const List<LocalizationsDelegate> localizationsDelegates = [
    DefaultMaterialLocalizations.delegate,
    DefaultWidgetsLocalizations.delegate,
  ];
}
