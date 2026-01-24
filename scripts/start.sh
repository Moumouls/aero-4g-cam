#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if VERBOSE mode is enabled
VERBOSE="${VERBOSE:-false}"

# Logging functions
log_info() {
    if [ "$VERBOSE" = "true" ] || [ "$VERBOSE" = "1" ]; then
        echo -e "${BLUE}$1${NC}"
    fi
}

log_success() {
    if [ "$VERBOSE" = "true" ] || [ "$VERBOSE" = "1" ]; then
        echo -e "${GREEN}$1${NC}"
    fi
}

log_error() {
    echo -e "${RED}$1${NC}" >&2
}

log_warn() {
    if [ "$VERBOSE" = "true" ] || [ "$VERBOSE" = "1" ]; then
        echo -e "${YELLOW}$1${NC}"
    fi
}

# Show startup message only in verbose mode
if [ "$VERBOSE" = "true" ] || [ "$VERBOSE" = "1" ]; then
    echo "🚀 Starting PRODUCTION mode (headless)..."
    echo ""
fi

# Detect OS, Architecture, and set Android SDK path
ARCH=$(uname -m)
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macos"
    ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
    # Detect ARM vs Intel Mac
    if [[ "$ARCH" == "arm64" ]]; then
        SYSTEM_IMAGE_ARCH="arm64-v8a"
    else
        SYSTEM_IMAGE_ARCH="x86_64"
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="linux"
    ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
    # Detect Linux architecture
    if [[ "$ARCH" == "aarch64" ]] || [[ "$ARCH" == "arm64" ]]; then
        SYSTEM_IMAGE_ARCH="arm64-v8a"
    else
        SYSTEM_IMAGE_ARCH="x86_64"
    fi
else
    echo -e "${YELLOW}⚠️  Unknown OS: $OSTYPE. Using default ANDROID_HOME${NC}"
    ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/sdk}"
    SYSTEM_IMAGE_ARCH="x86_64"
fi

# Add Android SDK tools to PATH
export ANDROID_HOME
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

# Verify Android SDK is available
if [ ! -f "$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" ]; then
    log_error "❌ Error: Android SDK not properly set up!"
    log_error "Please run: ./setup.sh"
    log_error "Expected location: $ANDROID_HOME/cmdline-tools/latest/bin/avdmanager"
    exit 1
fi

# Verify system images are installed
if ! "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --list_installed 2>/dev/null | grep -q "system-images;android-33;google_apis;$SYSTEM_IMAGE_ARCH"; then
    log_error "❌ Error: Android system images for $SYSTEM_IMAGE_ARCH not installed!"
    log_error "Please run: ./setup.sh"
    exit 1
fi

# Cleanup function
cleanup() {
    log_warn "\n🧹 Cleaning up..."
    if [ ! -z "$APPIUM_PID" ]; then
        log_info "Stopping Appium (PID: $APPIUM_PID)..."
        kill $APPIUM_PID 2>/dev/null || true
    fi
    if [ ! -z "$EMULATOR_PID" ]; then
        log_info "Stopping Emulator (PID: $EMULATOR_PID)..."
        kill $EMULATOR_PID 2>/dev/null || true
    fi
    # Kill any lingering emulator processes
    pkill -f "emulator.*test_emulator" 2>/dev/null || true
    if [ -f "$ANDROID_HOME/platform-tools/adb" ]; then
        "$ANDROID_HOME/platform-tools/adb" emu kill 2>/dev/null || true
    fi
    log_success "✅ Cleanup complete"
}

trap cleanup EXIT INT TERM

# 1. Start Appium server
log_info "📱 Step 1/4: Starting Appium server..."
appium --allow-cors > /dev/null 2>&1 &
APPIUM_PID=$!
log_info "Appium PID: $APPIUM_PID"

# Wait for Appium to be ready
log_info "Waiting for Appium to start..."
sleep 5
for i in {1..10}; do
    if curl -s http://localhost:4723/status > /dev/null 2>&1; then
        log_success "✅ Appium is ready"
        break
    fi
    if [ $i -eq 10 ]; then
        log_error "❌ Appium failed to start"
        exit 1
    fi
    sleep 1
done
[ "$VERBOSE" = "true" ] || [ "$VERBOSE" = "1" ] && echo ""

