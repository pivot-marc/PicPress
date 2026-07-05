#!/bin/bash
# Baut ein Installationspaket dist/PicPress-<version>.pkg,
# das PicPress.app nach /Applications installiert.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Support/Info.plist)"
IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Support/Info.plist)"

./Scripts/build-app.sh

PKG="dist/PicPress-$VERSION.pkg"
echo "▸ Paket bauen…"

# Bundle in ein sauberes Root-Verzeichnis legen und Relocation abschalten —
# sonst aktualisiert der Installer u. U. eine woanders liegende Kopie der App
# statt nach /Applications zu installieren.
PKGROOT="dist/pkgroot"
rm -rf "$PKGROOT"
mkdir -p "$PKGROOT"
cp -R "dist/PicPress.app" "$PKGROOT/PicPress.app"

COMPONENT_PLIST="dist/component.plist"
pkgbuild --analyze --root "$PKGROOT" "$COMPONENT_PLIST" >/dev/null
/usr/libexec/PlistBuddy -c 'Set :0:BundleIsRelocatable false' "$COMPONENT_PLIST"

pkgbuild \
    --root "$PKGROOT" \
    --component-plist "$COMPONENT_PLIST" \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    --install-location /Applications \
    "$PKG"

# Mit PICPRESS_INSTALLER_IDENTITY="Developer ID Installer: …" wird das
# Paket signiert — Voraussetzung für die Weitergabe ohne Gatekeeper-Warnung.
if [ -n "${PICPRESS_INSTALLER_IDENTITY:-}" ]; then
    echo "▸ Paket signieren…"
    SIGNED="dist/PicPress-$VERSION-signed.pkg"
    productsign --sign "$PICPRESS_INSTALLER_IDENTITY" "$PKG" "$SIGNED"
    mv "$SIGNED" "$PKG"
fi

# Mit PICPRESS_NOTARY_PROFILE=<keychain-profil> wird das Paket bei Apple
# notarisiert und das Ticket angeheftet (Profil anlegen mit:
#   xcrun notarytool store-credentials <name> --apple-id … --team-id … --password <app-spezifisch>)
if [ -n "${PICPRESS_NOTARY_PROFILE:-}" ]; then
    echo "▸ Notarisierung (kann einige Minuten dauern)…"
    xcrun notarytool submit "$PKG" --keychain-profile "$PICPRESS_NOTARY_PROFILE" --wait
    xcrun stapler staple "$PKG"
fi

echo "✓ Fertig: $PKG"
