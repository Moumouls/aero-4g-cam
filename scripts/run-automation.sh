#!/bin/bash
set -e

echo "📱 Emulator is ready!"

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

