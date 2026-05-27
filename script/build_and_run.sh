#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="SiliconPulse"
BUNDLE_ID="com.alan13367.SiliconPulse"
PROJECT="SiliconPulse.xcodeproj"
SCHEME="SiliconPulse"
CONFIGURATION="Debug"
DESTINATION="platform=macOS,arch=arm64"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "$DESTINATION" \
  build

APP_BUNDLE="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/Build/Products/$CONFIGURATION/$APP_NAME.app" -type d | grep -v "Index.noindex" | head -n 1)"

if [[ -z "$APP_BUNDLE" ]]; then
  echo "error: could not locate built $APP_NAME.app in DerivedData" >&2
  exit 1
fi

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
