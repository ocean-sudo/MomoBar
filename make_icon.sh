#!/bin/bash
set -e

# Create temporary directory
mkdir -p AppIcon.iconset

# Resize image to standard Apple resolutions
sips -z 16 16 logo4.png --out AppIcon.iconset/icon_16x16.png > /dev/null 2>&1
sips -z 32 32 logo4.png --out AppIcon.iconset/icon_16x16@2x.png > /dev/null 2>&1
sips -z 32 32 logo4.png --out AppIcon.iconset/icon_32x32.png > /dev/null 2>&1
sips -z 64 64 logo4.png --out AppIcon.iconset/icon_32x32@2x.png > /dev/null 2>&1
sips -z 128 128 logo4.png --out AppIcon.iconset/icon_128x128.png > /dev/null 2>&1
sips -z 256 256 logo4.png --out AppIcon.iconset/icon_128x128@2x.png > /dev/null 2>&1
sips -z 256 256 logo4.png --out AppIcon.iconset/icon_256x256.png > /dev/null 2>&1
sips -z 512 512 logo4.png --out AppIcon.iconset/icon_256x256@2x.png > /dev/null 2>&1
sips -z 512 512 logo4.png --out AppIcon.iconset/icon_512x512.png > /dev/null 2>&1
sips -z 1024 1024 logo4.png --out AppIcon.iconset/icon_512x512@2x.png > /dev/null 2>&1

# Compile to .icns format
iconutil -c icns AppIcon.iconset

# Clean up
rm -rf AppIcon.iconset

echo "AppIcon.icns generated successfully!"
