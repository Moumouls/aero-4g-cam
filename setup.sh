#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Aero 4G Cam - Setup Script${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Detect OS and Architecture
OS_TYPE="unknown"
ARCH=$(uname -m)
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macos"
    echo -e "${GREEN}✅ Detected: macOS${NC}"
    # Detect ARM vs Intel Mac
    if [[ "$ARCH" == "arm64" ]]; then
        SYSTEM_IMAGE_ARCH="arm64-v8a"
        echo -e "${GREEN}✅ Detected: Apple Silicon (ARM)${NC}"
    else
        SYSTEM_IMAGE_ARCH="x86_64"
        echo -e "${GREEN}✅ Detected: Intel Mac (x86_64)${NC}"
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="linux"
    echo -e "${GREEN}✅ Detected: Linux${NC}"
    # Detect Linux architecture
    if [[ "$ARCH" == "aarch64" ]] || [[ "$ARCH" == "arm64" ]]; then
        SYSTEM_IMAGE_ARCH="arm64-v8a"
        echo -e "${GREEN}✅ Detected: ARM architecture${NC}"
    else
        SYSTEM_IMAGE_ARCH="x86_64"
        echo -e "${GREEN}✅ Detected: x86_64 architecture${NC}"
    fi
else
    echo -e "${RED}❌ Unsupported OS: $OSTYPE${NC}"
    exit 1
fi
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Step 1: Check/Install Java (required for Android SDK)
echo -e "${BLUE}☕ Step 1/7: Checking Java...${NC}"
if java -version 2>&1 | grep -q "version"; then
    JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2)
    echo -e "${GREEN}✅ Java is installed: version $JAVA_VERSION${NC}"
else
    echo -e "${YELLOW}⚠️  Java not found. Installing...${NC}"
    if [[ "$OS_TYPE" == "macos" ]]; then
        if command_exists brew; then
            brew install --cask temurin
            # Verify installation
            if java -version 2>&1 | grep -q "version"; then
                echo -e "${GREEN}✅ Java installed${NC}"
            else
                echo -e "${RED}❌ Java installation failed${NC}"
                exit 1
            fi
        else
            echo -e "${RED}❌ Homebrew not found. Please install from https://brew.sh${NC}"
            exit 1
        fi
    else
        # Linux - install OpenJDK
        sudo apt-get update
        sudo apt-get install -y openjdk-17-jdk
    fi
fi
echo ""

# Step 2: Check/Install Node.js
echo -e "${BLUE}📦 Step 2/7: Checking Node.js...${NC}"
if command_exists node; then
    NODE_VERSION=$(node --version)
    echo -e "${GREEN}✅ Node.js is installed: $NODE_VERSION${NC}"
else
    echo -e "${YELLOW}⚠️  Node.js not found. Installing...${NC}"
    if [[ "$OS_TYPE" == "macos" ]]; then
        if command_exists brew; then
            brew install node
        else
            echo -e "${RED}❌ Homebrew not found. Please install from https://brew.sh${NC}"
            exit 1
        fi
    else
        # Linux - use NodeSource
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi
    echo -e "${GREEN}✅ Node.js installed${NC}"
fi
echo ""

# Step 3: Check/Install Yarn
echo -e "${BLUE}📦 Step 3/7: Checking Yarn...${NC}"
if command_exists yarn; then
    YARN_VERSION=$(yarn --version)
    echo -e "${GREEN}✅ Yarn is installed: $YARN_VERSION${NC}"
else
    echo -e "${YELLOW}⚠️  Yarn not found. Installing...${NC}"
    npm install -g yarn
    echo -e "${GREEN}✅ Yarn installed${NC}"
fi
echo ""

# Step 4: Install Android SDK
echo -e "${BLUE}📱 Step 4/7: Setting up Android SDK...${NC}"

# Set Android SDK paths based on OS
if [[ "$OS_TYPE" == "macos" ]]; then
    ANDROID_HOME="$HOME/Library/Android/sdk"
else
    ANDROID_HOME="$HOME/Android/Sdk"
fi

export ANDROID_HOME
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"

# Check if SDK is properly installed with all components
SDK_COMPLETE=true
if [ ! -d "$ANDROID_HOME/cmdline-tools/latest/bin" ]; then
    SDK_COMPLETE=false
elif [ ! -d "$ANDROID_HOME/platform-tools" ]; then
    SDK_COMPLETE=false
elif [ ! -d "$ANDROID_HOME/emulator" ]; then
    SDK_COMPLETE=false
