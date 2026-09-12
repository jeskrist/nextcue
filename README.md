# NextCue 🏋️‍♂️

A simple Flutter app that plays one workout video, over and over. Pick the video
once — it's remembered for every future launch — then control it with big,
sweaty-hands-friendly buttons.

## What's included in this package

```
nextcue/
├── pubspec.yaml
├── assets/icon/icon.png             (legacy launcher icon, full-bleed square)
├── assets/icon/icon_foreground.png  (transparent Android adaptive-icon layer)
└── lib/
    ├── main.dart
    ├── services/video_storage_service.dart
    └── screens/video_player_screen.dart
```

This is the **Dart/Flutter source**, not a pre-built APK. This environment
doesn't have the Flutter SDK, Android SDK, or access to pub.dev, so I can't
compile an .apk here — but the steps below take about 10 minutes on any
machine with Flutter installed.

## How the app works

- **First launch:** shows a "Choose Workout Video" button. Pick a video from
  your gallery — it's copied into the app's private storage and remembered
  (via `shared_preferences`), so it reloads automatically every time you open
  the app after that.
- **Starts paused**, with one big play button in the middle.
- **Tap anywhere on the video** while it's playing → it pauses.
- **While paused** you get four big buttons: restart from the beginning,
  back 10s, resume (play), forward 10s.
- **Progress bar** at the bottom is always visible and draggable — jump to
  any point in the video any time, playing or paused.
- Tap the video-library icon in the top-right app bar any time to swap in a
  different video.

## Build it yourself

1. **Get Flutter**: https://docs.flutter.dev/get-started/install (any recent
   stable version, e.g. 3.24+).

2. **Create the native scaffolding.** In an empty folder:
   ```bash
   flutter create --org com.yourname nextcue
   ```
   This generates the `android/`, `ios/`, etc. folders that aren't included
   in this package.

3. **Copy in the files from this package**, overwriting the generated
   `pubspec.yaml`, `lib/`, and adding `assets/`:
   ```bash
   cp -r /path/to/this/nextcue/lib        ./nextcue/
   cp -r /path/to/this/nextcue/assets     ./nextcue/
   cp /path/to/this/nextcue/pubspec.yaml  ./nextcue/
   cd nextcue
   ```

4. **Set the app name** so "NextCue" shows under the icon on the home
   screen. Edit `android/app/src/main/AndroidManifest.xml` and set:
   ```xml
   <application
       android:label="NextCue"
       ...>
   ```

5. **Install dependencies:**
   ```bash
   flutter pub get
   ```

6. **Generate the launcher icon** from the artwork in `assets/icon/`:
   ```bash
   dart run flutter_launcher_icons
   ```
   This writes all the mipmap/adaptive-icon resources into `android/`.

7. **Run or build:**
   ```bash
   flutter run                     # test on a connected device/emulator
   flutter build apk --release     # produces build/app/outputs/flutter-apk/app-release.apk
   ```

## Notes

- **Permissions:** `image_picker` handles gallery access itself. On Android
  13+ it uses the system photo/video picker, which needs no runtime
  permission at all. On older Android versions it will prompt for storage
  permission automatically the first time you pick a video — no manifest
  changes needed.
- **Large videos:** the app makes a private copy of the video you pick (so it
  keeps working even if you delete/move the original from your gallery).
  Make sure the device has enough free storage for that copy.
- **Colors/branding:** the theme (`lib/main.dart`) uses the same
  indigo → orange-red gradient as the logo. Tweak `accent` / `deepIndigo`
  there if you want a different look.
- Want an iOS version too? The Dart code is already cross-platform — just
  also run `flutter create` targeting iOS and follow Apple's usual signing
  steps; no code changes needed.
