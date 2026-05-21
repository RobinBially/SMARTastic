# SMARTastic

<p align="center">
  <img src="assets/banner.png" alt="SMARTastic" width="600">
</p>

<p align="center">
  <b>Native macOS App für SSD- und HDD-SMART-Daten</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Plattform-macOS%2014%2B-blue?logo=apple" alt="macOS">
  <img src="https://img.shields.io/badge/Swift-6.3-orange?logo=swift" alt="Swift">
  <img src="https://img.shields.io/badge/SwiftUI-native-purple" alt="SwiftUI">
  <img src="https://img.shields.io/badge/Lizenz-MIT-green" alt="MIT">
  <img src="https://img.shields.io/badge/Status-Aktiv-brightgreen" alt="Status">
</p>

---

**SMARTastic** ist eine minimalistische, native macOS-App, die SMART-Daten von NVMe-SSDs und ATA-HDDs visualisiert – direkt auf deinem Rechner, ohne Cloud, ohne Tracking.

Alles läuft lokal über `smartctl` (smartmontools). Die App zeigt dir auf einen Blick:

- **Lebensdauer** der SSDs (Percentage Used, TBW, Restlaufzeit)
- **Temperatur** der Laufwerke
- **Geschriebene/Gelesene Datenmenge** in TB
- **Medienfehler**, Power Cycles, Unsafe Shutdowns
- **Health-Score** mit farblicher Ampelführung

## Features

| Feature | Beschreibung |
|---------|-------------|
| 🖥️ **Native macOS UI** | SwiftUI mit NavigationSplitView, `.ultraThinMaterial` |
| 🔍 **NVMe + ATA** | Unterstützt NVMe-SSDs und (SMART-fähige) ATA/HDDs |
| 📊 **Health-Gauges** | Animierte Ringdiagramme für Lebensdauer, Temperatur, Reserve |
| 📈 **Nutzungsstatistik** | TB gelesen/geschrieben, tägliche Schreibrate, Betriebsstunden |
| ⏳ **Restlebensdauer** | Schätzung basierend auf aktuellem Verbrauch |
| ⚡ **Auto-Refresh** | Automatische Aktualisierung alle 30 Sekunden |
| 🏷️ **Badges** | SMART-Status, Laufwerkstyp, Health-Label |
| 🎨 **Farbcodierung** | Grün/Gelb/Rot je nach Zustand der SSD/HDD |
| 📦 **Keine Abhängigkeiten** | Nur SwiftUI + smartctl |

## Voraussetzungen

- macOS 14 (Sonoma) oder neuer
- [smartmontools](https://www.smartmontools.org) (`brew install smartmontools`)

## Installation

```bash
# 1. smartmontools installieren (falls nicht vorhanden)
brew install smartmontools

# 2. App aus dem Release laden oder selbst bauen
git clone https://github.com/robin/SMARTastic.git
cd SMARTastic
swift build
bash scripts/make-app.sh
open SMARTastic.app
```

Oder das aktuelle Release aus [Releases](https://github.com/robin/SMARTastic/releases) herunterladen.

## Verwendung

Nach dem Start scannt SMARTastic automatisch alle externen physischen Laufwerke:

1. **Sidebar** – zeigt alle erkannten SSDs/HDDs mit Status, Temperatur und Health-Score
2. **Detailansicht** – Klick auf ein Laufwerk öffnet die Detailseite mit:
   - **Gesundheit** – Große Gauges für Lebensdauer, Temperatur, Reserve, Medienfehler
   - **Nutzung** – Lese-/Schreibvolumen, Betriebszeit, Power Cycles
   - **Lebensdauer-Prognose** – Verbrauch, Schreibrate, Restlaufzeit
   - **Laufwerks-Informationen** – Seriennummer, Firmware, Kapazität

### HDDs ohne SMART

Bei USB-HDDs, deren Bridge-Chip keine SMART-Daten durchreicht, zeigt SMARTastic die verfügbaren Basisinformationen (Modell, Größe) und einen Hinweis an, dass SMART nicht verfügbar ist.

## Eigenes Build erstellen

```bash
cd ~/SMARTastic
swift build
bash scripts/make-app.sh
```

Das erzeugte `.app`-Bundle liegt dann im Projektordner und kann per `open SMARTastic.app` oder via Spotlight gestartet werden.

## Technologie

- **Sprache:** Swift 6
- **UI-Framework:** SwiftUI (macOS 14+)
- **SMART-Daten:** smartmontools (`smartctl`)
- **System-APIs:** `diskutil` für Laufwerkserkennung
- **Build-Tool:** Swift Package Manager

## Lizenz

MIT – siehe [LICENSE](LICENSE).

---

<p align="center">
  Made with ❤️ and SwiftUI
</p>
