# SMARTastic

Native macOS app for visualizing SSD and HDD SMART data.

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-blue?logo=apple" alt="macOS">
  <img src="https://img.shields.io/badge/Swift-6-orange?logo=swift" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT">
</p>

---

**SMARTastic** shows drive health at a glance — temperature, wear, errors, TB written, and estimated remaining life. Built with SwiftUI, powered by `smartctl`.

## Features

- **NVMe SSDs & ATA HDDs** — Full SMART data where available
- **Health gauges** — Temperature, spare, media errors, usage
- **Usage stats** — Data read/written, daily write rate, power-on hours
- **Life estimate** — Based on current wear rate
- **Auto-refresh** — Every 30 seconds
- **Color-coded** — Green/orange/red at a glance

## Requirements

- macOS 14+
- `brew install smartmontools`

## Quick Start

```bash
brew install smartmontools
git clone https://github.com/RobinBially/SMARTastic.git
cd SMARTastic
swift build
bash scripts/make-app.sh
open SMARTastic.app
```

Or download from [Releases](https://github.com/RobinBially/SMARTastic/releases).

## How it works

| Interface | Data shown |
|-----------|-----------|
| **Sidebar** | All drives with health status, temperature, usage |
| **Detail** | Health overview, usage metrics, life prognosis, drive info |

HDDs behind USB bridges that don't pass SMART commands show basic info (model, size) with a note that SMART is unavailable.

## License

MIT
