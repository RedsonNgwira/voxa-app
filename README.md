# Voxa — Android App 🎙️

**Voice-first social network. Built in Malawi.**

> *"Where your voice actually matters."*

The official Flutter app for [Voxa](https://voxa.gigalixirapp.com) — a social network where every post is a voice clip. No text. No photos. No follower counts. Just voices.

📱 **Download:** [Latest APK](https://github.com/RedsonNgwira/voxa-app/releases/latest)  
🌍 **Web:** [voxa.gigalixirapp.com](https://voxa.gigalixirapp.com)

---

## Screens

| Screen | Description |
|---|---|
| Splash | Brand intro, 1.5s |
| Login / Register | Email + password auth |
| Voice Bio | Record your intro (60s max, mandatory) |
| Feed | For You / Following / Ember tabs |
| Record | Full-screen recording with live waveform |
| Discover | Filter by mood + category |
| Search | Find people and clips |
| Circles | Private groups, max 20 members |
| Notifications | Pulse, whisper, expiry alerts |
| Profile | Voice bio player, clips, follow/unfollow |
| Embers | Subscription upgrade screen |
| Clip Detail | Full clip with replies and whispers |

---

## Tech Stack

| | |
|---|---|
| Framework | Flutter (Dart) |
| State | InheritedWidget (MeProvider) |
| GraphQL | graphql_flutter |
| Audio recording | record |
| Audio playback | just_audio |
| Local storage | Hive |
| Push notifications | firebase_messaging + flutter_local_notifications |
| Real-time | Phoenix WebSocket (custom client) |
| Routing | go_router |
| Fonts | google_fonts (Playfair Display + DM Sans) |

---

## Setup

### Prerequisites
- Flutter 3.41.8+
- Android Studio or VS Code
- Firebase project (for FCM)

### Install

```bash
git clone https://github.com/RedsonNgwira/voxa-app
cd voxa-app
flutter pub get
```

### Firebase Setup
1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add Android app with package `com.redson.voxa_app`
3. Download `google-services.json` → place in `android/app/`

### Run

```bash
flutter run
```

---

## Build Release APK

The CI pipeline builds automatically on every push to `main`.

**Manual build:**
```bash
flutter build apk --release
```

**Signed AAB for Play Store:**
```bash
flutter build appbundle --release
```

Signing config is in `android/key.properties` (not committed — set up locally or via CI secrets).

---

## CI/CD

GitHub Actions builds a signed APK + AAB on every push and publishes a GitHub Release automatically.

Required secrets:
- `KEYSTORE_BASE64` — base64-encoded keystore file
- `KEY_STORE_PASSWORD` — keystore password
- `KEY_PASSWORD` — key password
- `KEY_ALIAS` — key alias

---

## Architecture

```
lib/
├── core/
│   ├── cloudinary_service.dart   # Signed Cloudinary uploads
│   ├── fcm_service.dart          # Push notifications
│   ├── me_provider.dart          # Current user state (InheritedWidget)
│   ├── phoenix_socket.dart       # WebSocket real-time client
│   ├── queries.dart              # All GraphQL queries/mutations
│   ├── services.dart             # AuthService, GraphQLService, FeedCache
│   └── theme.dart                # Design system (colors, fonts)
├── features/
│   ├── auth/                     # Login, Register, Splash
│   ├── circles/                  # Circles list + detail
│   ├── discover/                 # Discover + Search
│   ├── embers/                   # Embers upgrade screen
│   ├── feed/                     # Feed, ClipCard, AudioPlayer
│   ├── notifications/            # Notifications screen
│   ├── onboarding/               # Voice bio setup
│   ├── profile/                  # Profile screen
│   └── record/                   # Record screen
└── main.dart                     # App entry, router, ClipDetailScreen
```

---

## Design System

```dart
// Colors
AppTheme.black    = #0E0B08  // background
AppTheme.surface  = #181310  // cards
AppTheme.accent   = #E8622A  // ember orange (brand)
AppTheme.gold     = #C9A84C  // gold accent
AppTheme.border   = rgba(gold, 8%)

// Fonts
VoxaLogo()        // Playfair Display — logo only
DM Sans           // all body text
```

---

## Key Features

- **Real-time feed** — Phoenix WebSocket shows new posts instantly with "New voices" banner
- **Haptic pulse** — phone vibrates when someone pulses your voice
- **Push notifications** — system tray notifications when app is backgrounded
- **Offline cache** — last feed cached in Hive, shown while loading
- **Circle posting** — record directly from circle detail screen
- **Waveform seek** — tap anywhere on waveform to seek audio

---

## Backend

The backend is a separate Phoenix/Elixir project:  
[github.com/RedsonNgwira/voxa](https://github.com/RedsonNgwira/voxa)

API endpoint: `https://voxa.gigalixirapp.com/api/graphql`

---

## Built By

**Redson Ngwira** — Lilongwe, Malawi 🇲🇼

---

## Copyright

© 2026 Redson Ngwira. All rights reserved.  
Proprietary software. No copying, modification, or distribution without explicit written permission.
