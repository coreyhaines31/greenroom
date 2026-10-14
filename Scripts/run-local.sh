#!/bin/bash
# Builds Green Room from source and opens it, without an Apple Developer account.
#
#   Scripts/run-local.sh
#
# The app is signed "to run locally" (ad-hoc). Quit any installed copy first: both share
# the same settings.
set -euo pipefail
cd "$(dirname "$0")/.."

# xcodebuild and SwiftLint need the full Xcode, not just the Command Line Tools.
case "$(xcode-select -p 2>/dev/null)" in
  *CommandLineTools*|"") export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ;;
esac
command -v xcodegen >/dev/null || { echo "Install XcodeGen first: brew install xcodegen" >&2; exit 1; }

xcodegen generate --quiet
# A separate build folder, so these builds never mix with team-signed ones.
DERIVED=build/LocalDerivedData
LOG=build/run-local.log
mkdir -p build
if ! xcodebuild -project GreenRoom.xcodeproj -scheme GreenRoom -configuration Debug \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" CODE_SIGN_STYLE=Manual \
  build > "$LOG" 2>&1; then
  grep -E "error:" "$LOG" | head -20 >&2
  echo "Build failed. Full log: $LOG" >&2
  exit 1
fi

APP="$DERIVED/Build/Products/Debug/Green Room.app"
pkill -f "Green Room.app/Contents/MacOS" 2>/dev/null || true
open "$APP"
echo "✓ Running. Look for the camera icon in your menu bar."
