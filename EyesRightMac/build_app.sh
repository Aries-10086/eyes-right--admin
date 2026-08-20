#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

APP_NAME="Eyes Right.app"
BUILD_DIR="$ROOT/.build/release"
APP_DIR="$ROOT/$APP_NAME"
BUNDLE_NAME="EyesRightMac_EyesRightMac.bundle"
DIST_DIR="$ROOT/dist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Info.plist" 2>/dev/null || echo "0.1.0")"
DMG_NAME="EyesRight-${VERSION}-arm64.dmg"

echo "▶ Building EyesRightMac (release)…"
swift build -c release

echo "▶ Assembling app bundle…"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/EyesRightMac" "$APP_DIR/Contents/MacOS/"
cp "$ROOT/Info.plist" "$APP_DIR/Contents/Info.plist"
chmod +x "$APP_DIR/Contents/MacOS/EyesRightMac"

# App icon
if [ -f "$ROOT/Sources/EyesRightMac/Resources/AppIcon.icns" ]; then
  cp "$ROOT/Sources/EyesRightMac/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# SPM resource bundle → Contents/Resources（标准 Mac App 结构）
if [ -d "$BUILD_DIR/$BUNDLE_NAME" ]; then
  cp -R "$BUILD_DIR/$BUNDLE_NAME" "$APP_DIR/Contents/Resources/"
fi

echo "▶ Ad-hoc signing…"
codesign --force --sign - "$APP_DIR/Contents/MacOS/EyesRightMac"
codesign --force --sign - "$APP_DIR"

echo "▶ Creating DMG…"
mkdir -p "$DIST_DIR"
STAGE="$DIST_DIR/dmg_stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP_DIR" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/如何打开.txt" "$STAGE/如何打开.txt" 2>/dev/null || true
# 若脚本首次运行还没有该文件，写一份兜底
if [ ! -f "$STAGE/如何打开.txt" ]; then
  cat > "$STAGE/如何打开.txt" <<'TXT'
如何打开 Eyes Right
1. 右键 App → 打开 → 再点打开
2. 或：系统设置 → 隐私与安全性 → 仍要打开
3. 仍提示损坏时，终端执行：
   xattr -cr "/Applications/Eyes Right.app"
TXT
fi

DMG_PATH="$DIST_DIR/$DMG_NAME"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "Eyes Right" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG_PATH" >/dev/null
rm -rf "$STAGE"

echo "▶ Installing to /Applications…"
rm -rf "/Applications/$APP_NAME"
cp -R "$APP_DIR" "/Applications/"

echo "▶ Creating Desktop alias…"
osascript <<'EOF'
tell application "Finder"
  set appPath to POSIX file "/Applications/Eyes Right.app" as alias
  set deskPath to path to desktop folder
  try
    delete (every item of deskPath whose name is "Eyes Right")
  end try
  make new alias file at deskPath to appPath with properties {name:"Eyes Right"}
end tell
EOF

echo ""
echo "✅ Done"
echo "   App:     $APP_DIR"
echo "   Install: /Applications/$APP_NAME"
echo "   Desktop: ~/Desktop/Eyes Right (alias)"
echo "   DMG:     $DMG_PATH"
echo ""
echo "   Open: open -a \"Eyes Right\""
