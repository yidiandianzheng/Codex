#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
APP_NAME="Codex算力条"
BUILD_DIR="${CODEX_PET_ENERGY_BUILD_DIR:-$HOME/Library/Caches/CodexPetEnergy}"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp ".build/release/CodexPetEnergy" "$APP_DIR/Contents/MacOS/CodexPetEnergy"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
xattr -cr "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"
xattr -cr "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "$APP_DIR"
