#!/bin/bash
set -e

APP_NAME="Mira"
VERSION="0.2.21"
DMG_NAME="${APP_NAME}-${VERSION}"
DMG_TEMP="dmg-temp"
DMG_FINAL="${DMG_NAME}.dmg"
DMG_RW="${DMG_NAME}-rw.dmg"

# Window dimensions and icon positions
WINDOW_WIDTH=660
WINDOW_HEIGHT=400
ICON_SIZE=128
APP_X=480      # App icon on the right
APP_Y=170
APPS_X=180     # Applications folder on the left
APPS_Y=170

cd "$(dirname "$0")"

echo "💿 Creating DMG..."

# Clean up old artifacts
rm -rf "${DMG_TEMP}" "${DMG_FINAL}" "${DMG_RW}"

# Create temp directory for DMG contents
mkdir -p "${DMG_TEMP}/.background"

# Copy app and create Applications symlink
cp -R "${APP_NAME}.app" "${DMG_TEMP}/"
ln -s /Applications "${DMG_TEMP}/Applications"

# Copy pre-made background
if [ -f "dmg-background/background.png" ]; then
    cp dmg-background/background.png "${DMG_TEMP}/.background/background.png"
    echo "🎨 Using custom background"
fi

# Calculate DMG size (app size + 15MB buffer)
DMG_SIZE=$(du -sm "${DMG_TEMP}" | cut -f1)
DMG_SIZE=$((DMG_SIZE + 15))

# Create a writable DMG
hdiutil create -volname "${APP_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -size ${DMG_SIZE}m \
    -srcfolder "${DMG_TEMP}" \
    "${DMG_RW}"

# Mount the writable DMG
echo "🔧 Configuring DMG appearance..."
MOUNT_DIR=$(hdiutil attach -readwrite -noverify "${DMG_RW}" | grep "/Volumes/${APP_NAME}" | cut -f3)

if [ -n "$MOUNT_DIR" ]; then
    # Use AppleScript to configure the DMG window
    osascript << APPLESCRIPT
tell application "Finder"
    tell disk "${APP_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, $((100 + WINDOW_WIDTH)), $((100 + WINDOW_HEIGHT))}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to ${ICON_SIZE}
        set text size of viewOptions to 13
        try
            set background picture of viewOptions to file ".background:background.png"
        on error
            -- Background not found, use default
        end try
        set position of item "${APP_NAME}.app" of container window to {${APP_X}, ${APP_Y}}
        set position of item "Applications" of container window to {${APPS_X}, ${APPS_Y}}
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT
    
    # Sync and unmount
    sync
    hdiutil detach "$MOUNT_DIR" -quiet || hdiutil detach "$MOUNT_DIR" -force
fi

# Convert to compressed DMG
hdiutil convert "${DMG_RW}" -format UDZO -imagekey zlib-level=9 -o "${DMG_FINAL}"

# Clean up
rm -rf "${DMG_TEMP}" "${DMG_RW}"

echo "✅ Created ${DMG_FINAL}"
ls -lh "${DMG_FINAL}"
