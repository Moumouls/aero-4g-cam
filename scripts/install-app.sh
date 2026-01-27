#!/bin/bash
set -e

echo "📦 Installing split APKs..."

SPLIT_APKS_DIR="split-apks"
PACKAGE_NAME="cn.ubia.ubox"

# Check if app is already installed
if adb shell pm list packages 2>/dev/null | grep -q "package:$PACKAGE_NAME"; then
    if [ "${REINSTALL_APP:-0}" = "1" ]; then
        echo "App already installed, reinstalling (REINSTALL_APP=1)..."
        adb uninstall "$PACKAGE_NAME" 2>/dev/null || true
    else
        echo "✅ App already installed, skipping install"
        exit 0
    fi
fi

# Install all APKs (compatible with ARM64)
echo "Installing split APKs..."
adb install-multiple -g "$SPLIT_APKS_DIR"/*.apk

echo "✅ Split APKs installed successfully"

# Push OBB files if they exist
if [ -d "obb" ] && [ -n "$(find obb -name '*.obb' 2>/dev/null)" ]; then
    echo "📦 Pushing OBB files to device..."
    
    # Create OBB directory on device
    adb shell mkdir -p "/sdcard/Android/obb/$PACKAGE_NAME" 2>/dev/null || true
    
    # Push each OBB file
    find obb -name "*.obb" | while read -r obb_file; do
        OBB_FILENAME=$(basename "$obb_file")
        echo "Pushing $OBB_FILENAME..."
        adb push "$obb_file" "/sdcard/Android/obb/$PACKAGE_NAME/$OBB_FILENAME"
    done
    
    echo "✅ OBB files pushed to device"
else
    echo "ℹ️  No OBB files found, skipping..."
fi

echo "✅ Device ready for testing"
