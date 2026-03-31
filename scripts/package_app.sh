#!/bin/zsh
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
APP_NAME="OCI Object Storage Explorer"
BUNDLE_ID="com.paulosartori.oci-object-storage-explorer"
EXECUTABLE_NAME="OCIObjectStorageExplorer"
APP_ICON_NAME="AppIcon"
RELEASE_DIR="$ROOT_DIR/.build/arm64-apple-macosx/release"
RESOURCE_BUNDLE_NAME="OCIObjectStorageExplorer_OCIExplorerApp.bundle"
RESOURCE_BUNDLE_PATH="$RELEASE_DIR/$RESOURCE_BUNDLE_NAME"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_SOURCE_DIR="$ROOT_DIR/Sources/OCIExplorerApp/Resources/Assets.xcassets/AppIcon.appiconset"
TMP_DIR="$ROOT_DIR/.tmp/package"
ICONSET_DIR="$TMP_DIR/$APP_ICON_NAME.iconset"
ICON_FILE="$RESOURCES_DIR/$APP_ICON_NAME.icns"
BUILD_VERSION="$(date +%Y%m%d%H%M%S)"

cd "$ROOT_DIR"
swift build -c release

mkdir -p "$TMP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

cp "$RELEASE_DIR/$EXECUTABLE_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

if [[ -d "$RESOURCE_BUNDLE_PATH" ]]; then
  cp -R "$RESOURCE_BUNDLE_PATH" "$RESOURCES_DIR/"
fi

copy_icon() {
  local source_name="$1"
  local target_name="$2"
  cp "$ICON_SOURCE_DIR/$source_name" "$ICONSET_DIR/$target_name"
}

if [[ -d "$ICON_SOURCE_DIR" ]]; then
  copy_icon "16.png" "icon_16x16.png"
  copy_icon "32.png" "icon_16x16@2x.png"
  copy_icon "32.png" "icon_32x32.png"
  copy_icon "64.png" "icon_32x32@2x.png"
  copy_icon "128.png" "icon_128x128.png"
  copy_icon "256.png" "icon_128x128@2x.png"
  copy_icon "256.png" "icon_256x256.png"
  copy_icon "512.png" "icon_256x256@2x.png"
  copy_icon "512.png" "icon_512x512.png"
  copy_icon "1024.png" "icon_512x512@2x.png"
  iconutil --convert icns --output "$ICON_FILE" "$ICONSET_DIR"
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIconFile</key>
  <string>$APP_ICON_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_VERSION</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.developer-tools</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

/usr/bin/codesign --force --deep --sign - "$APP_DIR"

echo "$APP_DIR"
