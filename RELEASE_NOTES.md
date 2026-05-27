# SiliconPulse Release Notes

## v1.0.1

SiliconPulse is focused on being a minimal, useful macOS menu bar monitor: quick to read, quiet in daily use, and deep enough when you need to inspect what is happening.

### Highlights

- Refined dashboard graphs with compact trend panels, peak labels, and clearer CPU, GPU, memory, and network history.
- First-run onboarding for choosing launch behavior and key display preferences.
- Settings window now reliably opens in front of other windows from the menu bar popup.
- Storage reporting now uses macOS-style file capacity units and includes important-use available capacity, matching System Settings more closely.
- Process detail gauges now match the refreshed dashboard gauge style.

### Install Note

This release is not notarized because SiliconPulse is distributed without a paid Apple Developer account. If macOS blocks the app after installation, right-click `SiliconPulse.app` and choose **Open**. If macOS says the app is damaged, run:

```bash
xattr -cr /Applications/SiliconPulse.app
```