elif ! "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --list 2>/dev/null | grep -q "system-images;android-33;google_apis;$SYSTEM_IMAGE_ARCH"; then
    SDK_COMPLETE=false
fi

if [ "$SDK_COMPLETE" = true ]; then
    # Verify system images are actually installed
    if "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --list_installed 2>/dev/null | grep -q "system-images;android-33;google_apis;$SYSTEM_IMAGE_ARCH"; then
        echo -e "${GREEN}✅ Android SDK already installed with all components${NC}"
    else
        SDK_COMPLETE=false
    fi
fi

if [ "$SDK_COMPLETE" = false ]; then
    echo -e "${YELLOW}⚠️  Setting up Android SDK components...${NC}"
    
    # Create Android SDK directory
    mkdir -p "$ANDROID_HOME"
    
    # Check if cmdline-tools need to be installed
    if [ ! -d "$ANDROID_HOME/cmdline-tools/latest/bin" ]; then
        echo "Installing Android SDK command-line tools..."
        cd "$ANDROID_HOME"
        
        # Download command line tools
        if [[ "$OS_TYPE" == "macos" ]]; then
            CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip"
        else
            CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
        fi
        
        curl -o cmdline-tools.zip "$CMDLINE_TOOLS_URL"
        unzip -q cmdline-tools.zip
        rm cmdline-tools.zip
        
        # Move to proper location
        mkdir -p cmdline-tools/latest
        if [ -d "cmdline-tools/bin" ]; then
            mv cmdline-tools/bin cmdline-tools/lib cmdline-tools/source.properties cmdline-tools/NOTICE.txt cmdline-tools/latest/ 2>/dev/null || true
        fi
        
        cd - > /dev/null
    fi
    
    # Accept licenses
    echo "Accepting Android SDK licenses..."
    yes | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --licenses 2>/dev/null || true
    
    # Install essential SDK components
    echo "Installing Android SDK components for $SYSTEM_IMAGE_ARCH (this may take a few minutes)..."
    "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" \
        "platform-tools" \
        "platforms;android-33" \
        "build-tools;33.0.0" \
        "emulator" \
        "system-images;android-33;google_apis;$SYSTEM_IMAGE_ARCH"
    
    echo -e "${GREEN}✅ Android SDK components installed${NC}"
fi
echo ""

# Step 5: Configure environment variables
echo -e "${BLUE}🔧 Step 5/7: Configuring environment variables...${NC}"

SHELL_CONFIG=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_CONFIG="$HOME/.bashrc"
elif [ -f "$HOME/.bash_profile" ]; then
    SHELL_CONFIG="$HOME/.bash_profile"
fi

if [ -n "$SHELL_CONFIG" ]; then
    # Check if ANDROID_HOME is already in the config
    if ! grep -q "ANDROID_HOME" "$SHELL_CONFIG"; then
        echo "" >> "$SHELL_CONFIG"
        echo "# Android SDK" >> "$SHELL_CONFIG"
        echo "export ANDROID_HOME=\"$ANDROID_HOME\"" >> "$SHELL_CONFIG"
        echo "export PATH=\"\$PATH:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/emulator\"" >> "$SHELL_CONFIG"
        echo -e "${GREEN}✅ Added ANDROID_HOME to $SHELL_CONFIG${NC}"
        echo -e "${YELLOW}⚠️  Please run: source $SHELL_CONFIG${NC}"
    else
        echo -e "${GREEN}✅ Environment variables already configured${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Could not detect shell config file. Please add these manually:${NC}"
    echo "export ANDROID_HOME=\"$ANDROID_HOME\""
    echo "export PATH=\"\$PATH:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/emulator\""
fi
echo ""

# Step 6: Extract XAPK to split APKs and OBB files
echo -e "${BLUE}📦 Step 6/8: Extracting UBox XAPK...${NC}"
cd "$(dirname "$0")"

XAPK_FILE="UBox.xapk"
SPLIT_APKS_DIR="split-apks"
OBB_DIR="obb"

