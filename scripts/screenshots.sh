#!/bin/bash
# Usage: scripts/screenshots.sh <out-dir>. Builds, installs with demo data, captures 4 tabs in fr and en.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=${1:?out dir}
mkdir -p "$OUT"
DEVICE="iPhone 17"
BUNDLE=com.maelrochard.groovecore
xcodegen generate >/dev/null
xcodebuild -project GrooveCore.xcodeproj -scheme GrooveCore -destination "platform=iOS Simulator,name=$DEVICE,OS=26.5" \
  -derivedDataPath build build -quiet
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl uninstall booted $BUNDLE 2>/dev/null || true
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/GrooveCore.app
xcrun simctl status_bar booted override --time 14:28 --batteryLevel 100 --cellularBars 4
for lang in fr en; do
  locale=$([ "$lang" = fr ] && echo fr_FR || echo en_US)
  for tab in 0 1 2 3; do
    xcrun simctl terminate booted $BUNDLE 2>/dev/null || true
    xcrun simctl launch booted $BUNDLE -demo -tab $tab -AppleLanguages "($lang)" -AppleLocale $locale >/dev/null
    sleep 3
    xcrun simctl io booted screenshot "$OUT/$lang-tab$tab.png" >/dev/null
  done
done
ls "$OUT"
