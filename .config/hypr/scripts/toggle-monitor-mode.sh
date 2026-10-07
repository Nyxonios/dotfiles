#!/usr/bin/env bash
set -euo pipefail

LUA_CONF="${LUA_CONF:-$HOME/.config/hypr/hyprland.lua}"

if [ ! -f "$LUA_CONF" ]; then
    echo "Config not found: $LUA_CONF"
    exit 1
fi

CURRENT=$(grep -oP '^local wide_mode = "\K[^"]+' "$LUA_CONF")

case "$CURRENT" in
    "5120x1440@120"|"5120x1440@"*)
        NEW="2560x1440@120"
        MSG="Switched to PBP half: 2560x1440"
        ;;
    "2560x1440@120"|"2560x1440@"*)
        NEW="5120x1440@120"
        MSG="Switched to full: 5120x1440"
        ;;
    *)
        NEW="2560x1440@120"
        MSG="Unknown current mode (${CURRENT}), switching to PBP half: 2560x1440"
        ;;
esac

sed -i -E "s/^local wide_mode = \".*\"/local wide_mode = \"${NEW}\"/" "$LUA_CONF"

# Notify via whatever notification daemon is running
if command -v notify-send &>/dev/null; then
    notify-send "Monitor Mode" "$MSG"
fi

echo "$MSG"
echo "Run 'hyprctl reload' to apply."
