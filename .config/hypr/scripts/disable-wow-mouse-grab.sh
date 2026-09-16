#!/usr/bin/env bash

# Disable Super+mouse grab for World of Warcraft.
# Listens to Hyprland's socket2 and unbinds SUPER+mouse:272/273 drag/resize
# when WoW is focused, re-binds them when focus leaves WoW.

LOG="/tmp/hypr-wow-grab.log"
exec >>"$LOG" 2>&1

# Re-exec with nix-shell if socat is missing.
if ! command -v socat &>/dev/null; then
	exec nix-shell -p socat --run "bash '$0'"
fi

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id - u)}"
SOCKET="${RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
STATE_FILE="/tmp/hypr-wow-grab-state"
LOCK_FILE="/tmp/hypr-wow-grab.lock"

echo "=== Script started at $(date) PID=$$ ==="
echo "PATH=$PATH"
echo "HYPRLAND_INSTANCE_SIGNATURE=${HYPRLAND_INSTANCE_SIGNATURE:-<not set>}"

# Prevent duplicate instances.
if [[ -f "$LOCK_FILE" ]]; then
	old_pid=$(cat "$LOCK_FILE" 2>/dev/null || true)
	if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
		echo "Replacing old instance (PID $old_pid)"
		kill "$old_pid" 2>/dev/null || true
		# Give the old socat loop a moment to exit so the socket is free.
		sleep 0.5
	fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

if [[ ! -S "$SOCKET" ]]; then
	echo "ERROR: Hyprland socket2 not found: $SOCKET"
	exit 1
fi
echo "Using socket: $SOCKET"

if ! command -v hyprctl &>/dev/null; then
	echo "ERROR: hyprctl not found"
	exit 1
fi

# Helper: get active window title via hyprctl.
get_focused_title() {
	hyprctl activewindow 2>/dev/null \
		| grep -m1 '^[[:space:]]*title:' \
		| sed 's/.*title:[[:space:]]*//' \
		|| true
}

# Helper: get active window class via hyprctl.
get_focused_class() {
	hyprctl activewindow 2>/dev/null \
		| grep -m1 '^[[:space:]]*class:' \
		| sed 's/.*class:[[:space:]]*//' \
		|| true
}

# Set initial state.
title=$(get_focused_title)
echo "Initial title='$title' class='$(get_focused_class)'"
if [[ "$title" == "World of Warcraft" ]]; then
	echo "Initial: WoW focused -> unbinding"
	hyprctl eval 'hl.unbind("SUPER + mouse:272")' || true
	hyprctl eval 'hl.unbind("SUPER + mouse:273")' || true
	echo "unbound" > "$STATE_FILE"
else
	echo "Initial: not WoW -> keeping binds"
	echo "bound" > "$STATE_FILE"
fi

echo "Listening for events..."

# Outer loop restarts socat if the socket disconnects (e.g. Hyprland reload).
while true; do
	# -u = unidirectional (read from socket, write to stdout)
	socat -u UNIX-CONNECT:"$SOCKET" - 2>/dev/null | while IFS= read -r line; do
		echo "EVENT: $line"

		# Hyprland activewindow format: activewindow>>CLASS,TITLE
		if [[ "$line" == "activewindow>>"* ]]; then
			rest="${line#activewindow>>}"
			class="${rest%%,*}"
			title="${rest#*,}"
			echo "PARSED class='$class' title='$title'"
		else
			continue
		fi

		state=$(cat "$STATE_FILE" 2>/dev/null || echo "bound")
		echo "STATE: $state"

		if [[ "$title" == "World of Warcraft" ]]; then
			if [[ "$state" != "unbound" ]]; then
				echo "ACTION: unbind SUPER+mouse"
				hyprctl eval 'hl.unbind("SUPER + mouse:272")' || echo "unbind 272 failed"
				hyprctl eval 'hl.unbind("SUPER + mouse:273")' || echo "unbind 273 failed"
				echo "unbound" > "$STATE_FILE"
			fi
		else
			if [[ "$state" != "bound" ]]; then
				echo "ACTION: rebind SUPER+mouse"
				hyprctl eval 'hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })' || echo "bind 272 failed"
				hyprctl eval 'hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })' || echo "bind 273 failed"
				echo "bound" > "$STATE_FILE"
			fi
		fi
	done
	echo "socat disconnected (Hyprland reload?), reconnecting in 2s ..."
	sleep 2
done