# 2. Check if emulator AVD exists
log_info "📱 Step 2/4: Checking emulator..."
if ! "$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" list avd 2>/dev/null | grep -q "test_emulator"; then
    log_info "Creating emulator AVD for $SYSTEM_IMAGE_ARCH..."
    if [ "$VERBOSE" = "true" ] || [ "$VERBOSE" = "1" ]; then
        echo "no" | "$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" create avd \
            -n test_emulator \
            -k "system-images;android-33;google_apis;$SYSTEM_IMAGE_ARCH" \
            -d pixel_5 \
            --force
    else
        echo "no" | "$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" create avd \
            -n test_emulator \
            -k "system-images;android-33;google_apis;$SYSTEM_IMAGE_ARCH" \
            -d pixel_5 \
            --force > /dev/null 2>&1
    fi
fi
log_success "✅ Emulator AVD ready"
[ "$VERBOSE" = "true" ] || [ "$VERBOSE" = "1" ] && echo ""

# 3. Start emulator HEADLESS (no window for production)
log_info "📱 Step 3/4: Starting emulator (headless)..."
# Kill any existing emulator
"$ANDROID_HOME/platform-tools/adb" emu kill 2>/dev/null || true
pkill -f "emulator.*test_emulator" 2>/dev/null || true
sleep 2

# Start emulator headless (with Linux optimizations)
if [[ "$OS_TYPE" == "linux" ]]; then
    # Linux: Check if we have GPU acceleration
    if [ -e /dev/kvm ]; then
        if [ "$VERBOSE" = "true" ] || [ "$VERBOSE" = "1" ]; then
            "$ANDROID_HOME/emulator/emulator" -avd test_emulator -no-snapshot-load -no-audio -no-window -accel on &
        else
            "$ANDROID_HOME/emulator/emulator" -avd test_emulator -no-snapshot-load -no-audio -no-window -accel on > /dev/null 2>&1 &
        fi
    else
        log_warn "⚠️  KVM not available, emulator will be slow"
        if [ "$VERBOSE" = "true" ] || [ "$VERBOSE" = "1" ]; then
            "$ANDROID_HOME/emulator/emulator" -avd test_emulator -no-snapshot-load -no-audio -no-window &
        else
            "$ANDROID_HOME/emulator/emulator" -avd test_emulator -no-snapshot-load -no-audio -no-window > /dev/null 2>&1 &
        fi
    fi
else
    # macOS
    if [ "$VERBOSE" = "true" ] || [ "$VERBOSE" = "1" ]; then
        "$ANDROID_HOME/emulator/emulator" -avd test_emulator -no-snapshot-load -no-audio -no-window &
    else
        "$ANDROID_HOME/emulator/emulator" -avd test_emulator -no-snapshot-load -no-audio -no-window > /dev/null 2>&1 &
    fi
fi
EMULATOR_PID=$!
log_info "Emulator PID: $EMULATOR_PID"

# Wait for device
log_info "Waiting for emulator to boot..."
if [ "$VERBOSE" = "true" ] || [ "$VERBOSE" = "1" ]; then
    "$ANDROID_HOME/platform-tools/adb" wait-for-device
else
    "$ANDROID_HOME/platform-tools/adb" wait-for-device > /dev/null 2>&1
fi
log_info "Device detected, waiting for full boot..."
sleep 15

