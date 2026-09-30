#!/bin/bash
# Renders the 1024 px app icon with headless Chrome: identical sets well under a dashed max line,
# the grease-the-groove rule of never training to failure.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=App/Resources/Assets.xcassets/AppIcon.appiconset
TMP=$(mktemp -d)
cat > "$TMP/icon.html" <<'HTML'
<html><body style="margin:0;background:#141516">
<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs><radialGradient id="g" cx="50%" cy="42%" r="70%"><stop offset="0" stop-color="#1E1F21"/><stop offset="1" stop-color="#141516"/></radialGradient></defs>
  <rect width="1024" height="1024" fill="url(#g)"/>
  <!-- the max, never reached -->
  <line x1="233" y1="268" x2="791" y2="268" stroke="#6F6D69" stroke-width="24" stroke-dasharray="40 34" stroke-linecap="round"/>
  <!-- identical submaximal sets, the current one in groseille -->
  <g fill="#EDEAE3">
    <rect x="230" y="507" width="68" height="293" rx="34"/><rect x="354" y="507" width="68" height="293" rx="34"/>
    <rect x="478" y="507" width="68" height="293" rx="34"/><rect x="602" y="507" width="68" height="293" rx="34"/>
  </g>
  <rect x="726" y="507" width="68" height="293" rx="34" fill="#FF4D6D"/>
</svg></body></html>
HTML
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu --hide-scrollbars \
  --window-size=1024,1024 --screenshot="$OUT/icon-1024.png" "file://$TMP/icon.html" >/dev/null 2>&1
sips -g pixelWidth -g pixelHeight "$OUT/icon-1024.png"
