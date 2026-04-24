#!/bin/sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

source "$LIB_DIR/utils.sh"

REMOTE_HOST="${1:-}"
TARGET_HOSTNAME="${2:-mimir}"

show_usage() {
    cat << EOF
Usage: $0 [REMOTE_HOST] [HOSTNAME]

Bootstrap script for setting up a new VM.
Runs hostname, SSH, and Ghostty configuration in sequence.

Individual components can be run independently from the lib/ directory.

Arguments:
  REMOTE_HOST   SSH connection string for remote host (optional)
  HOSTNAME      Hostname to set (default: mimir)

Options:
  -h, --help    Show this help message

Examples:
  $0                          # Run locally, hostname=mimir
  $0 root@192.168.1.100       # Run on remote, hostname=mimir
  $0 root@192.168.1.100 zero  # Run on remote, hostname=zero

Individual components:
  ./lib/hostname.sh [HOSTNAME]
  ./lib/ssh.sh
  ./lib/ghostty.sh [user@host|--local]
  ./lib/ssh_config.sh HOST ALIAS
  ./lib/shell.sh [SHELL_PATH]
EOF
}

run_remote() {
    local host="$1"
    log_info "Connecting to remote host: $host"
    
    log_info "Copying bootstrap files to remote..."
    scp -r "$LIB_DIR" "${host}:/tmp/bootstrap_lib"
    scp "$SCRIPT_DIR/bootstrap.sh" "${host}:/tmp/bootstrap.sh"
    
    log_info "Running bootstrap on remote host..."
    ssh -t "$host" "chmod +x /tmp/bootstrap.sh && /tmp/bootstrap.sh"
    
    log_info "Remote bootstrap complete!"
    log_info "Adding remote host to local SSH config..."
    
    "$LIB_DIR/ssh_config.sh" "$host" "$TARGET_HOSTNAME"
    
    log_info "Copying Ghostty terminfo to remote..."
    "$LIB_DIR/ghostty.sh" "$host" || log_warn "Could not copy terminfo"
}

run_local() {
    log_info "Running bootstrap locally on: $(hostname)"
    
    check_not_root
    
    log_info "Step 1/4: Configuring hostname..."
    "$LIB_DIR/hostname.sh" "$TARGET_HOSTNAME"
    
    log_info "Step 2/4: Configuring SSH..."
    "$LIB_DIR/ssh.sh"
    
    log_info "Step 3/4: Configuring Ghostty fix..."
    "$LIB_DIR/ghostty.sh"
    
    log_info "Step 4/4: Configuring shell (zsh)..."
    "$LIB_DIR/shell.sh"
    
    echo ""
    echo "=== Verification ==="
    echo "Hostname: $(hostname)"
    echo "SSH Dir: $HOME/.ssh"
    echo "Default Shell: $(getent passwd "$USER" | cut -d: -f7)"
    ssh-add -l 2>/dev/null || log_warn "No keys in agent"
    
    log_info "Bootstrap complete!"
    log_info "Note: Log out and back in for shell change to take effect"
}

main() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    if [[ -n "$REMOTE_HOST" ]]; then
        run_remote "$REMOTE_HOST"
    else
        run_local
    fi
}

main "$@"
