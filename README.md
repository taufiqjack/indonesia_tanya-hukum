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

## Google Sign-In

The chat is gated: the app opens on
[`SigninView`](lib/core/pages/signin_view.dart/signin_view.dart) and only shows
the assistant once a Google account has signed in. The session is restored
silently on the next launch, so signing in is a one-time step per device.

Sign-in needs OAuth clients of your own — without them every attempt fails with
*"Konfigurasi Google Sign-In belum lengkap"*.

1. Create a project in the
   [Google Cloud console](https://console.cloud.google.com/apis/credentials) (or
   Firebase, which creates the same clients for you).
2. Create an **Android** OAuth client with this app's package name
   (`com.jetorbit.indonesia_law`) and the SHA-1 of the signing key you build
   with. For debug builds:

   ```bash
   keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android
   ```

   If that path does not exist, the Android tooling is keeping the keystore
   next to the SDK instead — check `$ANDROID_SDK_HOME/.android/debug.keystore`
   (on this machine: `F:\Android\Sdk\.android\debug.keystore`). To read the
   fingerprint off the APK you actually built, which is never wrong:

   ```bash
   apksigner verify --print-certs build/app/outputs/flutter-apk/app-debug.apk
   ```

   Release builds are currently signed with the debug key too, so one SHA-1
   covers both until you add a release signing config.

   The Android client carries no id you copy anywhere — registering it *is* the
   step. Skipping it is the usual reason a correct `.env` still cannot sign in:
   Credential Manager finds no usable credential and the app reports *"Tidak
   ada akun Google yang bisa dipakai"*.
3. Create a **Web application** OAuth client. Its id is what the Android and web
   builds send as `serverClientId` — put it in `.env`:

   ```dotenv
   GOOGLE_SERVER_CLIENT_ID=1234567890-abcdef.apps.googleusercontent.com
   ```

4. iOS only: create an **iOS** OAuth client for the bundle id
   `com.jetorbit.indonesiaLaw`. It takes two edits, and the simulator fails
   just as a device does if either is missing:

   ```dotenv
   GOOGLE_IOS_CLIENT_ID=1234567890-ios.apps.googleusercontent.com
   ```

   Then replace the placeholder scheme in `ios/Runner/Info.plist` with the same
   id *reversed* — the domain part first, without `.apps.googleusercontent.com`:

   ```xml
   <string>com.googleusercontent.apps.1234567890-ios</string>
   ```

   The URL scheme is what brings the OAuth callback back into the app, so it is
   required even though the client id is passed from `.env` rather than a
   `GoogleService-Info.plist`. `.env` is read by Dart at runtime; `Info.plist`
   is read by the OS at launch, which is why the value is written twice.

Dropping `android/app/google-services.json` into the project works as well; in
that case `GOOGLE_SERVER_CLIENT_ID` can stay empty, as long as the file contains
a web client entry (`client_type: 3`).

Android needs **minSdk 24** for the Credential Manager flow, which is already
the Flutter default used here.

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
├─ main.dart                              # entry point, loads .env, owns AuthController
└─ core/
   ├─ config/env.dart                     # access to the .env values
   ├─ models/                             # chat message, chat session, app user
   ├─ services/
   │  ├─ gemini_service.dart              # streaming Gemini client + system prompt
   │  ├─ chat_history_store.dart          # saved conversations (SharedPreferences)
   │  └─ auth_service.dart                # Google Sign-In + cached session
   ├─ widgets/                            # answer rendering, backdrop, Google logo
   └─ pages/
      ├─ auth_gate.dart                   # sign-in page vs. chat
      ├─ signin_view.dart/                # sign-in UI + AuthController
      └─ dashboard/                       # chat UI, ChatController, history drawer
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
| `Konfigurasi Google Sign-In belum lengkap` | OAuth clients missing or the SHA-1 does not match — see [Google Sign-In](#google-sign-in). |
| `Masuk dengan Google belum didukung di platform ini` | Web builds need Google's own button widget; use Android or iOS.   |
