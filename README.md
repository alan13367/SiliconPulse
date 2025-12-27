# SiliconPulse

SiliconPulse is a sleek, real-time CPU monitoring application for macOS that lives right in your menu bar. Built with SwiftUI and Swift Charts, it provides a lightweight and visually appealing way to keep tabs on your system's performance.

![SiliconPulse Mockup](file:///Users/alan/.gemini/antigravity/brain/50f40305-c385-45e9-88a5-3a6f02950cc5/silicon_pulse_mockup_1766859971797.png)

## Features

- **Menu Bar Integration**: Real-time CPU percentage display directly in the macOS menu bar.
- **Visual Dashboard**: A beautiful, interactive popover dashboard with a live CPU usage chart.
- **Real-time Monitoring**: High-frequency updates using native Mach APIs for accurate CPU load calculation.
- **Minimalist Design**: Clean, glassmorphism-inspired UI that fits perfectly with the macOS aesthetic.

## Technical Details

- **Language**: Swift
- **Framework**: SwiftUI
- **Visuals**: Swift Charts
- **System API**: `host_statistics` (Mach API) for low-level CPU metrics.
- **Architecture**: ObservableObject-based state management for real-time reactivity.

## Getting Started

### Prerequisites

- macOS (12.0+)
- Xcode (latest recommended)

### Build & Run

1. Clone the repository.
2. Open `SiliconPulse.xcodeproj` in Xcode.
3. Select your target (SiliconPulse) and destination (My Mac).
4. Press `Cmd + R` to build and run.

The application will appear in your menu bar as "CPU %". Click it to view the full dashboard.

## Usage

- **View Live Chart**: Click the menu bar icon to open the dashboard and see the last 30 seconds of CPU activity.
- **Quit**: Use the "Quit" button in the dashboard or press `Cmd + Q` while the dashboard is open.

---

*Designed for high performance and visual excellence.*
