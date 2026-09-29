#!/bin/bash
# Renders the 1024 px app icon (tally of five, groseille diagonal) with headless Chrome.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=App/Resources/Assets.xcassets/AppIcon.appiconset
TMP=$(mktemp -d)
cat > "$TMP/icon.html" <<'HTML'
<html><body style="margin:0;background:#141516">
<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <rect width="1024" height="1024" fill="#141516"/>
  <g stroke="#EDEAE3" stroke-width="64" stroke-linecap="round" fill="none">
    <path d="M322 262 L306 762"/><path d="M458 262 L450 762"/>
    <path d="M594 262 L602 762"/><path d="M730 262 L738 762"/>
  </g>
  <path d="M240 666 L820 400" stroke="#FF4D6D" stroke-width="64" stroke-linecap="round" fill="none"/>
</svg></body></html>
HTML
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu --hide-scrollbars \
  --window-size=1024,1024 --screenshot="$OUT/icon-1024.png" "file://$TMP/icon.html" >/dev/null 2>&1
sips -g pixelWidth -g pixelHeight "$OUT/icon-1024.png"
