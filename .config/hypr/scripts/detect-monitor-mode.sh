#!/usr/bin/env bash
set -euo pipefail

LUA_CONF="${LUA_CONF:-$HOME/.config/hypr/hyprland.lua}"

if [ ! -f "$LUA_CONF" ]; then
    echo "Config not found: $LUA_CONF"
    exit 1
fi

# Detect current active monitor geometry from Hyprland
read -r NAME WIDTH HEIGHT REFRESH < <(hyprctl monitors -j \
    | jq -r '.[0] | "\(.name) \(.width) \(.height) \(.refreshRate)"')
REFRESH=$(printf '%.0f' "$REFRESH")
MODE="${WIDTH}x${HEIGHT}@${REFRESH}"

# Update the Lua config — only `wide_mode` needs changing because
# `wide_w`, `wide_h`, `float_w`, and `float_h` are derived from it.
sed -i -E "s/^local wide_mode = \".*\"/local wide_mode = \"${MODE}\"/" "$LUA_CONF"

echo "Patched ${LUA_CONF}: ${MODE} (${NAME})"
echo "Run 'hyprctl reload' (or log out/in) to apply."
