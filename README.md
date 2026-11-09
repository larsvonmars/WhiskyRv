<div align="center">

  # Whisky 🥃 
  *Wine but a bit stronger*
  
  ![](https://img.shields.io/github/actions/workflow/status/IsaacMarovitz/Whisky/SwiftLint.yml?style=for-the-badge)
  [![](https://img.shields.io/discord/1115955071549702235?style=for-the-badge)](https://discord.gg/CsqAfs9CnM)
</div>

## This fork (WhiskyRv)

This is a personal fork that keeps Whisky usable on current macOS releases. Upstream development has stopped,
so the pieces that depended on upstream infrastructure were replaced:

| Area | Upstream | This fork |
|------|----------|-----------|
| Wine runtime | `data.getwhisky.app` (no longer reachable) | [Gcenx Wine builds](https://github.com/Gcenx/macOS_Wine_builds) 11.21 + [DXVK-macOS](https://github.com/Gcenx/DXVK-macOS) |
| Runtime updates | Remote version plist | Local version check against the bundled runtime version |
| App updates | Sparkle appcast (now only publishes an end-of-life notice) | Removed |
| Bundle identifier | `com.isaacmarovitz.Whisky` | `de.larsvonmars.WhiskyRv` |
| Code signing | Forced Developer ID + team ID | “Sign to Run Locally” (ad-hoc), no team required |

Bottles are kept in the container of upstream Whisky (`~/Library/Containers/com.isaacmarovitz.Whisky`).
macOS protects app containers and does not allow one application to rename the container of another one, so
existing bottles simply stay where they are and keep working. Preferences, logs and the Wine runtime are
migrated to the new bundle identifier on first launch.

## Maintenance Notice

[Whisky is no longer actively maintained](https://docs.getwhisky.app/maintenance-notice). Apps and games may break at any time.

<img width="650" alt="Config" src="https://github.com/Whisky-App/Whisky/assets/42140194/d0a405e8-76ee-48f0-92b5-165d184a576b">

Familiar UI that integrates seamlessly with macOS

<div align="right">
  <img width="650" alt="New Bottle" src="https://github.com/Whisky-App/Whisky/assets/42140194/ed1a0d69-d8fb-442b-9330-6816ba8981ba">

  One-click bottle creation and management
</div>

<img width="650" alt="debug" src="https://user-images.githubusercontent.com/42140194/229176642-57b80801-d29b-4123-b1c2-f3b31408ffc6.png">

Debug and profile with ease

---

Whisky provides a clean and easy to use graphical wrapper for Wine built in native SwiftUI. You can make and manage bottles, install and run Windows apps and games, and unlock the full potential of your Mac with no technical knowledge required. This fork runs a WoW64 capable Wine 11.21 build from Gcenx together with DXVK, D9VK and Metal.

Translated on [Crowdin](https://crowdin.com/project/whisky).

---

## System Requirements
- CPU: Apple Silicon (M-series chips)
- OS: macOS Sonoma 14.0 or later (built and tested on macOS 27.2 with Xcode 27.2)
- Rosetta 2, required to run the `x86_64` Wine build

## Building from source

```bash
xcodebuild -scheme Whisky -configuration Release -destination 'platform=macOS' build
```

The project signs with “Sign to Run Locally”, so no Developer ID certificate or team is needed. SwiftLint runs
as a build phase when it is installed (`brew install swiftlint`) and is skipped otherwise.

## Wine runtime

Whisky does not download a runtime on its own. The setup assistant fetches the archives below and assembles
`~/Library/Application Support/de.larsvonmars.WhiskyRv/Libraries`:

- Wine: `wine-staging-11.21-osx64.tar.xz` from [Gcenx/macOS_Wine_builds](https://github.com/Gcenx/macOS_Wine_builds)
- DXVK: `dxvk-macOS-async-v1.10.3-20230507-repack.tar.gz` from [Gcenx/DXVK-macOS](https://github.com/Gcenx/DXVK-macOS)

The version that is installed is pinned in `WhiskyWineInstaller.supportedRuntimeVersion`. If the download fails,
the setup assistant also accepts a local archive of the old `WhiskyWine` layout (a tarball that already contains
`Libraries/Wine` and `Libraries/DXVK`).

## Homebrew

Upstream Whisky is available as `brew install --cask whisky`. It installs the unmaintained app and its runtime
endpoints no longer work, so prefer building this fork from source.

## My game isn't working!

Some games need special steps to get working. Check out the [wiki](https://github.com/IsaacMarovitz/Whisky/wiki/Game-Support).

---

## Credits & Acknowledgments

Whisky is possible thanks to the magic of several projects:

- [msync](https://github.com/marzent/wine-msync) by marzent
- [Wine](https://www.winehq.org) and the [Gcenx macOS Wine builds](https://github.com/Gcenx/macOS_Wine_builds)
- [DXVK-macOS](https://github.com/Gcenx/DXVK-macOS) by Gcenx and doitsujin
- [MoltenVK](https://github.com/KhronosGroup/MoltenVK) by KhronosGroup
- [SemanticVersion](https://github.com/SwiftPackageIndex/SemanticVersion) by SwiftPackageIndex
- [swift-argument-parser](https://github.com/apple/swift-argument-parser) by Apple
- [SwiftTextTable](https://github.com/scottrhoyt/SwiftyTextTable) by scottrhoyt
- [CrossOver](https://www.codeweavers.com/crossover) by CodeWeavers and WineHQ, which upstream Whisky was based on
- D3DMetal by Apple

Special thanks to Gcenx, ohaiibuzzle, and Nat Brown for their support and contributions!

---
