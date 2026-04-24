#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

SSH_DIR="$HOME/.ssh"

show_usage() {
    cat << EOF
Usage: $(basename "$0") HOST ALIAS

Add an SSH config entry for easy connection to a remote host.

Arguments:
  HOST    Remote host (user@hostname or hostname)
  ALIAS   Short alias to use for connecting (e.g., 'mimir')

Options:
  -h, --help    Show this help message

Example:
  $(basename "$0") root@192.168.1.100 mimir

After running, you can connect with: ssh mimir
EOF
}

add_ssh_config_entry() {
    local host="$1"
    local target_hostname="$2"
    
    local user
    local remote_host
    
    if [[ "$host" =~ @ ]]; then
        user="${host%%@*}"
        remote_host="${host#*@}"
    else
        user="$USER"
        remote_host="$host"
    fi
    
    local config_entry="
Host ${target_hostname}
    HostName ${remote_host}
    User ${user}
    IdentityFile ~/.ssh/id_ed25519_personal
    IdentitiesOnly yes
    AddKeysToAgent yes
"
    
    if [[ -f "$SSH_DIR/config" ]]; then
        if grep -q "^Host ${target_hostname}$" "$SSH_DIR/config" 2>/dev/null; then
            log_warn "SSH config entry for '${target_hostname}' already exists"
            return
        fi
    fi
    
    echo "$config_entry" >> "$SSH_DIR/config"
    chmod 600 "$SSH_DIR/config"
    log_info "Added SSH config entry for '${target_hostname}'"
    log_info "You can now connect with: ssh ${target_hostname}"
}

main() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    if [[ $# -lt 2 ]]; then
        log_error "Missing arguments: HOST and ALIAS required"
        show_usage
        exit 1
    fi
    
    add_ssh_config_entry "$@"
}

main "$@"
