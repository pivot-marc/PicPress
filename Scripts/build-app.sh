#!/bin/bash
# Baut PicPress.app (Universal Binary) nach dist/.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="PicPress"
ARCH_FLAGS=(--arch arm64 --arch x86_64)

echo "▸ Release-Build (Universal Binary)…"
if ! swift build -c release "${ARCH_FLAGS[@]}" 2>/dev/null; then
    echo "  Universal Build nicht möglich, baue für native Architektur."
    ARCH_FLAGS=()
    swift build -c release
fi

BIN_PATH="$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)/$APP_NAME"
APP="dist/$APP_NAME.app"

echo "▸ Bundle zusammenstellen…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/$APP_NAME"
cp Support/Info.plist "$APP/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

# Mit PICPRESS_SIGN_IDENTITY="Developer ID Application: …" wird richtig
# signiert (Voraussetzung für Notarisierung), sonst ad-hoc.
SIGN_IDENTITY="${PICPRESS_SIGN_IDENTITY:--}"
if [ "$SIGN_IDENTITY" = "-" ]; then
    echo "▸ Ad-hoc-Signierung (nur für lokale Nutzung geeignet)…"
    codesign --force --deep --sign - "$APP"
else
    echo "▸ Signierung mit: $SIGN_IDENTITY"
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
fi

# Zip-Archiv für die Script-Installation (install.sh lädt
# …/releases/latest/download/PicPress.zip — der Name muss stabil bleiben).
echo "▸ Zip-Archiv für Releases…"
ditto -c -k --keepParent "$APP" "dist/$APP_NAME.zip"

echo "✓ Fertig: $APP + dist/$APP_NAME.zip"
lipo -info "$APP/Contents/MacOS/$APP_NAME" 2>/dev/null || true
