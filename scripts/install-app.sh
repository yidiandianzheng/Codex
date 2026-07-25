#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
SOURCE_APP="${CODEX_PET_ENERGY_BUILD_DIR:-$HOME/Library/Caches/CodexPetEnergy}/Codex算力条.app"
INSTALL_DIR="$HOME/Applications"
INSTALLED_APP="$INSTALL_DIR/Codex算力条.app"

"$ROOT_DIR/scripts/build-app.sh" >/dev/null
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALLED_APP"
ditto "$SOURCE_APP" "$INSTALLED_APP"
xattr -cr "$INSTALLED_APP"
codesign --force --deep --sign - "$INSTALLED_APP"
xattr -cr "$INSTALLED_APP"
codesign --verify --deep --strict "$INSTALLED_APP"

echo "$INSTALLED_APP"
