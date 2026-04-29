# 🟢 BAPANDER
### Secure Community Messenger — Indonesia-first, Local Language Support

![Flutter](https://img.shields.io/badge/Flutter-3.16-blue?logo=flutter)
![Firebase](https://img.shields.io/badge/Firebase-Firestore-orange?logo=firebase)
![Platform](https://img.shields.io/badge/Platform-Android-green?logo=android)

---

## 📱 Fitur

| Fitur | Status |
|-------|--------|
| Login OTP via Firebase Auth | ✅ |
| Chat 1 vs 1 (text, gambar, voice note) | ✅ |
| Status pesan (sent/delivered/read) | ✅ |
| Group / Komunitas | ✅ |
| Voice Call via WebRTC | ✅ |
| Incoming Call screen | ✅ |
| Dukungan 6 bahasa daerah | ✅ |
| Dark mode | ✅ |
| End-to-end encryption (Signal Protocol) | 🔜 |
| Secret Chat / self-destruct | 🔜 |
| Video Call | 🔜 |

---

## 🚀 Setup — Langkah demi Langkah

### 1. Clone & Install Flutter

```bash
git clone https://github.com/USERNAME/bapander.git
cd bapander
flutter pub get
```

> Butuh Flutter 3.16+. Download: https://docs.flutter.dev/get-started/install

---

### 2. Buat Firebase Project

1. Buka https://console.firebase.google.com
2. **Create project** → nama: `bapander`
3. Aktifkan layanan berikut:
   - **Authentication** → Sign-in method → Phone
   - **Firestore Database** → Create database → Start in production mode
   - **Storage** → Get started
   - **Cloud Messaging** (untuk notifikasi)

---

### 3. Daftarkan Android App

1. Firebase Console → **Project Settings** → **Add app** → Android
2. Package name: `com.bapander.app`
3. Download **`google-services.json`**
4. Taruh di: `android/app/google-services.json`

---

### 4. Generate firebase_options.dart

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Generate config
flutterfire configure
```

Ini otomatis membuat `lib/firebase_options.dart` yang benar.

---

### 5. Upload Firestore Rules

```bash
# Install Firebase CLI dulu
npm install -g firebase-tools
firebase login

# Deploy rules
firebase deploy --only firestore:rules,storage
```

---

### 6. Jalankan di Emulator / Device

```bash
flutter run
```

---

## 🔧 Build APK Manual

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# Split APK per arsitektur (lebih kecil)
flutter build apk --split-per-abi

# App Bundle untuk Play Store
flutter build appbundle
```

APK tersedia di: `build/app/outputs/flutter-apk/`

---

## 🤖 Build di GitHub Actions (Otomatis)

### Setup Secrets di GitHub

Pergi ke: **Repository → Settings → Secrets and variables → Actions**

Tambahkan 2 secrets:

**1. GOOGLE_SERVICES_JSON**
```bash
# Di terminal, encode file ke base64:
base64 -i android/app/google-services.json | pbcopy  # Mac
base64 android/app/google-services.json              # Linux
```
Copy output → paste sebagai value secret.

**2. FIREBASE_OPTIONS**
```bash
base64 -i lib/firebase_options.dart | pbcopy  # Mac
base64 lib/firebase_options.dart              # Linux
```

### Trigger Build

```bash
# Push ke branch main → otomatis build
git add .
git commit -m "feat: initial release"
git push origin main
```

### Download APK

1. Pergi ke tab **Actions** di GitHub repo
2. Klik workflow run terbaru
3. Scroll ke bawah → **Artifacts**
4. Download `bapander-debug-apk` atau `bapander-release-apk`

### Release otomatis dengan tag

```bash
git tag v1.0.0
git push origin v1.0.0
# → Otomatis buat GitHub Release dengan APK terlampir
```

---

## 🌍 Menambah Bahasa Daerah

Edit `lib/localization/app_localizations.dart`:

```dart
// Tambah bahasa baru di enum AppLanguage
enum AppLanguage {
  // ... existing ...
  sasak('sasak', 'Bahasa Sasak', '🌴'),
}

// Tambah terjemahan di AppStrings.strings
'chat': {
  'id': 'Pesan',
  'banjar': 'Panderan',
  'sasak': 'Bejango',  // tambah ini
},
```

---

## 🗄️ Struktur Database Firestore

```
firestore/
├── users/{uid}
│   ├── name, phone, photo
│   ├── online, last_seen
│   └── language
│
├── chats/{chatId}
│   ├── type: "private" | "group"
│   ├── members: [uid1, uid2]
│   ├── last_message, last_timestamp
│   └── messages/{msgId}
│       ├── sender, text, type
│       ├── media_url, timestamp
│       └── status: sent|delivered|read
│
├── groups/{groupId}
│   ├── name, photo, description
│   ├── members: [uid1, uid2, ...]
│   └── admin: [uid1]
│
└── calls/{callId}
    ├── caller, receiver
    ├── status: ringing|accepted|rejected|ended
    ├── offer, answer (WebRTC SDP)
    ├── callerCandidates/{id}
    └── receiverCandidates/{id}
```

---

## 📦 Tech Stack

| Layer | Teknologi |
|-------|-----------|
| Frontend | Flutter 3.16 |
| Backend | Firebase (Auth, Firestore, Storage, FCM) |
| Realtime | Firestore listeners |
| Voice Call | WebRTC (flutter_webrtc) |
| STUN Server | stun:stun.l.google.com:19302 |
| State | Provider |
| Navigation | go_router |

---

## 📁 Struktur Project

```
lib/
├── main.dart
├── firebase_options.dart
├── screens/
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── otp_screen.dart
│   ├── home_screen.dart
│   ├── chat_list_tab.dart
│   ├── chat_room_screen.dart
│   ├── community_tab.dart
│   ├── calls_tab.dart
│   ├── profile_tab.dart
│   ├── settings_screen.dart
│   └── other_screens.dart     (call, group, create group, dll)
├── services/
│   ├── auth_service.dart
│   ├── chat_service.dart
│   └── call_service.dart
├── models/
│   └── models.dart
├── widgets/
│   ├── message_bubble.dart
│   └── avatar_widget.dart
├── localization/
│   └── app_localizations.dart
└── utils/
    ├── app_theme.dart
    └── app_router.dart
```

---

## ⚠️ Catatan Penting

- **Jangan commit** `google-services.json` dan `firebase_options.dart` ke repo publik
- Keduanya sudah ada di `.gitignore`
- Gunakan GitHub Secrets untuk CI/CD
- Free tier Firebase sudah cukup untuk testing

---

## 🏆 Roadmap

- [ ] Phase 1: Login + Chat + Bahasa Indonesia & Banjar ← **sekarang**
- [ ] Phase 2: Group Chat + Voice Note
- [ ] Phase 3: Voice Call (WebRTC)
- [ ] Phase 4: End-to-End Encryption (Signal Protocol)
- [ ] Phase 5: Video Call

---

**Made with ❤️ untuk komunitas lokal Indonesia**
