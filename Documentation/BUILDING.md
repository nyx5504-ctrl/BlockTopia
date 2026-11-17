# Building the clients
Open `GodotClient/` in Godot 4.7.2 and install the matching export templates. Export presets are in `export_presets.cfg`.

- **Windows**: export `BlockTopia.exe`; first run registers the `blocktopia://` URL handler for the current user.
- **Linux**: export `BlockTopia.x86_64`; first run registers the `blocktopia://` URL handler.
- **macOS**: export the macOS preset. The release packaging step must add `CFBundleURLTypes` for `blocktopia` and sign the app for normal distribution.
- **Android**: use **Build Android APK**. It builds with the `blocktopia_link` export plugin and checks the APK manifest for the `blocktopia://` intent filter before publishing the APK.
- **Website Play**: after sign-in, Play mints a short-lived, single-use launch code. The Open app link sends that URL to the installed desktop or Android app so it can join the game.
- **iOS**: the export preset declares the `blocktopia://` URL scheme. iOS still needs an Xcode build/signing and URL-event integration before a published iOS app can open a website Play link directly; there is no iOS release workflow yet.
