#!/usr/bin/env bash
# Helper for managing PI agent tmux background sessions
# Usage: ./pi-tmux.sh <command> [args]
# Can also be sourced to use as a library: source ./pi-tmux.sh && pi_tmux init

# Save current shell options so they can be restored after sourcing.
__pi_tmux_old_opts=$-
shopt -p pipefail >/dev/null 2>&1 && __pi_tmux_old_pipefail=1 || __pi_tmux_old_pipefail=0

set -euo pipefail

DEFAULT_SESSION="pi-agent-bg"
SESSION_FILE="${TMPDIR:-/tmp}/.pi_agent_tmux_session"

usage() {
    cat <<EOF
Usage: pi_tmux <command> [args]

Commands:
  init [name]               Create a new detached tmux session.
                            Default name: pi-agent-bg (auto-uniquified if taken).
                            Stores the session name in a temp file for later use.
  window <name>             Create a new window inside the session.
  split [target]            Split the target window/pane (default last active).
                            Use -h or -v in args to control direction.
  run <target> <cmd...>     Send a shell command to a target pane/window.
                            Target syntax: [session:][window].[pane]
  capture [target]          Capture and print the contents of a pane.
  list                      List windows and panes in the session.
  ls                        Alias for list.
  kill                      Kill the session and clean up state file.
  attach                    Attach to the session (for human debugging).
  session                   Print the currently tracked session name.
  wait-port <host> <port> [timeout]  Wait until a TCP port is open (default timeout 30s).
  health <url> [timeout]    Poll a HTTP endpoint until it returns 2xx (default timeout 30s).

Examples:
  pi_tmux init
  pi_tmux window build
  pi_tmux split build -h
  pi_tmux run build.0 "npm run build"
  pi_tmux capture build.0
  pi_tmux list
  pi_tmux kill
EOF
}

resolve_target() {
    local session="$1"
    local raw="$2"
    if [[ "$raw" == *":"* ]]; then
        echo "$raw"
    elif [[ "$raw" == "$session" ]]; then
        echo "$session"
    else
        echo "$session:$raw"
    fi
}

get_session() {
    if [[ -f "$SESSION_FILE" ]]; then
        cat "$SESSION_FILE"
    else
        # fallback
        local candidate
        candidate=$(tmux list-sessions -F '#S' 2>/dev/null | grep '^pi-agent-bg' | head -n 1 || true)
        if [[ -n "$candidate" ]]; then
            echo "$candidate" > "$SESSION_FILE"
            echo "$candidate"
        else
            echo "$DEFAULT_SESSION"
        fi
    fi
}

_cmd_init() {
    local name="${1:-$DEFAULT_SESSION}"
    # Uniquify if needed
    local orig_name="$name"
    while tmux has-session -t "$name" 2>/dev/null; do
        local suffix
        # Try openssl first, fallback to date/cut
        if command -v openssl >/dev/null 2>&1; then
            suffix=$(openssl rand -hex 2 2>/dev/null || true)
        fi
        if [[ -z "${suffix:-}" ]]; then
            suffix="$(date +%s | tail -c 5)"
        fi
        name="$orig_name-$suffix"
        # safety break
        if [[ "$name" == "$orig_name-"*"$orig_name"* ]]; then
            echo "ERROR: Could not generate a unique session name" >&2
            return 1
        fi
    done

    tmux new-session -d -s "$name" -n "main"
    echo "$name" > "$SESSION_FILE"
    echo "Created tmux session: $name"
}

_cmd_window() {
    local session
    session=$(get_session)
    local win_name="${1:-task}"
    tmux new-window -t "$session" -n "$win_name"
    echo "Created window '$win_name' in session '$session'"
}

