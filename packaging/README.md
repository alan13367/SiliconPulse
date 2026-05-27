# Packaging SiliconPulse

SiliconPulse ships best as a small `.dmg` containing `SiliconPulse.app` and an Applications shortcut. The app is a normal macOS GUI cask for Homebrew, not a formula.

## Create a GitHub Release Artifact

1. Bump `CFBundleShortVersionString`, `CFBundleVersion`, `MARKETING_VERSION`, and `CURRENT_PROJECT_VERSION`.
2. Run:

   ```bash
   ./script/build_and_run.sh --verify
   ./script/package_release.sh
   ```

3. Confirm the generated checksum:

   ```bash
   cat dist/SiliconPulse-<version>.dmg.sha256
   ```

4. Create or update the GitHub release:

   ```bash
   gh release create v<version> dist/SiliconPulse-<version>.dmg dist/SiliconPulse-<version>.dmg.sha256 \
     --title "SiliconPulse v<version>" \
     --notes-file RELEASE_NOTES.md
   ```

## Signing and Notarization

Public releases should be signed with a Developer ID Application certificate, use hardened runtime, and be notarized. A local Apple Development signature is fine for personal testing, but it is not enough for a frictionless GitHub or Homebrew install.

Before submitting to the official Homebrew cask repository, verify:

```bash
codesign --verify --deep --strict --verbose=2 /Applications/SiliconPulse.app
spctl -a -vv -t exec /Applications/SiliconPulse.app
```

## Homebrew

The personal tap lives at `alan13367/homebrew-tap`. Users can install with:

```bash
brew tap alan13367/tap
brew install --cask siliconpulse
```

For the official Homebrew cask repository, submit a PR to `Homebrew/homebrew-cask` once the app has a stable, public, signed, and Gatekeeper-friendly release artifact. A personal tap is the better first step while the project builds public usage and notability.
