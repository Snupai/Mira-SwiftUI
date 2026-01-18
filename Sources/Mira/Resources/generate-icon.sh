#!/bin/bash
# Generate AppIcon.icns from AppIcon.svg
set -e

cd "$(dirname "$0")"

# Create iconset directory
rm -rf AppIcon.iconset
mkdir -p AppIcon.iconset

# Check if we have rsvg-convert or qlmanage for SVG conversion
if command -v rsvg-convert &> /dev/null; then
    CONVERT_CMD="rsvg"
elif command -v sips &> /dev/null; then
    CONVERT_CMD="sips"
else
    echo "Error: Need rsvg-convert (librsvg) or sips for conversion"
    echo "Install with: brew install librsvg"
    exit 1
fi

# Generate all required sizes
sizes=(16 32 64 128 256 512 1024)

for size in "${sizes[@]}"; do
    if [ "$CONVERT_CMD" = "rsvg" ]; then
        rsvg-convert -w $size -h $size AppIcon.svg -o "AppIcon.iconset/icon_${size}x${size}.png"
        # Also create @2x versions where applicable
        if [ $size -le 512 ]; then
            double=$((size * 2))
            rsvg-convert -w $double -h $double AppIcon.svg -o "AppIcon.iconset/icon_${size}x${size}@2x.png"
        fi
    else
        # Fallback: use qlmanage to render SVG then sips to resize
        if [ ! -f "AppIcon_master.png" ]; then
            qlmanage -t -s 1024 -o . AppIcon.svg 2>/dev/null
            mv AppIcon.svg.png AppIcon_master.png 2>/dev/null || true
        fi
        sips -z $size $size AppIcon_master.png --out "AppIcon.iconset/icon_${size}x${size}.png" 2>/dev/null
        if [ $size -le 512 ]; then
            double=$((size * 2))
            sips -z $double $double AppIcon_master.png --out "AppIcon.iconset/icon_${size}x${size}@2x.png" 2>/dev/null
        fi
    fi
done

# Create icns file
iconutil -c icns AppIcon.iconset -o AppIcon.icns

# Cleanup
rm -rf AppIcon.iconset AppIcon_master.png 2>/dev/null || true

echo "✅ Created AppIcon.icns"
