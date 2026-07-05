# PicPress

<img src="Resources/icon-preview.png" width="80" alt="PicPress Icon" align="right">

Menu bar app for macOS that watches a folder (e.g. **Downloads**) and automatically
compresses new images — by default as WebP with a maximum width of 1800 px.
Set it up once, never resize images by hand again.

## Installation

Open Terminal and run:

```bash
curl -fsSL https://raw.githubusercontent.com/pivot-marc/PicPress/main/install.sh | bash
```

This installs the latest version to `/Applications` and launches the app.
To update, simply run the same command again.

**Getting started:**

1. The photo icon appears at the top right of the menu bar — on first launch, the settings window opens automatically.
2. When macOS asks for access to the Downloads folder: **Allow**.
3. Enable **"Launch at Login"** in the settings so PicPress is always running.

From now on, every image that lands in the watched folder is converted automatically.

## Features

- Supports JPG, PNG, GIF, TIFF, BMP, HEIC, and WebP as input
- Selectable output format: **WebP**, HEIC, JPEG, or PNG
- Adjustable quality and maximum width (wider images are scaled down proportionally)
- Keep the original or move it to the Trash
- Output to the same folder or a custom destination folder
- Menu bar overview: recent conversions with savings, click to reveal the file in Finder
- Waits until downloads are complete; its own output files are never processed again
- Native app (SwiftUI), universal binary for Apple Silicon and Intel, requires macOS 14+

## Uninstall

Click **"Uninstall PicPress…"** at the bottom of the settings window —
this removes the launch-at-login entry, deletes all settings, and moves the
app to the Trash. (You can also do it manually: quit the app and delete
`PicPress.app` from the Applications folder.)

## Building from Source

Requirements: Xcode 15+ / Swift 5.10+.

```bash
./Scripts/build-app.sh   # builds dist/PicPress.app and dist/PicPress.zip
./Scripts/build-pkg.sh   # additionally builds an installer package (.pkg)
```

Note: The `.pkg` from the releases page is not notarized — if it is transferred via
browser or email, macOS blocks the installation (Gatekeeper). The script installation
above avoids this because `curl` downloads don't receive a quarantine attribute. For
distribution without any warnings, the build scripts can be signed and notarized with
an Apple Developer ID via environment variables (see `Scripts/build-pkg.sh`).

## License

[MIT](LICENSE)
