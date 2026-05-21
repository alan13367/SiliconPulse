# <img src="SiliconPulse/Assets.xcassets/AppIcon.appiconset/icon_32x32.png" width="32" height="32" align="center"> SiliconPulse

SiliconPulse is a native macOS menu bar utility for real-time system monitoring. It tracks CPU, GPU, memory, network, thermal pressure, battery, disk usage, and fan speeds — optimized for Apple Silicon, with a dedicated Top Processes window for inspection and process management.

![SiliconPulse](SiliconPulse/Assets.xcassets/AppIcon.appiconset/icon_256x256.png)

## Features

### Menu bar dashboard
- **CPU** — usage gauge, temperature badge, per-core bars (optional), history sparkline
- **GPU** — utilization via IOAccelerator / IOReport (hidden when unavailable)
- **Memory** — used/total, pressure gauge, optional breakdown (App, Wired, Compressed, Free)
- **Network** — live download/upload speeds, session totals, history chart
- **Storage** — per-volume usage and free space
- **Power** — charge level, time remaining, cycles, health (when a battery is present)
- **Fans** — RPM readout and manual control (Automatic / Manual / Maximum / Off)
- **Thermal** — system thermal pressure level and description

The menu bar label shows live **CPU %** and **memory %**, with a warning icon when thermal pressure is elevated.

### Top Processes window
- Sort by CPU, memory, or name
- Search/filter by process name
- Process detail view with usage gauges
- Terminate processes (SIGTERM, then SIGKILL)

### Settings
Tabbed preferences (General, Display, Network, Processes, About):
- Update interval (1s, 2s, 5s)
- Toggle dashboard sections
- °C / °F, B/s vs bps, network history length
- Default process sort order
- Reset all preferences

### Fan control (Apple Silicon)
Reading fan speeds uses SMC via IOKit. **Writing** fan speeds on Apple Silicon requires installing a privileged helper (`FanHelper`) via `SMJobBless` the first time you change fan mode — macOS will prompt for your password. Fan control availability varies by Mac model; some Apple Silicon machines expose limited or no SMC fan keys.

## Requirements

- **macOS 14.0** or later
- Apple Silicon Mac recommended (Intel builds are supported; some GPU/fan paths differ)

## Installation

1. Download the latest `SiliconPulse.dmg` from [Releases](https://github.com/alan13367/SiliconPulse/releases).
2. Open the DMG and drag **SiliconPulse** to **Applications**.
3. Launch the app. If Gatekeeper blocks an unsigned build, right-click the app and choose **Open**.

## Usage

SiliconPulse runs as a menu bar app (no Dock icon). Click the menu bar item to open the dashboard.

**Footer controls**
| Control | Action |
|---------|--------|
| **Every Xs** | Change refresh rate (1 / 2 / 5 seconds) |
| **List** | Open Top Processes window |
| **Gear** | Open Settings (⌘,) |
| **Power** | Quit SiliconPulse |

## Development

### Requirements
- macOS 14.0+
- Xcode 15.0+ with the macOS SDK
- Apple Development signing team configured (required for FanHelper `SMJobBless`)

### Build

```bash
xcodebuild -project SiliconPulse.xcodeproj -scheme SiliconPulse -configuration Debug build
```

### Run the built app

```bash
APP_PATH="$(find ~/Library/Developer/Xcode/DerivedData -name "SiliconPulse.app" -type d | grep -v "Index.noindex" | head -n 1)"
open -n "$APP_PATH"
```

### Build and launch (one command)

```bash
xcodebuild -project SiliconPulse.xcodeproj -scheme SiliconPulse -configuration Debug build && \
  APP_PATH="$(find ~/Library/Developer/Xcode/DerivedData -name "SiliconPulse.app" -type d | grep -v "Index.noindex" | head -n 1)" && \
  open -n "$APP_PATH"
```

### Project layout

See [AGENTS.md](AGENTS.md) for architecture, private API notes, and agent-oriented build/debug instructions.

```
SiliconPulse/
├── SiliconPulse/          # Main app (SwiftUI views, services, models)
├── FanHelper/             # Privileged helper for SMC fan writes (arm64)
└── SiliconPulse.xcodeproj
```

## Contributing

Contributions are welcome. Open an issue for bugs or feature requests, or submit a pull request.

## License

MIT License — see [LICENSE](LICENSE).

---

*Created by Alan Beltran Pozo.*