if [ -f "$XAPK_FILE" ]; then
    echo "Found UBox.xapk, extracting split APKs..."
    
    # Create directories
    rm -rf "$SPLIT_APKS_DIR"
    mkdir -p "$SPLIT_APKS_DIR"
    
    TEMP_DIR=".xapk-temp"
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    # Extract XAPK (it's just a ZIP file)
    unzip -q "$XAPK_FILE" -d "$TEMP_DIR"
    
    # Copy all APK files to split-apks directory
    APK_COUNT=$(find "$TEMP_DIR" -name "*.apk" -type f | wc -l | tr -d ' ')
    if [ "$APK_COUNT" -eq 0 ]; then
        echo -e "${RED}❌ No APK files found inside XAPK${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    cp "$TEMP_DIR"/*.apk "$SPLIT_APKS_DIR/"
    echo -e "${GREEN}✅ Extracted $APK_COUNT split APK files to ./$SPLIT_APKS_DIR/${NC}"
    
    # Check for OBB files and preserve them
    if [ -d "$TEMP_DIR/Android/obb" ]; then
        echo "Found OBB files, preserving..."
        rm -rf "$OBB_DIR"
        mkdir -p "$OBB_DIR"
        cp -r "$TEMP_DIR/Android/obb/"* "$OBB_DIR/"
        OBB_COUNT=$(find "$OBB_DIR" -name "*.obb" -type f | wc -l | tr -d ' ')
        echo -e "${GREEN}✅ Preserved $OBB_COUNT OBB file(s) in ./$OBB_DIR/${NC}"
    else
        echo "No OBB files found in XAPK"
    fi
    
    # Clean up temp directory
    rm -rf "$TEMP_DIR"
    
elif [ -d "$SPLIT_APKS_DIR" ] && [ "$(ls -A $SPLIT_APKS_DIR/*.apk 2>/dev/null | wc -l | tr -d ' ')" -gt 0 ]; then
    APK_COUNT=$(ls -1 "$SPLIT_APKS_DIR"/*.apk 2>/dev/null | wc -l | tr -d ' ')
    echo -e "${GREEN}✅ Split APKs already extracted ($APK_COUNT files in ./$SPLIT_APKS_DIR/)${NC}"
else
    echo -e "${RED}❌ UBox.xapk not found and no split APKs directory exists!${NC}"
    exit 1
fi
echo ""

# Step 7: Install project dependencies
echo -e "${BLUE}📦 Step 7/8: Installing project dependencies...${NC}"
yarn install
echo -e "${GREEN}✅ Dependencies installed${NC}"
echo ""

# Step 8: Setup Appium
echo -e "${BLUE}📱 Step 8/8: Setting up Appium...${NC}"
# Check if appium is available (from node_modules or globally)
if command_exists appium || [ -f "node_modules/.bin/appium" ]; then
    APPIUM_CMD="appium"
    if ! command_exists appium && [ -f "node_modules/.bin/appium" ]; then
        APPIUM_CMD="./node_modules/.bin/appium"
    fi
    
    echo "Appium is available"
    
    # Check if uiautomator2 driver is installed (check output more carefully)
    DRIVER_LIST=$($APPIUM_CMD driver list --installed 2>&1)
    if echo "$DRIVER_LIST" | grep -q "uiautomator2"; then
        echo -e "${GREEN}✅ Appium uiautomator2 driver already installed${NC}"
    else
        echo "Installing uiautomator2 driver..."
        if $APPIUM_CMD driver install uiautomator2 2>&1 | grep -q "already installed"; then
            echo -e "${GREEN}✅ Appium uiautomator2 driver already installed${NC}"
        else
            echo -e "${GREEN}✅ Appium uiautomator2 driver installed${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⚠️  Appium not found in dependencies or globally${NC}"
    echo -e "${YELLOW}Running yarn install should fix this...${NC}"
fi
echo ""

# Additional Linux-specific setup
if [[ "$OS_TYPE" == "linux" ]]; then
    echo -e "${BLUE}🐧 Linux-specific setup...${NC}"
    
    # Install dependencies for headless emulator
    echo "Checking required packages..."
    REQUIRED_PACKAGES=(
        "qemu-kvm"
        "libvirt-daemon-system"
        "libvirt-clients"
        "bridge-utils"
        "cpu-checker"
    )
    
    MISSING_PACKAGES=()
    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg"; then
            MISSING_PACKAGES+=("$pkg")
        fi
    done
    
    if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Installing missing packages: ${MISSING_PACKAGES[*]}${NC}"
        sudo apt-get update
        sudo apt-get install -y "${MISSING_PACKAGES[@]}"
    fi
    
    # Enable KVM acceleration
    if [ -e /dev/kvm ]; then
        echo -e "${GREEN}✅ KVM acceleration available${NC}"
        # Add user to kvm group
        if ! groups | grep -q "kvm"; then
            sudo usermod -aG kvm "$USER"
            echo -e "${YELLOW}⚠️  Added user to kvm group. Please log out and log back in.${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  KVM not available. Emulator will run slowly.${NC}"
    fi
    
    echo -e "${GREEN}✅ Linux setup complete${NC}"
    echo ""
fi

echo ""
echo -e "${GREEN}🎉 Setup completed successfully!${NC}"
