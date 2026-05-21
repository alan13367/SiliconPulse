# SiliconPulse — Agent Instructions

## Project Overview

SiliconPulse is a native macOS menu bar utility for real-time system monitoring. It tracks CPU, GPU, memory, network, thermal state, battery, disk usage, and fan speeds. It includes a dedicated Top Processes window with sort, search, and kill functionality.

- **Language**: Swift
- **Framework**: SwiftUI (macOS 14+), IOKit, SystemConfiguration
- **Target**: macOS 14.0+ (arm64 / Apple Silicon optimized)
- **Build System**: Xcode project (`SiliconPulse.xcodeproj`)

## Architecture

```
SiliconPulse/
├── SiliconPulse/
│   ├── App/
│   │   └── SiliconPulseApp.swift          # @main, scenes, MenuBarExtra, Window, Settings
│   ├── Models/
│   │   └── Models.swift                   # CoreUsage, ProcessInfo, MemoryDetails, NetworkSpeed, SystemInfo, VolumeInfo, BatteryInfo
│   ├── Services/
│   │   ├── SystemMonitor.swift            # CPU, Memory, Temperature, System Info
│   │   ├── GPUMonitor.swift               # IOAccelerator + IOReport GPU metrics
│   │   ├── NetworkMonitor.swift           # Network speed, counter rollover handling, VPN detection
│   │   ├── ThermalMonitor.swift           # Thermal pressure via notify(3)
│   │   ├── ProcessMonitor.swift           # Top processes with corrected CPU % calculation
│   │   ├── BatteryMonitor.swift           # Battery charge, cycles, health
│   │   ├── DiskMonitor.swift              # Mounted volume usage
│   │   ├── FanController.swift            # SMC fan reading + manual/automatic/max/off control
│   │   └── SettingsManager.swift          # UserDefaults-backed preferences
│   ├── Views/
│   │   ├── MenuBarView.swift              # Main popup dashboard
│   │   ├── ProcessWindowView.swift        # Dedicated Top Processes window
│   │   ├── SettingsView.swift             # Tabbed preferences
│   │   └── Components/
│   │       └── DashboardComponents.swift    # DashboardCard, SparklineChart, MetricValue, TemperatureBadge
│   ├── Support/
│   │   └── Formatters.swift               # Bytes, temperature, speed, percentage, uptime formatting
│   ├── Assets.xcassets/
│   └── Info.plist
└── SiliconPulse.xcodeproj/
```

## Build Instructions

### Requirements
- macOS 14.0+ (deployment target)
- Xcode 15.0+ with macOS SDK
- Apple Silicon Mac (Intel support is present but some Apple-Silicon-specific paths exist)

### Build from Terminal

```bash
xcodebuild -project SiliconPulse.xcodeproj -scheme SiliconPulse -configuration Debug build
```

### Find and Launch Built App

```bash
# The built .app is in Xcode's DerivedData
APP_PATH="$(find ~/Library/Developer/Xcode/DerivedData -name "SiliconPulse.app" -type d | grep -v "Index.noindex" | head -n 1)"
/usr/bin/open -n "$APP_PATH"
```

### Build and Launch (One Command)

```bash
xcodebuild -project SiliconPulse.xcodeproj -scheme SiliconPulse -configuration Debug build && \
  APP_PATH="$(find ~/Library/Developer/Xcode/DerivedData -name "SiliconPulse.app" -type d | grep -v "Index.noindex" | head -n 1)" && \
  /usr/bin/open -n "$APP_PATH"
```

### Debug / Logs

```bash
# Stream app logs
/usr/bin/log stream --info --style compact --predicate 'process == "SiliconPulse"'

# Launch under LLDB
lldb -- "$APP_PATH/Contents/MacOS/SiliconPulse"
```

## Key Technical Details

### Private API Usage
The app uses several private/undocumented APIs for hardware access. These are gated with `_silgen_name` in Swift:

- **proc_***: `proc_listpids`, `proc_name`, `proc_pidinfo` (from `libproc.h`) — process enumeration
- **IOHIDEventSystemClient***: Thermal sensor reading via IOKit HID event system
- **notify_register_check / notify_get_state**: Thermal pressure state changes
- **IOReport** (via `dlopen`): GPU metrics on Apple Silicon (best-effort fallback)
- **AppleSMC** (via IOKit): Fan control and SMC temperature sensors

