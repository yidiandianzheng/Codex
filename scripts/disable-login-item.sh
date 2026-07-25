#!/bin/zsh
set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/com.local.codex-pet-energy.plist"
DOMAIN="gui/$(id -u)"

if [[ -f "$PLIST" ]]; then
  launchctl bootout "$DOMAIN" "$PLIST" 2>/dev/null || true
  rm -f "$PLIST"
fi
echo "已关闭登录自动启动。"
