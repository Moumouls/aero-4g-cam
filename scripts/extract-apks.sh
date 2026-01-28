#!/bin/bash
set -e

echo "📦 Extracting split APKs from XAPK..."

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

XAPK_FILE="UBox.xapk"
SPLIT_APKS_DIR="split-apks"
OBB_DIR="obb"

if [ ! -f "$XAPK_FILE" ]; then
    echo "❌ UBox.xapk not found at $ROOT_DIR/$XAPK_FILE"
    exit 1
fi

echo "Found UBox.xapk, re-extracting split APKs..."

rm -rf "$SPLIT_APKS_DIR"
mkdir -p "$SPLIT_APKS_DIR"

TEMP_DIR=".xapk-temp"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

unzip -q "$XAPK_FILE" -d "$TEMP_DIR"

APK_COUNT=$(find "$TEMP_DIR" -name "*.apk" -type f | wc -l | tr -d ' ')
if [ "$APK_COUNT" -eq 0 ]; then
    echo "❌ No APK files found inside XAPK"
    rm -rf "$TEMP_DIR"
    exit 1
fi

cp "$TEMP_DIR"/*.apk "$SPLIT_APKS_DIR/"
echo "✅ Extracted $APK_COUNT split APK file(s) to ./$SPLIT_APKS_DIR/"

if [ -d "$TEMP_DIR/Android/obb" ]; then
    echo "Found OBB files, preserving..."
    rm -rf "$OBB_DIR"
    mkdir -p "$OBB_DIR"
    cp -r "$TEMP_DIR/Android/obb/"* "$OBB_DIR/"
    OBB_COUNT=$(find "$OBB_DIR" -name "*.obb" -type f | wc -l | tr -d ' ')
    echo "✅ Preserved $OBB_COUNT OBB file(s) in ./$OBB_DIR/"
else
    echo "ℹ️  No OBB files found in XAPK"
fi

rm -rf "$TEMP_DIR"

echo "✅ Extraction complete"
