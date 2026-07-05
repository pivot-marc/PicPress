# PicPress

<img src="Resources/icon-preview.png" width="80" alt="PicPress Icon" align="right">

Menüleisten-App für macOS, die einen Ordner überwacht (z. B. **Downloads**) und neue
Bilder automatisch komprimiert — standardmäßig als WebP mit maximal 1800 px Breite.
Einmal einrichten, nie wieder Bilder von Hand verkleinern.

## Installation

Terminal öffnen und ausführen:

```bash
curl -fsSL https://raw.githubusercontent.com/pivot-marc/PicPress/main/install.sh | bash
```

Das installiert die neueste Version nach `/Applications` und startet die App.
Zum Aktualisieren einfach denselben Befehl erneut ausführen.

**Erste Schritte:**

1. Das Foto-Symbol erscheint oben rechts in der Menüleiste — beim ersten Start öffnet sich das Einstellungsfenster automatisch.
2. Wenn macOS nach dem Zugriff auf den Downloads-Ordner fragt: **Erlauben**.
3. In den Einstellungen **„Bei Anmeldung starten“** aktivieren, damit PicPress immer läuft.

Ab jetzt wird jedes Bild, das im überwachten Ordner landet, automatisch konvertiert.

## Funktionen

- Unterstützt JPG, PNG, GIF, TIFF, BMP, HEIC und WebP als Eingabe
- Ausgabeformat wählbar: **WebP**, HEIC, JPEG oder PNG
- Qualität und maximale Breite einstellbar (breitere Bilder werden proportional verkleinert)
- Original behalten oder in den Papierkorb legen
- Ausgabe in denselben oder einen eigenen Zielordner
- Menüleisten-Übersicht: letzte Konvertierungen mit Ersparnis, Klick öffnet die Datei im Finder
- Wartet, bis Downloads fertig sind; eigene Ausgaben werden nie erneut verarbeitet
- Native App (SwiftUI), Universal Binary für Apple Silicon und Intel, ab macOS 14

## Deinstallation

In den Einstellungen ganz unten auf **„PicPress deinstallieren…“** klicken —
das entfernt den Start bei Anmeldung, löscht alle Einstellungen und legt die
App in den Papierkorb. (Manuell geht es natürlich auch: App beenden und
`PicPress.app` aus dem Programme-Ordner löschen.)

## Selbst bauen

Voraussetzung: Xcode 15+ bzw. Swift 5.10+.

```bash
./Scripts/build-app.sh   # baut dist/PicPress.app und dist/PicPress.zip
./Scripts/build-pkg.sh   # baut zusätzlich ein Installationspaket (.pkg)
```

Hinweis: Das `.pkg` von der Release-Seite ist nicht notarisiert — wird es per Browser
oder Mail übertragen, blockiert macOS die Installation (Gatekeeper). Die Script-Installation
oben umgeht das, weil `curl`-Downloads kein Quarantäne-Attribut erhalten. Für eine
Weitergabe ganz ohne Hinweise lassen sich die Build-Scripts über Umgebungsvariablen
mit einer Apple-Developer-ID signieren und notarisieren (siehe `Scripts/build-pkg.sh`).

## Lizenz

[MIT](LICENSE)
