#!/bin/bash
set -e

APP_NAME="Mira"
VERSION="0.2.39"
BUNDLE_ID="com.snupai.mira"

cd "$(dirname "$0")"

# Build (use Xcode toolchain for SwiftData macros)
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
echo "🔨 Building with DEVELOPER_DIR=$DEVELOPER_DIR"
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
if [ -f "Sources/Mira/Resources/AppIcon.icns" ]; then
    cp "Sources/Mira/Resources/AppIcon.icns" "${APP_NAME}.app/Contents/Resources/"
elif [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${APP_NAME}.app/Contents/Resources/"
fi

# Sparkle feed URL (hosted on GitHub)
SPARKLE_FEED_URL="https://raw.githubusercontent.com/Snupai/Mira-SwiftUI/main/appcast.xml"

# EdDSA public key for Sparkle update verification
SPARKLE_PUBLIC_KEY="lAu3sHrnhreoAC+WIbYbY39XUqmfjvytjJbBWpaTb/k="

# Create Info.plist BEFORE signing (must be bound to code signature)
echo "📝 Creating Info.plist..."
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
    <!-- Required for sandboxed apps to use Sparkle's installer XPC service -->
    <key>SUEnableInstallerLauncherService</key>
    <true/>

    <!-- iCloud / CloudKit Configuration -->
    <key>NSUbiquitousContainers</key>
    <dict>
        <key>iCloud.com.snupai.Mira</key>
        <dict>
            <key>NSUbiquitousContainerIsDocumentScopePublic</key>
            <false/>
            <key>NSUbiquitousContainerName</key>
            <string>Mira</string>
            <key>NSUbiquitousContainerSupportedFolderLevels</key>
            <string>None</string>
        </dict>
    </dict>
</dict>
</plist>
EOF

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

# Optional provisioning profile for iCloud (exported from Xcode)
# Place it as: ./Mira.mobileprovision
if [ -f "Mira.mobileprovision" ]; then
    echo "📦 Embedding provisioning profile"
    cp "Mira.mobileprovision" "${APP_NAME}.app/Contents/embedded.provisionprofile"
fi

# Code signing (MUST happen AFTER Info.plist is created)
# Set SIGNING_IDENTITY to your certificate name, or leave empty for ad-hoc
# Example: export SIGNING_IDENTITY="Apple Development: your@email.com (TEAMID)"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"

# Match the push environment to the profile embedded in this build. A development
# certificate/profile cannot authorize the production entitlement in the release
# entitlements file, even though codesign's on-disk verification succeeds.
SIGNING_ENTITLEMENTS="Mira.entitlements"
if [ -f "Mira.entitlements" ] && [ -f "Mira.mobileprovision" ]; then
    PROFILE_PLIST=$(mktemp -t mira-profile)
    BUILD_ENTITLEMENTS=$(mktemp -t mira-entitlements)
    trap 'rm -f "$PROFILE_PLIST" "$BUILD_ENTITLEMENTS"' EXIT
    security cms -D -i "Mira.mobileprovision" > "$PROFILE_PLIST"
    cp "Mira.entitlements" "$BUILD_ENTITLEMENTS"
    if /usr/libexec/PlistBuddy -c 'Print :com.apple.developer.aps-environment' "$BUILD_ENTITLEMENTS" >/dev/null 2>&1; then
        PUSH_ENVIRONMENT=$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.developer.aps-environment' "$PROFILE_PLIST")
        case "$PUSH_ENVIRONMENT" in
            development|production) ;;
            *) echo "Invalid push environment in Mira.mobileprovision" >&2; exit 1 ;;
        esac
        /usr/libexec/PlistBuddy -c "Set :com.apple.developer.aps-environment $PUSH_ENVIRONMENT" "$BUILD_ENTITLEMENTS"
        echo "   Using provisioning profile push environment: $PUSH_ENVIRONMENT"
    fi
    SIGNING_ENTITLEMENTS="$BUILD_ENTITLEMENTS"
fi

echo "🔐 Signing app bundle..."
if [ -n "$SIGNING_IDENTITY" ]; then
    echo "   Using identity: $SIGNING_IDENTITY"
    if [ -f "Mira.entitlements" ]; then
        echo "   Using entitlements: Mira.entitlements"
        codesign --force --deep --sign "$SIGNING_IDENTITY" --entitlements "$SIGNING_ENTITLEMENTS" --options runtime "${APP_NAME}.app"
    else
        codesign --force --deep --sign "$SIGNING_IDENTITY" --options runtime "${APP_NAME}.app"
    fi
else
    echo "   Using ad-hoc signing (set SIGNING_IDENTITY for iCloud support)"
    if [ -f "Mira.entitlements" ]; then
        codesign --force --deep --sign - --entitlements "$SIGNING_ENTITLEMENTS" "${APP_NAME}.app"
    else
        codesign --force --deep --sign - "${APP_NAME}.app"
    fi
fi

echo "✅ Created ${APP_NAME}.app (v${VERSION}) with Sparkle support"