_cmd_split() {
    local session
    session=$(get_session)
    local target
    if [[ $# -gt 0 ]]; then
        # user passed target and maybe flags
        # heuristic: if first arg doesn't start with - it's a target
        if [[ "$1" != -* ]]; then
            target="$1"
            shift
        else
            target="$session"
        fi
    else
        target="$session"
    fi
    local resolved
    resolved=$(resolve_target "$session" "$target")
    tmux split-window -t "$resolved" -d "$@" || true
    echo "Split pane in target '$resolved'"
}

_cmd_run() {
    local session
    session=$(get_session)
    local target="$1"
    shift
    tmux send-keys -t "$session:$target" "$*" Enter
    echo "Sent command to $session:$target"
}

_cmd_capture() {
    local session
    session=$(get_session)
    local target="${1:-$session}"
    local resolved
    resolved=$(resolve_target "$session" "$target")
    # default to full history capture if supported, else regular
    if tmux capture-pane -t "$resolved" -pS - 2>/dev/null; then
        return 0
    fi
    tmux capture-pane -t "$resolved" -p
}

_cmd_list() {
    local session
    session=$(get_session)
    # lists all panes in the tracked session (-s = session target) with a readable format
    tmux list-panes -s -t "$session" -F '#{session_name}:#{window_index}.#{pane_index}  wname=#{window_name}  cmd=[#{pane_current_command}]  title=#{pane_title}  pid=#{pane_pid}' 2>/dev/null || {
        echo "Session '$session' not found or has no panes."
        return 1
    }
}

_cmd_kill() {
    local session
    session=$(get_session)
    if tmux has-session -t "$session" 2>/dev/null; then
        tmux kill-session -t "$session"
    fi
    rm -f "$SESSION_FILE"
    echo "Killed session '$session'"
}

_cmd_attach() {
    local session
    session=$(get_session)
    echo "Run this in your terminal to attach:"
    echo "  tmux attach -t $session"
}

_cmd_session() {
    get_session
}

_cmd_wait_port() {
    local host="${1:-127.0.0.1}"
    local port="${2:-}"
    local timeout="${3:-30}"
    if [[ -z "$port" ]]; then
        echo "Usage: wait-port <host> <port> [timeout]" >&2
        return 1
    fi
    local start
    start=$(date +%s)
    while ! nc -z "$host" "$port" 2>/dev/null; do
        if (( $(date +%s) - start > timeout )); then
            echo "Timeout: port $host:$port not ready after ${timeout}s" >&2
            return 1
        fi
        sleep 1
    done
    echo "Port $host:$port is ready"
}

_cmd_health() {
    local url="${1:-}"
    local timeout="${2:-30}"
    if [[ -z "$url" ]]; then
        echo "Usage: health <url> [timeout]" >&2
        return 1
    fi
    local start
    start=$(date +%s)
    while true; do
        local http_code
        http_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || true)
        if [[ "$http_code" =~ ^2 ]]; then
            echo "Endpoint $url is healthy (HTTP $http_code)"
            return 0
        fi
        if (( $(date +%s) - start > timeout )); then
            echo "Timeout: $url did not return 2xx within ${timeout}s (last HTTP $http_code)" >&2
            return 1
        fi
        sleep 1
    done
}

pi_tmux() {
    local cmd="${1:-}"
    shift || true

    case "$cmd" in
        init)      _cmd_init "$@" ;;
        window)    _cmd_window "$@" ;;
        split)     _cmd_split "$@" ;;
        run)       _cmd_run "$@" ;;
        capture)   _cmd_capture "$@" ;;
        list|ls)   _cmd_list ;;
        kill)      _cmd_kill ;;
        attach)    _cmd_attach ;;
        session)   _cmd_session ;;
        wait-port) _cmd_wait_port "$@" ;;
        health)    _cmd_health "$@" ;;
        --help|-h|help) usage ;;
        *) usage; return 1 ;;
    esac
}

# Execute main only when run directly; when sourced, restore caller options.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    pi_tmux "$@"
else
    # Restore any options we changed so sourcing does not alter the caller shell.
    [[ "$__pi_tmux_old_opts" == *e* ]] || set +e
    [[ "$__pi_tmux_old_opts" == *u* ]] || set +u
    [[ "$__pi_tmux_old_pipefail" == 1 ]] || set +o pipefail
fi
