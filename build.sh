#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="SecretPad.app"
rm -rf "$APP" build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build

compile() {
  local sdk_target="$1"
  local output="$2"
  swiftc -O -parse-as-library \
    -target "$sdk_target" \
    -framework AppKit \
    -framework CoreText \
    -o "$output" \
    main.swift
}

compile arm64-apple-macos14.0 build/SecretPad-arm64
if compile x86_64-apple-macos14.0 build/SecretPad-x86_64; then
  lipo -create -output "$APP/Contents/MacOS/SecretPad" \
    build/SecretPad-arm64 \
    build/SecretPad-x86_64
else
  cp build/SecretPad-arm64 "$APP/Contents/MacOS/SecretPad"
fi

cp Info.plist "$APP/Contents/Info.plist"
cp save-secrets.sh "$APP/Contents/Resources/save-secrets.sh"
cp fonts/Monocraft.ttf fonts/OFL-Monocraft.txt SecretPad.icns "$APP/Contents/Resources/"
chmod 755 "$APP/Contents/MacOS/SecretPad" "$APP/Contents/Resources/save-secrets.sh"
echo "built $(pwd)/$APP"