# Wait for boot to complete
for i in {1..30}; do
    BOOT_COMPLETED=$("$ANDROID_HOME/platform-tools/adb" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
    if [ "$BOOT_COMPLETED" = "1" ]; then
        log_success "✅ Emulator is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        log_error "❌ Emulator boot timeout"
        exit 1
    fi
    sleep 2
done
[ "$VERBOSE" = "true" ] || [ "$VERBOSE" = "1" ] && echo ""

# 3.5. Install split APKs
cd "$(dirname "$0")/.."
SPLIT_APKS_DIR="split-apks"

if [ -d "$SPLIT_APKS_DIR" ] && [ -n "$(ls -A $SPLIT_APKS_DIR/*.apk 2>/dev/null)" ]; then
    log_info "📦 Installing split APKs..."
    
    # Check if app is already installed
    PACKAGE_NAME="cn.ubia.ubox"
    if "$ANDROID_HOME/platform-tools/adb" shell pm list packages 2>/dev/null | grep -q "package:$PACKAGE_NAME"; then
        log_info "App already installed, uninstalling first..."
        if [ "$VERBOSE" = "true" ] || [ "$VERBOSE" = "1" ]; then
            "$ANDROID_HOME/platform-tools/adb" uninstall "$PACKAGE_NAME" 2>/dev/null || true
        else
            "$ANDROID_HOME/platform-tools/adb" uninstall "$PACKAGE_NAME" > /dev/null 2>&1 || true
        fi
    fi
    
    # Detect device ABI
    DEVICE_ABI=$("$ANDROID_HOME/platform-tools/adb" shell getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r')
    log_info "Device ABI: $DEVICE_ABI"
    
    # Build list of APKs to install
    # Note: arm64-v8a devices can run armeabi-v7a (32-bit ARM) through compatibility
    APK_FILES=()
    for apk in "$SPLIT_APKS_DIR"/*.apk; do
        apk_name=$(basename "$apk")
        
        # Skip x86/x86_64 architecture APKs on ARM devices and vice versa
        if [[ "$DEVICE_ABI" == "arm64-v8a" ]] || [[ "$DEVICE_ABI" == "armeabi-v7a" ]]; then
            # ARM device - skip x86 APKs
            if [[ "$apk_name" == *"x86_64"* ]] || [[ "$apk_name" == *"x86.apk"* ]]; then
                log_info "Skipping $apk_name (x86 on ARM device)"
                continue
            fi
        elif [[ "$DEVICE_ABI" == "x86_64" ]] || [[ "$DEVICE_ABI" == "x86" ]]; then
            # x86 device - skip ARM APKs
            if [[ "$apk_name" == *"armeabi"* ]] || [[ "$apk_name" == *"arm64"* ]]; then
                log_info "Skipping $apk_name (ARM on x86 device)"
                continue
            fi
        fi
        
        APK_FILES+=("$apk")
    done
    
    APK_COUNT=${#APK_FILES[@]}
    log_info "Installing $APK_COUNT compatible split APK files..."
    if [ "$VERBOSE" = "true" ] || [ "$VERBOSE" = "1" ]; then
        "$ANDROID_HOME/platform-tools/adb" install-multiple -g "${APK_FILES[@]}"
    else
        # Capture output, only show if there's an error
        if ! "$ANDROID_HOME/platform-tools/adb" install-multiple -g "${APK_FILES[@]}" > /dev/null 2>&1; then
            log_error "❌ Failed to install APKs"
            exit 1
        fi
    fi
    
    log_success "✅ Split APKs installed successfully"
else
    log_error "❌ Split APKs directory not found! Please run ./setup.sh first"
    exit 1
fi
[ "$VERBOSE" = "true" ] || [ "$VERBOSE" = "1" ] && echo ""

# 3.6. Push OBB files if they exist
if [ -d "obb" ] && [ -n "$(find obb -name '*.obb' 2>/dev/null)" ]; then
    log_info "📦 Pushing OBB files to device..."
    
    # Use the known package name
    PACKAGE_NAME="cn.ubia.ubox"
    
    if [ -z "$PACKAGE_NAME" ]; then
        log_error "❌ Could not determine package name for OBB files"
    else
        log_info "Package name: $PACKAGE_NAME"
        
        # Create OBB directory on device
        "$ANDROID_HOME/platform-tools/adb" shell mkdir -p "/sdcard/Android/obb/$PACKAGE_NAME" 2>/dev/null || true
        
        # Push each OBB file
        find obb -name "*.obb" | while read -r obb_file; do
            OBB_FILENAME=$(basename "$obb_file")
            log_info "Pushing $OBB_FILENAME..."
            if [ "$VERBOSE" = "true" ] || [ "$VERBOSE" = "1" ]; then
                "$ANDROID_HOME/platform-tools/adb" push "$obb_file" "/sdcard/Android/obb/$PACKAGE_NAME/$OBB_FILENAME"
            else
                if ! "$ANDROID_HOME/platform-tools/adb" push "$obb_file" "/sdcard/Android/obb/$PACKAGE_NAME/$OBB_FILENAME" > /dev/null 2>&1; then
                    log_error "❌ Failed to push OBB file: $OBB_FILENAME"
                    exit 1
                fi
            fi
        done
        
        log_success "✅ OBB files pushed to device"
    fi
else
    log_info "ℹ️  No OBB files found, skipping..."
fi
[ "$VERBOSE" = "true" ] || [ "$VERBOSE" = "1" ] && echo ""

# 4. Run automation
log_info "📱 Step 4/5: Starting automation..."
[ "$VERBOSE" = "true" ] || [ "$VERBOSE" = "1" ] && echo ""
node src/automation/camera-recorder.js

[ "$VERBOSE" = "true" ] || [ "$VERBOSE" = "1" ] && echo ""
log_success "🎉 Production run completed successfully!"

