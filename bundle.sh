#!/bin/bash
set -e

APP_NAME="Mira"
VERSION="0.2.19"
BUNDLE_ID="com.snupai.mira"

cd "$(dirname "$0")"

# Build
swift build -c release

# Create .app structure
rm -rf "${APP_NAME}.app"
mkdir -p "${APP_NAME}.app/Contents/MacOS"
mkdir -p "${APP_NAME}.app/Contents/Resources"
mkdir -p "${APP_NAME}.app/Contents/Frameworks"

# Copy binary
cp ".build/release/Mira" "${APP_NAME}.app/Contents/MacOS/${APP_NAME}"

# Copy resources bundle if exists
if [ -d ".build/release/Mira_Mira.bundle" ]; then
    cp -R ".build/release/Mira_Mira.bundle" "${APP_NAME}.app/Contents/Resources/"
fi

# Copy app icon if exists
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${APP_NAME}.app/Contents/Resources/"
fi

# Copy Sparkle.framework (check multiple possible locations)
SPARKLE_FRAMEWORK=""
if [ -d ".build/release/Sparkle.framework" ]; then
    SPARKLE_FRAMEWORK=".build/release/Sparkle.framework"
elif [ -d ".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework" ]; then
    SPARKLE_FRAMEWORK=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
elif [ -d ".build/arm64-apple-macosx/release/Sparkle.framework" ]; then
    SPARKLE_FRAMEWORK=".build/arm64-apple-macosx/release/Sparkle.framework"
fi

if [ -n "$SPARKLE_FRAMEWORK" ]; then
    echo "📦 Bundling Sparkle.framework from $SPARKLE_FRAMEWORK"
    cp -R "$SPARKLE_FRAMEWORK" "${APP_NAME}.app/Contents/Frameworks/"
    
    # Update the framework's rpath in the binary
    install_name_tool -add_rpath "@executable_path/../Frameworks" "${APP_NAME}.app/Contents/MacOS/${APP_NAME}" 2>/dev/null || true
    
    # Strip ALL existing signatures from Sparkle framework (including nested)
    echo "🔓 Stripping Sparkle signatures..."
    find "${APP_NAME}.app/Contents/Frameworks/Sparkle.framework" -type f \( -perm +111 -o -name "*.dylib" \) 2>/dev/null | while read binary; do
        codesign --remove-signature "$binary" 2>/dev/null || true
    done
else
    echo "⚠️ Warning: Sparkle.framework not found. Auto-updates will not work."
fi

# Ad-hoc sign the entire app bundle (ensures consistent signatures)
echo "🔐 Signing app bundle..."
codesign --force --deep --sign - "${APP_NAME}.app"

# Sparkle feed URL (hosted on GitHub)
SPARKLE_FEED_URL="https://raw.githubusercontent.com/Snupai/Mira-SwiftUI/main/appcast.xml"

# EdDSA public key for Sparkle update verification
SPARKLE_PUBLIC_KEY="lAu3sHrnhreoAC+WIbYbY39XUqmfjvytjJbBWpaTb/k="

# Create Info.plist with Sparkle configuration
cat > "${APP_NAME}.app/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    
    <!-- Sparkle Auto-Update Configuration -->
    <key>SUFeedURL</key>
    <string>${SPARKLE_FEED_URL}</string>
    <key>SUPublicEDKey</key>
    <string>${SPARKLE_PUBLIC_KEY}</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUAllowsAutomaticUpdates</key>
    <true/>
</dict>
</plist>
EOF

echo "✅ Created ${APP_NAME}.app (v${VERSION}) with Sparkle support"
