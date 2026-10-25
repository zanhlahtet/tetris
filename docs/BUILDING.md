# Building and installing on devices

The repository contains `export_presets.cfg` with an **Android** and an **iOS**
preset. It holds no credentials: keystores, passwords, signing identities and
Apple team IDs are supplied from your machine and are never committed
(`.gitignore` blocks `*.keystore`, `*.jks`, `*.p12`, `*.mobileprovision`,
`export_credentials.cfg`, `build/`).

Before shipping, change the placeholders in the presets (or in
*Project > Export*): the package / bundle id (`com.example.tetris`), the display
name, and the version (`0.1.0`, code/build `1`).

## Prerequisites (both platforms)
- Godot 4.7.1 (the version the project was built with).
- Export templates matching the editor: *Editor > Manage Export Templates >
  Download and Install* (they live in `~/Library/Application Support/Godot/export_templates/4.7.1.stable`).
- Run `godot --headless --path . --import` once so the `.godot/` cache exists.
- Project settings already required by the exporters: VRAM compression
  *Import ETC2 ASTC* is on (needed by Android), orientation is portrait.

CLI export, from the repo root (create the output folder first):

```
mkdir -p build/android build/ios
godot --headless --path . --export-debug "Android" build/android/tetris.apk
godot --headless --path . --export-debug "iOS" build/ios/Tetris.xcodeproj
```

## Android
1. Install JDK 17+ and the Android SDK (command-line tools, platform-tools,
   build-tools, one platform). Android Studio installs all of this.
2. In Godot: *Editor > Editor Settings > Export > Android* set **Android SDK
   Path** and **Java SDK Path**.
3. Debug keystore (once):
   `keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deploymentType PKCS12`
   and point *Editor Settings > Export > Android > Debug Keystore* at it
   (Godot also generates one automatically if the SDK is configured).
4. Export a debug APK with the CLI above (or *Project > Export > Android >
   Export Project*).
5. Install: enable USB debugging on the phone, then
   `adb install -r build/android/tetris.apk`.
   For an emulator, start an AVD first and run the same command.

Release builds (Play Store) need your own release keystore: create it with
`keytool`, keep it outside the repo, and supply it through the export dialog or
the environment variables Godot reads:
`GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`,
`GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`. Switch *Gradle Build > Export Format*
to AAB for Play uploads (this requires installing the Gradle build template).

## iOS
Requires macOS, Xcode and an Apple ID (a free Apple ID can install on your own
device for 7 days; the paid Developer Program is needed for TestFlight and the
App Store).
1. Open Xcode once, sign in under *Settings > Accounts*, and let it install the
   iOS platform.
2. Find your **Team ID** (Xcode > Settings > Accounts, or developer.apple.com >
   Membership). Enter it in *Project > Export > iOS > Application > App Store
   Team ID* in the editor. Do **not** commit it if you consider it private; you
   can instead keep the change uncommitted.
3. Make the bundle identifier unique to you (the default `com.example.tetris`
   cannot be registered).
4. Export: `godot --headless --path . --export-debug "iOS" build/ios/Tetris.xcodeproj`.
   Godot generates the Xcode project in `build/ios/` and then tries to archive
   it; if signing is not configured yet the archive step reports signing errors
   but the project is already generated.
5. Open `build/ios/Tetris.xcodeproj` in Xcode, select the *Tetris* target >
   *Signing & Capabilities*, choose your team, plug in the phone (enable
   Developer Mode on the device), select it and press Run. Trust the developer
   profile on the phone under *Settings > General > VPN & Device Management* if
   prompted.
6. For TestFlight/App Store: set `application/export_method_release` to App
   Store, archive from Xcode (*Product > Archive*) and upload with the
   Organizer.

## Verification status of this configuration
Checked on the development machine (Godot 4.7.1 with matching templates, macOS,
Xcode 27, Android SDK build-tools 36):
- **Android:** a debug APK was exported, aligned and signed with the debug
  keystore (`com.example.tetris`, `versionName 0.1.0`, arm64-v8a only,
  `aapt2 dump badging` and `apksigner verify` pass). It has **not** been
  installed or run: an Android emulator was started but never came online, and
  no physical device was attached.
- **iOS:** the Xcode project generates successfully. Archiving/signing was
  **not** completed because that needs a real Apple team and provisioning
  profile, which are intentionally not stored here; no `.ipa` exists. A
  throwaway attempt to link the generated project for the iOS Simulator without
  signing failed at the link step (the simulator slice in the installed
  template), so the iOS build has not been run anywhere. Xcode also warns that
  the camera/microphone/photo-library usage strings are empty; the game uses
  none of those, but expect to review them before an App Store submission.
- PCK export (`--export-pack`) works and excludes `tests/` and `docs/`.

## Troubleshooting
- *"ETC2/ASTC texture compression is required"*: re-import after enabling it in
  Project Settings (already set in this repo).
- *"IPHONEOS_DEPLOYMENT_TARGET ... supported range"*: raise
  `application/min_ios_version` to what your Xcode supports (15.0 here).
- Touch controls not responding in the desktop editor: the project emulates
  touch from the mouse, so click the on-screen buttons.
- Reset local data: delete `user://save.cfg` (macOS:
  `~/Library/Application Support/Godot/app_userdata/Tetris/save.cfg`).
