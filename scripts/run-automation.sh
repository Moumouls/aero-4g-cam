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

# Install APKs and OBBs
bash scripts/install-app.sh

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

