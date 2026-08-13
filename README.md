# Hukum AI (`indonesia_law`)

An Indonesian legal assistant in chat form. User questions are streamed to the
Gemini API, so answers appear word by word instead of after a long pause.

## Requirements

| Tool        | Minimum                                     |
| ----------- | ------------------------------------------- |
| Flutter SDK | **3.44** (stable)                           |
| Dart SDK    | 3.12.2 (ships with Flutter 3.44)            |
| JDK         | 17 (Android builds)                         |
| Xcode       | 15+ (iOS builds only, macOS required)       |

Check your installed version:

```bash
flutter --version
```

If it is below 3.44, upgrade first:

```bash
flutter channel stable
flutter upgrade
```

## Gemini API key

The app reads the key from a `.env` file at the project root. That file is
**git-ignored** and must never be committed.

1. Get an API key at <https://aistudio.google.com/apikey>.
2. Copy the example file:

   ```bash
   cp .env.example .env      # Windows PowerShell: Copy-Item .env.example .env
   ```

3. Fill in the values:

   ```dotenv
   GEMINI_API_KEY=AIza...your_key_here
   GEMINI_MODEL=gemini-3.5-flash
   ```

`.env` is registered as an asset in [pubspec.yaml](pubspec.yaml#L64-L65) and
loaded once in [main.dart](lib/main.dart#L8) through
[`Env`](lib/core/config/env.dart). If the file is missing or the key is empty
the app still starts, but every question is answered with an error bubble
asking you to set the key.

> **Note:** the key is bundled into the app binary, so it can be extracted from
> an APK/IPA. For a public release, put Gemini behind your own backend.

## Run

```bash
flutter pub get
flutter run                     # currently attached device/emulator
```

Target something else when needed:

```bash
flutter devices                 # list available devices
flutter run -d chrome           # web
flutter run -d emulator-5554    # Android emulator
flutter run --release           # release mode on device
```

Changing the key is not picked up by hot reload — `.env` is read at startup, so
do a **hot restart** (`R`) or relaunch the app.

## Build

Android:

```bash
flutter build apk --release              # universal APK
flutter build apk --split-per-abi        # per-ABI APKs, smaller downloads
flutter build appbundle --release        # AAB for the Play Store
```

Output lands in `build/app/outputs/flutter-apk/` and
`build/app/outputs/bundle/release/`.

Android release builds currently use the **debug signing key**
([build.gradle.kts](android/app/build.gradle.kts#L28-L34)). Replace it with your
own signing config before publishing.

iOS (macOS only):

```bash
flutter build ios --release              # requires signing set up in Xcode
flutter build ipa --release
```

Web:

```bash
flutter build web --release              # output: build/web/
```

Make sure `.env` is filled in **before** building — its contents are bundled as
an asset at build time.

## Test & analyze

```bash
flutter analyze
flutter test
```

## Project structure

```
lib/
├─ main.dart                              # entry point, loads .env
└─ core/
   ├─ config/env.dart                     # access to GEMINI_API_KEY & GEMINI_MODEL
   ├─ models/chat_message.dart            # chat message model
   ├─ services/gemini_service.dart        # streaming Gemini client + system prompt
   ├─ widgets/rich_answer_text.dart       # answer rendering (bold, bullets, etc.)
   └─ pages/
      ├─ signin_view.dart/
      └─ dashboard/                       # chat UI + ChatController
```

## Troubleshooting

In-app error messages are in Indonesian, since that is the language the
assistant speaks.

| Message                                | Cause & fix                                                        |
| -------------------------------------- | ------------------------------------------------------------------ |
| `GEMINI_API_KEY belum diatur`          | `.env` missing or key empty — fill it in and restart the app.       |
| `API key Gemini tidak valid` (401/403) | Wrong key, or it is not enabled in Google AI Studio.                |
| `Model "..." tidak tersedia` (404)     | Set `GEMINI_MODEL` in `.env` to a model your key can access.        |
| `Kuota Gemini habis` (429)             | Rate limit or quota reached; retry in a moment.                     |
| `Tidak dapat terhubung ke Gemini`      | Network issue; on web, check it is not blocked by CORS or a proxy.  |