These APIs may change between macOS versions. The app gracefully degrades when APIs fail.

### Data Reliability Improvements
- **CPU %**: Calculated as process delta vs total host CPU ticks, clamped 0–100%
- **Network counters**: 32-bit rollover handled explicitly; 3-sample EMA smoothing
- **Temperature**: Multi-source fallback (IOHID → SMC → "N/A")
- **GPU**: IOAccelerator with IOReport fallback; hides section if unavailable

### State Management
- Uses Swift 5.9+ `@Observable` (not `@ObservableObject`)
- Monitors are singletons accessed via `.shared`
- Passed via `.environment()` into view hierarchy
- Settings that need bindings use `@State var settings = SettingsManager.shared`

### Menu Bar Extra + Main Window
- The app is a `MenuBarExtra` with `.menuBarExtraStyle(.window)`
- Also declares a `Window("Top Processes", id: "processes")` scene
- `LSUIElement` is set to `true` in Info.plist (no Dock icon)

## Common Tasks for Agents

### Add a New Monitor
1. Create `Services/<MonitorName>.swift` with `@Observable final class <MonitorName>`
2. Add `static let shared = <MonitorName>()` singleton
3. Inject into `SiliconPulseApp.swift` via `@State private var ...`
4. Pass to views via `.environment(...)`
5. Add toggle in `SettingsManager` and `SettingsView`

### Add a New Dashboard Section
1. Add a `DashboardCard` in `MenuBarView.swift` with the appropriate section
2. Use `SparklineChart` for history data
3. Use `MetricValue` for large numbers
4. Use `ProgressView` for 0–100% metrics
5. Gate behind a `settings.show*Info` toggle

### Modify the Top Processes Window
- Process data lives in `ProcessMonitor.swift`
- UI is in `ProcessWindowView.swift` (NavigationSplitView pattern)
- Sorting logic is in the `filteredProcesses` computed property
- Kill sends `SIGTERM` first, falls back to `SIGKILL`

### Update App Icon / Assets
- App icons live in `SiliconPulse/Assets.xcassets/AppIcon.appiconset/`
- Current sizes have warnings (icons are 2x expected resolution); regenerate correct sizes if updating

## Testing Checklist After Changes

- [ ] Build succeeds: `xcodebuild -project SiliconPulse.xcodeproj -scheme SiliconPulse -configuration Debug build`
- [ ] App launches without crashing
- [ ] Menu bar icon shows CPU and memory percentages
- [ ] Menu bar popup shows all enabled sections
- [ ] Top Processes window opens and populates
- [ ] Settings window opens and saves preferences
- [ ] Process kill dialog appears and works (test with a safe user process)
- [ ] Fan controls appear and mode buttons are responsive (if fans detected)

## Known Issues / Limitations

1. **App icon**: Master art lives in `AppIcon.appiconset/` (generated from 1024×1024 source). Re-export all slots if replacing the icon.
2. **IOReport GPU**: The `IOReport` private framework cannot be used with Swift closures capturing context. The GPU monitor falls back to `IOAccelerator` which may report 0 on some Apple Silicon chips.
3. **SMC Fan Control**: Apple Silicon Macs (M1+) do not expose traditional SMC fan keys. Fan control may only work on Intel Macs. The UI gracefully shows "No fans detected" when SMC keys are unavailable.
4. **Info.plist in Copy Bundle Resources**: Xcode warns that `Info.plist` is in the Copy Bundle Resources build phase. This is an Xcode 16 folder-synchronization quirk and does not affect functionality.

## Code Style

- Prefer `@Observable` over `@ObservableObject` for new monitors
- Use `Formatters.*` for all user-facing numbers (bytes, temperature, speed, percentage, uptime)
- Use semantic colors (`Color.accentColor`, `.green`, `.orange`, `.red`) — no neon colors
- Keep views small; extract reusable components into `Views/Components/`
- Keep services focused; one monitor per file

## Entitlements / Permissions

The app uses `LSUIElement` (menu-bar-only, no Dock icon). It does not currently require code signing entitlements for basic functionality, but process kill functionality requires the app to run with sufficient privileges (same as the user). No `com.apple.security.cs.allow-jit` or special entitlements are needed.
