#!/bin/bash
# Builds, signs, notarizes, and publishes a release.
#
#   Scripts/release.sh 1.0.0
#
# Needs, one time:
#   - Developer ID signing: either Xcode signed in to the team (cloud signing), or
#     ASC_KEY_PATH + ASC_KEY_ID + ASC_ISSUER_ID for an App Store Connect API key (CI)
#   - notarytool credentials: either `xcrun notarytool store-credentials midnightoil-notary`
#     (the same Apple ID profile Midnight Oil uses)
#     or APPLE_ID + APPLE_APP_PASSWORD (+ TEAM_ID) in the environment (CI)
#   - the Sparkle EdDSA private key in the keychain, or SPARKLE_KEY_FILE pointing at it (CI)
#   - gh authenticated with push access to coreyhaines31/greenroom and coreyhaines31/homebrew-tap
#   - Node 20+ and npm, to pack the Claude Desktop extension in mcpb/
set -euo pipefail

VERSION="${1:?usage: Scripts/release.sh <version>}"
TEAM_ID="${TEAM_ID:-KPQU8X839X}"
NOTARY_PROFILE="${NOTARY_PROFILE:-midnightoil-notary}"
REPO="coreyhaines31/greenroom"
APP_NAME="Green Room"

cd "$(dirname "$0")/.."
[ "$(git branch --show-current)" = main ] || { echo "Release from main." >&2; exit 1; }
# Needs the full Xcode, even if the shell points DEVELOPER_DIR at the Command Line Tools.
case "${DEVELOPER_DIR:-}" in
  ""|*CommandLineTools*) export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ;;
esac
BUILD=build/release
[ -d "$BUILD" ] && rm -r "$BUILD"
mkdir -p "$BUILD"
BUILD_NUMBER=$(git rev-list --count HEAD)

quiet() { grep -E "error:|warning: |\*\* " || true; }

if [ -n "${APPLE_ID:-}" ]; then
  NOTARY_ARGS=(--apple-id "$APPLE_ID" --team-id "$TEAM_ID" --password "$APPLE_APP_PASSWORD")
else
  NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
fi
# macOS ships bash 3.2, where expanding an empty array trips `set -u`; hence the ${arr[@]+...} form below.
SPARKLE_KEY_ARGS=()
[ -n "${SPARKLE_KEY_FILE:-}" ] && SPARKLE_KEY_ARGS=(--ed-key-file "$SPARKLE_KEY_FILE")
# Cloud-managed Developer ID signing needs an account: Xcode's signed-in one, or an API key.
AUTH_ARGS=(-allowProvisioningUpdates)
if [ -n "${ASC_KEY_PATH:-}" ]; then
  AUTH_ARGS+=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi

echo "▶ Generating project"
xcodegen generate -q

echo "▶ Archiving $APP_NAME $VERSION ($BUILD_NUMBER)"
xcodebuild -project GreenRoom.xcodeproj -scheme GreenRoom -configuration Release \
  -archivePath "$BUILD/GreenRoom.xcarchive" \
  "${AUTH_ARGS[@]}" \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  archive | quiet

echo "▶ Exporting with Developer ID"
cat > "$BUILD/export.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath "$BUILD/GreenRoom.xcarchive" \
  -exportOptionsPlist "$BUILD/export.plist" -exportPath "$BUILD/export" \
  "${AUTH_ARGS[@]}" | quiet
APP="$BUILD/export/$APP_NAME.app"
codesign --verify --deep --strict --verbose=1 "$APP"

echo "▶ Notarizing the app"
ditto -c -k --keepParent "$APP" "$BUILD/app.zip"
xcrun notarytool submit "$BUILD/app.zip" "${NOTARY_ARGS[@]}" --wait
xcrun stapler staple "$APP"

echo "▶ Building the DMG"
DMG="$BUILD/GreenRoom-$VERSION.dmg"
STAGE="$BUILD/dmg"
mkdir -p "$STAGE" && cp -R "$APP" "$STAGE/" && ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO -quiet "$DMG"
# The DMG is signed when a local Developer ID identity exists; with cloud-managed
# signing there is none, and notarization accepts an unsigned DMG of a signed app.
if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  codesign --sign "Developer ID Application" --timestamp "$DMG"
fi
xcrun notarytool submit "$DMG" "${NOTARY_ARGS[@]}" --wait
xcrun stapler staple "$DMG"
# Gatekeeper judges the app inside the image, so that's what we assess.
MOUNT=$(mktemp -d)
hdiutil attach -nobrowse -quiet "$DMG" -mountpoint "$MOUNT"
spctl --assess --type exec -v "$MOUNT/$APP_NAME.app"
hdiutil detach -quiet "$MOUNT"

echo "▶ Signing the update and writing the appcast"
# On a fresh checkout the folder doesn't exist yet, and with pipefail a failing find would end the script.
SPARKLE_BIN=$(find build/DerivedData/SourcePackages/artifacts -type d -path "*Sparkle/bin" 2>/dev/null | head -1 || true)
if [ -z "$SPARKLE_BIN" ]; then
  xcodebuild -project GreenRoom.xcodeproj -scheme GreenRoom -derivedDataPath build/DerivedData \
    -resolvePackageDependencies -quiet
  SPARKLE_BIN=$(find build/DerivedData/SourcePackages/artifacts -type d -path "*Sparkle/bin" 2>/dev/null | head -1 || true)
fi
mkdir -p "$BUILD/appcast" && cp "$DMG" "$BUILD/appcast/"
"$SPARKLE_BIN/generate_appcast" ${SPARKLE_KEY_ARGS[@]+"${SPARKLE_KEY_ARGS[@]}"} \
  --download-url-prefix "https://github.com/$REPO/releases/download/v$VERSION/" \
  --link "https://greenroomformac.com" \
  "$BUILD/appcast"

echo "▶ Publishing GitHub release v$VERSION"
# A copy without the version in its name, so releases/latest/download/GreenRoom.dmg always works
# for install scripts and AI agents.
cp "$DMG" "$BUILD/GreenRoom.dmg"
(cd mcpb && npm ci --silent && npm run --silent pack >/dev/null)
MCPB=mcpb/dist/greenroom.mcpb
# Every release carries greenroom.mcpb so releases/latest/download/greenroom.mcpb keeps working.
gh release create "v$VERSION" "$DMG" "$BUILD/GreenRoom.dmg" "$BUILD/appcast/appcast.xml" "$MCPB" \
  --repo "$REPO" --target main --title "$APP_NAME $VERSION" --generate-notes

echo "▶ Updating the Homebrew cask"
TAP="$BUILD/homebrew-tap"
gh repo clone coreyhaines31/homebrew-tap "$TAP" -- --quiet --depth 1
SHA=$(shasum -a 256 "$DMG" | cut -d' ' -f1)
CASK="$TAP/Casks/greenroom.rb"
# The first release adds the cask from Scripts/homebrew.
[ -f "$CASK" ] || cp Scripts/homebrew/greenroom.rb "$CASK"
sed -i '' -e "s/^  version \".*\"/  version \"$VERSION\"/" -e "s/^  sha256 \".*\"/  sha256 \"$SHA\"/" "$CASK"
git -C "$TAP" add Casks/greenroom.rb
git -C "$TAP" commit -qm "greenroom $VERSION" && git -C "$TAP" push -q
echo "✓ Released $APP_NAME $VERSION"
