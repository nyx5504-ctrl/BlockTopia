# Building the clients
Open `GodotClient/` in Godot 4.7.2 (it has `project.godot`). Install export templates (Editor > Manage Export Templates). Presets for all five platforms are in `export_presets.cfg`.
Automated: GitHub > Actions > **Build clients** (Windows, Linux, macOS zip, Android debug APK, iOS Xcode project).

- **Windows**: Project > Export > Windows > `BlockTopia.exe`. On first run the client registers `blocktopia://` for the current user.
- **Linux**: export `BlockTopia.x86_64`; first run registers the protocol (or run `register-protocol.sh`).
- **macOS**: export zip; the workflow adds `CFBundleURLTypes` for `blocktopia`. Unsigned: right-click > Open. Needs a Mac + Apple Developer ID to sign/notarize.
- **Android**: needs JDK 17 + Android SDK in Editor Settings. The APK builds, but the `blocktopia://` link is not wired to the app (needs a custom Gradle build intent filter). Use **Join from link** in the app, or fix per Godot's Android docs.
- **iOS**: needs a Mac, Xcode and an Apple Developer account. Export the Xcode project, sign, then TestFlight/App Store; put the link in `DOWNLOADS.ios`.
