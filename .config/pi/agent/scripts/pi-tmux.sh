#!/usr/bin/env bash
set -euo pipefail

# pi-tmux helper
SESSION_FILE="/tmp/.pi_agent_tmux_session"
DEFAULT_SESSION="pi-agent-bg"

pi_tmux() {
    local cmd="${1:-help}"
    case "$cmd" in
        init)
            local session="${2:-$DEFAULT_SESSION}"
            if tmux has-session -t "$session" 2>/dev/null; then
                echo "$session"
            else
                tmux new-session -d -s "$session" -n main
                echo "$session" > "$SESSION_FILE"
                echo "$session"
            fi
            ;;
        window)
            local session
            session=$(get_session)
            local win="${2:-new}"
            tmux new-window -t "$session" -n "$win" 2>/dev/null || true
            ;;
        run)
            local session
            session=$(get_session)
            local target="${2:-main.0}"
            local cmd="${3:-}"
            tmux send-keys -t "$session:$target" "$cmd" Enter
            ;;
        capture)
            local session
            session=$(get_session)
            local target="${2:-main.0}"
            tmux capture-pane -t "$session:$target" -p
            ;;
        list)
            local session
            session=$(get_session)
            tmux list-panes -s -t "$session" -F '#{window_index}.#{pane_index}  wname=#{window_name}  cmd=[#{pane_current_command}]  pid=#{pane_pid}'
            ;;
        kill)
            local session
            session=$(get_session)
            tmux kill-session -t "$session" 2>/dev/null || true
            rm -f "$SESSION_FILE"
            ;;
        *)
            echo "Usage: pi_tmux init|window|run|capture|list|kill"
            ;;
    esac
}

get_session() {
    if [[ -f "$SESSION_FILE" ]]; then
        cat "$SESSION_FILE"
    else
        echo "$DEFAULT_SESSION"
    fi
}

export -f pi_tmux get_session

# If executed directly, run the command
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    pi_tmux "$@"
fi
