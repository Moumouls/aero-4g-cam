#!/bin/bash
set -e

echo "📱 Emulator is ready!"

# Show device info
echo "📱 Device info:"
adb shell getprop ro.build.version.release
adb shell getprop ro.product.model
adb devices -l

# Verify ARM translation support
echo "🔍 Checking ARM ABI support on emulator..."
adb shell getprop ro.product.cpu.abilist | tee /tmp/abi_list.txt || echo "unknown" > /tmp/abi_list.txt
echo "Supported ABIs: $(cat /tmp/abi_list.txt)"
if grep -q "arm64-v8a" /tmp/abi_list.txt; then
    echo "✅ arm64-v8a is supported"
else
    echo "⚠️ arm64-v8a is NOT supported - ARM APK installation may fail"
fi

adb shell getprop ro.dalvik.vm.native.bridge | tee /tmp/native_bridge.txt || echo "none" > /tmp/native_bridge.txt
echo "Native bridge: $(cat /tmp/native_bridge.txt)"
if grep -q "libndk" /tmp/native_bridge.txt; then
    echo "✅ ARM translation (libndk_translation) is active"
else
    echo "⚠️ ARM translation bridge: $(cat /tmp/native_bridge.txt)"
fi

# Start Appium server in background
echo "📱 Starting Appium server..."
yarn exec appium --allow-cors > /tmp/appium.log 2>&1 &
APPIUM_PID=$!
echo $APPIUM_PID > /tmp/appium.pid
echo "Appium PID: $APPIUM_PID"

# Wait for Appium to be ready
echo "⏳ Waiting for Appium to start..."
for i in {1..30}; do
    if curl -s http://localhost:4723/status > /dev/null 2>&1; then
        echo "✅ Appium is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Appium failed to start"
        cat /tmp/appium.log
        kill $APPIUM_PID 2>/dev/null || true
        exit 1
    fi
    sleep 1
done

# Install APKs
echo "📦 Installing split APKs..."

SPLIT_APKS_DIR="split-apks"
PACKAGE_NAME="cn.ubia.ubox"

# Check if app is already installed
if adb shell pm list packages 2>/dev/null | grep -q "package:$PACKAGE_NAME"; then
    echo "App already installed, uninstalling first..."
    adb uninstall "$PACKAGE_NAME" 2>/dev/null || true
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

# Run the camera recorder automation
echo "🎥 Running camera recorder automation..."
VERBOSE=0 node src/automation/camera-recorder.js

# Cleanup Appium
echo "🧹 Stopping Appium..."
kill $(cat /tmp/appium.pid 2>/dev/null) 2>/dev/null || true
pkill -f appium || true

# Show logs
if [ -f /tmp/appium.log ]; then
    echo "📋 Appium logs (last 50 lines):"
    tail -50 /tmp/appium.log
fi

echo "✅ Automation completed successfully"

