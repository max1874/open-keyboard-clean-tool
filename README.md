<div align="center">
  <img src="Resources/AppIcon.png" width="160" alt="OpenKeyboardCleanTool macOS app icon">
  <h1>OpenKeyboardCleanTool</h1>
  <p><strong>Lock the keys. Keep the trackpad. Clean your Mac.</strong></p>
  <p>
    <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-111827?logo=apple">
    <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white">
    <img alt="MIT License" src="https://img.shields.io/badge/license-MIT-22c55e">
    <img alt="No dependencies" src="https://img.shields.io/badge/dependencies-none-06b6d4">
    <a href="https://github.com/max1874/open-keyboard-clean-tool/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/max1874/open-keyboard-clean-tool/actions/workflows/ci.yml/badge.svg"></a>
  </p>
  <p><a href="https://github.com/max1874/open-keyboard-clean-tool/releases/latest"><strong>Download the latest DMG</strong></a></p>
</div>

OpenKeyboardCleanTool is a lightweight, open-source KeyboardCleanTool alternative for macOS. It temporarily locks and blocks keyboard input—including modifier, function, and media keys—so you can clean a MacBook keyboard without accidental keystrokes. Your mouse and trackpad remain active, and the app adds no menu bar item, background process, login item, telemetry, or third-party dependency.

<p align="center">
  <img src="docs/app-preview.png" width="720" alt="OpenKeyboardCleanTool macOS keyboard cleaner app">
</p>

## Why use this instead of KeyboardCleanTool?

[KeyboardCleanTool](https://folivora.ai/downloads) is a well-known free utility for blocking keyboard input during cleaning. OpenKeyboardCleanTool offers the same focused cleaning workflow for people who want an MIT-licensed macOS keyboard lock they can inspect, build, and modify themselves.

| Area | OpenKeyboardCleanTool behavior |
| --- | --- |
| Source | Public Swift and SwiftUI code under the MIT License |
| Keyboard coverage | Normal, modifier, function, brightness, volume, and media keys |
| Pointer access | Mouse, trackpad, clicking, and scrolling remain available |
| App lifecycle | Runs only when opened; optional lock on launch and quit after cleaning |
| Background activity | No menu-bar item, login item, daemon, background helper, networking, or telemetry |

## Features

- **Open only when needed.** No menu-bar item, login item, daemon, or background helper.
- **Mouse stays active.** Finish cleaning and quit with one click.
- **Optional instant lock.** Choose whether the keyboard locks as soon as the app opens.
- **Your finish behavior.** Quit automatically after cleaning, or stay open for another round.
- **Native on macOS.** SwiftUI with Liquid Glass on macOS 26 and a material fallback on earlier releases.
- **Private by design.** No network access, analytics, telemetry, or third-party dependencies.

## Requirements

- macOS 13 or later
- Apple silicon Mac
- Accessibility permission, required by macOS to intercept keyboard events

## How do I install this macOS keyboard cleaner?

1. Download the DMG and matching `.sha256` file from the [latest release](https://github.com/max1874/open-keyboard-clean-tool/releases/latest).
2. Verify the download in Terminal:

   ```sh
   shasum -a 256 -c OpenKeyboardCleanTool-0.1.0.dmg.sha256
   ```

3. Open the DMG and drag OpenKeyboardCleanTool to **Applications**.
4. Try to open the app once. Because the privacy-preserving build is ad-hoc signed and not notarized, macOS will block the first launch.
5. Open **System Settings → Privacy & Security**, scroll to **Security**, then click **Open Anyway** and confirm.
6. In **System Settings → Privacy & Security → Accessibility**, enable OpenKeyboardCleanTool. Return to the app and click **Check Again**.

The release workflow builds on a clean GitHub-hosted macOS runner, uses an ad-hoc signature, and rejects a candidate if the mounted image contains a signing certificate or printable email address or `/Users/...` build path. This avoids embedding the maintainer's personal Apple Development certificate, but it also means Gatekeeper cannot identify the developer. Review the source and checksum before overriding macOS security.

## Build from source

```sh
git clone https://github.com/max1874/open-keyboard-clean-tool.git
cd open-keyboard-clean-tool
make app
open build/OpenKeyboardCleanTool.app
```

On first launch, allow OpenKeyboardCleanTool in **System Settings → Privacy & Security → Accessibility**, return to the app, and click **Check Again**.

The build uses a local Apple Development certificate so Accessibility permission remains attached across rebuilds. To select one explicitly:

```sh
SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" make app
```

For a one-off ad-hoc-signed local build:

```sh
SIGN_IDENTITY=- make app
```

Ad-hoc signatures can change identity after rebuilding, so macOS may ask for Accessibility permission again.

## Development

```sh
make test       # Run the Swift test suite
make icon       # Regenerate the app icon asset catalog from Resources/AppIcon.png
make dmg        # Build a local drag-to-Applications DMG
```

Maintainers can run **Release candidate** manually in GitHub Actions to build and audit a seven-day downloadable candidate. The workflow does not create a GitHub Release or publish anything automatically.

## How does it block keyboard input?

Keyboard filtering lives entirely inside the foreground process. A macOS Quartz event tap discards key-down, key-up, modifier, function, brightness, volume, and media-key events only while cleaning mode is active. Pointer, click, and scroll events pass through, so you can finish with the mouse or trackpad. Quitting the app or a process crash removes the event tap automatically.

## Security and privacy

Accessibility access is powerful. This app uses it only to discard keyboard events while cleaning mode is active. The implementation is small enough to audit, performs no networking, and installs no persistent component.

## License

[MIT](LICENSE) © 2026 Max
