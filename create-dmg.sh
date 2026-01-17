#!/bin/bash
set -e

APP_NAME="Mira"
VERSION="0.2.16"
DMG_NAME="${APP_NAME}-${VERSION}"

cd "$(dirname "$0")"

echo "🔨 Building release..."
swift build -c release

echo "📦 Creating app bundle..."
./bundle.sh

echo "💿 Creating DMG..."

# Clean up old artifacts
rm -rf dmg-temp "${DMG_NAME}.dmg"

# Create temp directory for DMG contents
mkdir -p dmg-temp
cp -R "${APP_NAME}.app" dmg-temp/

# Create Applications symlink
ln -s /Applications dmg-temp/Applications

# Create DMG
hdiutil create -volname "${APP_NAME}" \
    -srcfolder dmg-temp \
    -ov -format UDZO \
    "${DMG_NAME}.dmg"

# Clean up
rm -rf dmg-temp

echo "✅ Created ${DMG_NAME}.dmg"
ls -lh "${DMG_NAME}.dmg"
