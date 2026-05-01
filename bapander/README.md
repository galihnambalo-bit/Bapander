# 🟢 BAPANDER
### Secure Community Messenger — Indonesia-first, Local Language Support

![Flutter](https://img.shields.io/badge/Flutter-3.16-blue?logo=flutter)
![Firebase](https://img.shields.io/badge/Firebase-Firestore-orange?logo=firebase)

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
| Marketplace & Auction | ✅ |
| Status & Stories | ✅ |
| End-to-end encryption (Signal Protocol) | 🔜 |
| Secret Chat / self-destruct | 🔜 |
| Video Call | 🔜 |

---

## 🚀 Setup — Langkah demi Langkah

### 1. Clone & Install Flutter

```bash
git clone https://github.com/galihnambalo-bit/Bapander.git
cd Bapander/bapander
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

### 3. Setup Supabase

1. Buka https://supabase.com
2. **Create project** → nama: `bapander`
3. Copy URL dan anon key ke `lib/utils/supabase_config.dart`
4. Jalankan SQL schema dari `supabase_schema.sql`

---

### 4. Setup OneSignal (Push Notifications)

1. Buka https://onesignal.com
2. **Create app** → nama: `Bapander`
3. Copy App ID ke `lib/services/notification_service.dart`
4. Setup Android dengan `google-services.json`

---

## 🔧 GitHub Actions Setup

### Secrets yang Diperlukan:

Buka **Settings → Secrets and variables → Actions** di GitHub repo:

#### Untuk Build APK/AAB:
```
GOOGLE_SERVICES_JSON          # Base64 encoded google-services.json
KEYSTORE_FILE                 # Base64 encoded keystore file (.jks)
KEYSTORE_PASSWORD             # Password keystore
KEY_PASSWORD                  # Password key
KEY_ALIAS                     # Alias key
```

#### Untuk Deploy Play Store:
```
PLAY_STORE_SERVICE_ACCOUNT_JSON  # Service account JSON untuk Play Store
```

#### Untuk Deploy Supabase:
```
SUPABASE_ACCESS_TOKEN         # Access token dari Supabase
ONESIGNAL_API_KEY             # REST API Key dari OneSignal
```

### Cara Setup Secrets:

```bash
# Encode files ke base64
base64 -w 0 android/app/google-services.json > google_services.txt
base64 -w 0 android/app/bapander-release.jks > keystore.txt

# Copy isi file ke GitHub secrets
```

---

## 🚀 Deploy

### Otomatis via GitHub Actions:

1. **Push ke main branch** → Auto build APK/AAB
2. **Create tag v1.0.0** → Auto deploy ke Play Store
3. **Update supabase/functions/** → Auto deploy functions

### Manual Deploy:

```bash
# Build APK
flutter build apk --release

# Build AAB untuk Play Store
flutter build appbundle --release

# Deploy Supabase functions
supabase functions deploy send-notification
```

---

## 📋 Checklist Pre-Deploy

- [ ] Firebase project configured
- [ ] Supabase project configured
- [ ] OneSignal app configured
- [ ] GitHub secrets added
- [ ] Keystore generated
- [ ] google-services.json added
- [ ] Test build locally
- [ ] Test notifications
- [ ] Test calls & chat

---

## 🐛 Troubleshooting

### Build Gagal:
```bash
flutter doctor
flutter clean && flutter pub get
```

### OneSignal Error:
- Check API key di secrets
- Verify package name: `com.bapander.app`

### Supabase Error:
- Check access token
- Verify project ref: `hpbozzlqgkjvjouynihg`

---

## 📞 Support

Untuk pertanyaan atau issues, buat GitHub issue atau hubungi developer.

**Happy coding! 🚀**

## Getting started

### Install the CLI

Available via [NPM](https://www.npmjs.com) as dev dependency. To install:

```bash
npm i supabase --save-dev
```

When installing with yarn 4, you need to disable experimental fetch with the following nodejs config.

```
NODE_OPTIONS=--no-experimental-fetch yarn add supabase
```

> **Note**
For Bun versions below v1.0.17, you must add `supabase` as a [trusted dependency](https://bun.sh/guides/install/trusted) before running `bun add -D supabase`.

<details>
  <summary><b>macOS</b></summary>

  Available via [Homebrew](https://brew.sh). To install:

  ```sh
  brew install supabase/tap/supabase
  ```

  To install the beta release channel:
  
  ```sh
  brew install supabase/tap/supabase-beta
  brew link --overwrite supabase-beta
  ```
  
  To upgrade:

  ```sh
  brew upgrade supabase
  ```
</details>

<details>
  <summary><b>Windows</b></summary>

  Available via [Scoop](https://scoop.sh). To install:

  ```powershell
  scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
  scoop install supabase
  ```

  To upgrade:

  ```powershell
  scoop update supabase
  ```
</details>

<details>
  <summary><b>Linux</b></summary>

  Available via [Homebrew](https://brew.sh) and Linux packages.

  #### via Homebrew

  To install:

  ```sh
  brew install supabase/tap/supabase
  ```

  To upgrade:

  ```sh
  brew upgrade supabase
  ```

  #### via Linux packages

  Linux packages are provided in [Releases](https://github.com/supabase/cli/releases). To install, download the `.apk`/`.deb`/`.rpm`/`.pkg.tar.zst` file depending on your package manager and run the respective commands.

  ```sh
  sudo apk add --allow-untrusted <...>.apk
  ```

  ```sh
  sudo dpkg -i <...>.deb
  ```

  ```sh
  sudo rpm -i <...>.rpm
  ```

  ```sh
  sudo pacman -U <...>.pkg.tar.zst
  ```
</details>

<details>
  <summary><b>Other Platforms</b></summary>

  You can also install the CLI via [go modules](https://go.dev/ref/mod#go-install) without the help of package managers.

  ```sh
  go install github.com/supabase/cli@latest
  ```

  Add a symlink to the binary in `$PATH` for easier access:

  ```sh
  ln -s "$(go env GOPATH)/bin/cli" /usr/bin/supabase
  ```

  This works on other non-standard Linux distros.
</details>

<details>
  <summary><b>Community Maintained Packages</b></summary>

  Available via [pkgx](https://pkgx.sh/). Package script [here](https://github.com/pkgxdev/pantry/blob/main/projects/supabase.com/cli/package.yml).
  To install in your working directory:

  ```bash
  pkgx install supabase
  ```

  Available via [Nixpkgs](https://nixos.org/). Package script [here](https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/tools/supabase-cli/default.nix).
</details>

### Run the CLI

```bash
supabase bootstrap
```

Or using npx:

```bash
npx supabase bootstrap
```

The bootstrap command will guide you through the process of setting up a Supabase project using one of the [starter](https://github.com/supabase-community/supabase-samples/blob/main/samples.json) templates.

## Docs

Command & config reference can be found [here](https://supabase.com/docs/reference/cli/about).

## Breaking changes

We follow semantic versioning for changes that directly impact CLI commands, flags, and configurations.

However, due to dependencies on other service images, we cannot guarantee that schema migrations, seed.sql, and generated types will always work for the same CLI major version. If you need such guarantees, we encourage you to pin a specific version of CLI in package.json.

## Developing

To run from source:

```sh
# Go >= 1.22
go run . help
```
