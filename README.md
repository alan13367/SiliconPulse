# SiliconPulse 

SiliconPulse is a high-performance, lightweight system monitor designed specifically for Apple Silicon macOS. It lives in your menu bar and provides real-time insights into your Mac's CPU, Memory, Network, and Thermal states using native Mach APIs and SystemConfiguration frameworks.

![SiliconPulse Header](https://raw.githubusercontent.com/alan13367/SiliconPulse/main/SiliconPulse/Assets.xcassets/AppIcon.appiconset/icon_256x256.png)

## Features

- **CPU & GPU Monitoring:** Real-time usage tracking for both CPU (per-core) and GPU utilization, with combined live history charts.
- **Top Processes:** Live list of the top 5 resource-heavy processes by memory usage.
- **Memory Management:** Detailed breakdown of App Memory, Wired, and Compressed usage, matching macOS Activity Monitor's calculation logic.
- **Network Stats:** High-precision bandwidth tracking with dynamic interface switching (Wi-Fi/Ethernet) and session-based data totals.
- **Thermal Awareness:** Monitor system thermal pressure levels (Nominal to Critical) to understand when your Mac is throttling.
- **Highly Customizable:**
    - Adjustable update intervals (1s to 5s).
    - Toggleable display sections.
    - Customizable usage colors.
    - Bits per second (bps) or Bytes per second (B/s) network units.
- **Native Experience:** Built with SwiftUI and Swift Charts for a modern, fluid macOS aesthetic.

## Installation

1. Download the latest `SiliconPulse.dmg` from the [Releases](https://github.com/alan13367/SiliconPulse/releases) page.
2. Open the DMG and drag **SiliconPulse** to your **Applications** folder.
3. Launch the app. (Since it is self-signed, you may need to Right-Click > Open for the first run).

## Usage

Once launched, SiliconPulse lives in your menu bar. Click the icon to open the main dashboard. 

- **Gear Icon:** Access the Preferences window to customize your experience.
- **Refresh:** Manually trigger a refresh of all system stats.
- **Quit:** Safely close the application.

## Development

### Requirements
- macOS 13.0+
- Xcode 14.0+ (for source modifications)
- Swift 5.7+

### Manual Build
If you wish to build from source manually without Xcode:
```bash
swiftc -sdk $(xcrun --show-sdk-path --sdk macosx) SiliconPulse/*.swift \
-o SiliconPulseApp \
-framework SwiftUI -framework Charts -framework SystemConfiguration \
-framework AppKit -framework IOKit -framework ServiceManagement
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request or open an issue for feature requests and bug reports.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
*Created by Alan Beltran Pozo. Optimized for Apple Silicon.*
