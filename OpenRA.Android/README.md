# AndroidRA

AndroidRA is an unofficial Android port of [OpenRA](https://www.openra.net). It runs the regular OpenRA
engine and the Red Alert, Tiberian Dawn and Dune 2000 mods on arm64 Android devices with OpenGL ES 3.0.

AndroidRA is not made or endorsed by the OpenRA developers. Please report problems with the port here
rather than to the OpenRA project.

## Requirements

* Android 7.0 (API 24) or newer, 64-bit ARM (arm64-v8a), OpenGL ES 3.0.
* The game content is not included: on first launch use **Quick Install** (needs internet) or
  **Advanced Install** to copy it from your own copy of the games.

## Building

Tested on Linux with:

* .NET SDK 10 with the Android workload: `sudo dotnet workload install android`
* JDK 17 (newer JDKs are not supported by .NET for Android)
* Android SDK, NDK 29 and CMake 3.31:
  ```bash
  dotnet build OpenRA.Android/OpenRA.Android.csproj -t:InstallAndroidDependencies -f net10.0-android -p:AcceptAndroidSDKLicenses=True
  ~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager "ndk;29.0.14206865" "cmake;3.31.6"
  ```

Then, from the repository root:

```bash
./packaging/android/build-native.sh   # SDL2, OpenAL Soft, FreeType, Lua and libmain (checksum-verified sources)
./packaging/android/build-apk.sh      # OpenRA.Android/bin/Release/publish/pl.androidra-Signed.apk
```

Install with `adb install -r <apk>` or copy the APK to the device.

By default the APK is signed with the local .NET Android debug key. See the comment at the top of
`packaging/android/build-apk.sh` for signing with your own key. Never commit a keystore or its passwords.
The script also copies a versioned APK and its SHA-256 checksum to `release/` for GitHub Releases.

Release builds use the CoreCLR runtime, which is still experimental on Android. Pass
`-p:UseMonoRuntime=true` to `build-apk.sh` to build with Mono and full AOT compilation instead.

## Controls

| Gesture | Action |
|---|---|
| Tap | Left click: select, give orders, press buttons |
| Double tap | Select all units of the same type |
| Drag with one finger | Selection box, scroll lists, move sliders |
| Drag with two fingers | Scroll the map |
| Pinch | Zoom |
| Long press, or tap with two fingers | Right click: deselect, pause or cancel production |
| Back button | Escape (in-game menu) |

The touch controls use the *Classic* mouse style, which is enforced on every launch. The on-screen
keyboard appears when a text field is selected; press Back to dismiss it.

## Files on the device

* Engine data (mods, shaders) is extracted to the app's private storage on first launch after each install.
* Settings, logs, replays, saved games, maps and downloaded content are stored in
  `Android/data/pl.androidra/files/`. Custom maps go in `maps/<mod>/{DEV_VERSION}/`.

## Known limitations

* Only arm64-v8a is built by default (`ABIS="arm64-v8a x86_64"` for the emulator).
* Very large games (many AI players on huge maps) are limited by the single-threaded simulation and will
  slow down on phones.
* On Android 10 and older, other apps with storage permission can read and modify the files in
  `Android/data/pl.androidra/files/` (settings, replays, maps, game content).
* The engine version is shown as `{DEV_VERSION}`, so online games are only possible with other players
  running the same development build.

Third-party licenses are listed in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
