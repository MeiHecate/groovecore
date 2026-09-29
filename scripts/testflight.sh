#!/bin/bash
# Build GrooveCore for the App Store and upload it to TestFlight.
#   scripts/testflight.sh          archive + export the .ipa (signing creates the App ID if needed)
#   scripts/testflight.sh upload   upload the last exported .ipa to App Store Connect
# Needs ASC_KEY_ID and ASC_ISSUER_ID, and the key at ~/.private_keys/AuthKey_$ASC_KEY_ID.p8.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${ASC_KEY_ID:?export ASC_KEY_ID}"
: "${ASC_ISSUER_ID:?export ASC_ISSUER_ID}"
KEY="$HOME/.private_keys/AuthKey_${ASC_KEY_ID}.p8"
OUT=build/testflight

if [ "${1:-}" = "upload" ]; then
  xcrun altool --upload-app -f "$OUT"/export/GrooveCore.ipa --type ios \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  exit
fi

BUILD=$(date +%Y%m%d%H%M)
rm -rf "$OUT" && mkdir -p "$OUT"
xcodegen generate >/dev/null
AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$KEY"
      -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
xcodebuild archive -project GrooveCore.xcodeproj -scheme GrooveCore -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$OUT"/GrooveCore.xcarchive \
  CURRENT_PROJECT_VERSION="$BUILD" "${AUTH[@]}" -quiet
cat > "$OUT"/ExportOptions.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>signingStyle</key><string>automatic</string>
  <key>teamID</key><string>85228RBZF6</string>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath "$OUT"/GrooveCore.xcarchive \
  -exportPath "$OUT"/export -exportOptionsPlist "$OUT"/ExportOptions.plist "${AUTH[@]}" -quiet
echo "Build $BUILD prêt : $OUT/export/GrooveCore.ipa"
