#!/bin/sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [HOST]

Fix Ghostty terminal compatibility by either:
1. Copying Ghostty's terminfo entry to a remote host (requires SSH access)
2. Configuring local SSH to fallback to xterm-256color

Arguments:
  HOST          Remote host to copy terminfo to (user@hostname)
                If not provided, configures local SSH fallback

Options:
  -h, --help    Show this help message
  --local       Configure local SSH fallback instead of copying terminfo

Examples:
  $(basename "$0") root@192.168.1.100     # Copy terminfo to remote
  $(basename "$0") --local                 # Configure local SSH fallback
  $(basename "$0") -h                      # Show help

Note: Copying terminfo requires OpenSSH 8.7+ for SetEnv support.
EOF
}

copy_terminfo_to_remote() {
    local host="$1"
    
    log_info "Copying Ghostty terminfo entry to $host..."
    
    if ! command -v infocmp &> /dev/null; then
        log_error "infocmp not found. Install ncurses-bin package."
        exit 1
    fi
    
    infocmp -x xterm-ghostty | ssh "$host" -- tic -x - || {
        log_error "Failed to copy terminfo. Ensure remote has tic installed."
        exit 1
    }
    
    log_info "Ghostty terminfo copied successfully to $host"
}

configure_ssh_fallback() {
    log_info "Configuring SSH to fallback to xterm-256color..."
    
    local ssh_config="$HOME/.ssh/config"
    
    if [[ ! -f "$ssh_config" ]]; then
        log_warn "Creating $ssh_config"
        mkdir -p "$HOME/.ssh"
        touch "$ssh_config"
        chmod 600 "$ssh_config"
    fi
    
    if ! grep -q "SetEnv TERM=xterm-256color" "$ssh_config" 2>/dev/null; then
        cat >> "$ssh_config" << 'EOF'

# Ghostty terminal fallback
# Uncomment the following line to use xterm-256color on all hosts
# Host *
#   SetEnv TERM=xterm-256color
EOF
        log_info "Added SSH fallback configuration to $ssh_config"
        log_info "Edit the file and uncomment the lines to enable"
    else
        log_info "SSH fallback already configured"
    fi
}

configure_shell_ghostty_fix() {
    log_info "Configuring shell to override TERM for Ghostty..."
    
    local fix_snippet='
# Ghostty terminal compatibility - set TERM to xterm-256color for SSH
if [[ "$TERM" == "xterm-ghostty" ]]; then
    export TERM=xterm-256color
fi
'
    
    for rcfile in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [[ -f "$rcfile" ]] || continue
        if ! grep -q "xterm-ghostty" "$rcfile" 2>/dev/null; then
            echo "$fix_snippet" >> "$rcfile"
            log_info "Added Ghostty fix to $rcfile"
        fi
    done
}

main() {
    local use_local=0
    local host=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            --local)
                use_local=1
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                host="$1"
                shift
                ;;
        esac
    done
    
    if [[ -n "$host" && $use_local -eq 1 ]]; then
        log_error "Cannot use --local with a host argument"
        show_usage
        exit 1
    fi
    
    if [[ -n "$host" ]]; then
        copy_terminfo_to_remote "$host"
    elif [[ $use_local -eq 1 ]]; then
        configure_ssh_fallback
    else
        configure_shell_ghostty_fix
        log_info "Ghostty shell fix configured"
        log_info "For better compatibility, consider:"
        log_info "  1. Run: $(basename "$0") user@remote-host  # Copy terminfo to remote"
        log_info "  2. Run: $(basename "$0") --local           # Configure SSH fallback"
    fi
}

main "$@"
