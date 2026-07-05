#!/bin/bash
# PicPress-Installation im Homebrew-Stil:
#   curl -fsSL https://raw.githubusercontent.com/pivot-marc/PicPress/main/install.sh | bash
#
# Lädt die neueste Version von GitHub und installiert sie nach /Applications.
# Da der Download über curl läuft, wird kein Quarantäne-Attribut gesetzt —
# es gibt also keine Gatekeeper-Warnung.
set -euo pipefail

REPO="pivot-marc/PicPress"
APP_NAME="PicPress"
DOWNLOAD_URL="https://github.com/$REPO/releases/latest/download/$APP_NAME.zip"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "▸ Lade neueste $APP_NAME-Version…"
curl -fsSL "$DOWNLOAD_URL" -o "$TMP_DIR/$APP_NAME.zip"
ditto -x -k "$TMP_DIR/$APP_NAME.zip" "$TMP_DIR"

if [ ! -d "$TMP_DIR/$APP_NAME.app" ]; then
    echo "✗ Archiv enthält kein $APP_NAME.app — Abbruch." >&2
    exit 1
fi

# Zielordner: /Applications, sonst ~/Applications als Ausweichlösung.
DEST_DIR="/Applications"
if [ ! -w "$DEST_DIR" ]; then
    DEST_DIR="$HOME/Applications"
    mkdir -p "$DEST_DIR"
fi
DEST="$DEST_DIR/$APP_NAME.app"

# Laufende Instanz beenden, bevor das Bundle ersetzt wird.
if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    echo "▸ Beende laufende $APP_NAME-Instanz…"
    pkill -x "$APP_NAME" || true
    sleep 1
fi

if [ -d "$DEST" ] && [ ! -w "$DEST" ]; then
    echo "▸ Vorhandene Installation gehört einem anderen Benutzer — Administratorrechte nötig."
    sudo rm -rf "$DEST"
fi

echo "▸ Installiere nach $DEST…"
rm -rf "$DEST"
ditto "$TMP_DIR/$APP_NAME.app" "$DEST"

# Sicherheitshalber: Quarantäne entfernen, falls das Script selbst aus einem
# quarantänisierten Kontext lief.
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

open "$DEST"

echo ""
echo "✓ $APP_NAME wurde installiert und gestartet."
echo "  Das Foto-Symbol findest du oben rechts in der Menüleiste."
echo "  Beim ersten Start öffnet sich das Einstellungsfenster automatisch."
