#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

SSH_DIR="$HOME/.ssh"
PRIVATE_KEY="$SSH_DIR/id_ed25519_personal"

show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Configure SSH permissions, start ssh-agent, and add keys.
Also configures shell files for automatic ssh-agent setup.

Options:
  -h, --help    Show this help message

Actions:
  - Set ~/.ssh directory permissions to 700
  - Set private key permissions to 600
  - Set public key permissions to 644
  - Start ssh-agent if not running
  - Add ~/.ssh/id_ed25519_personal to agent
  - Configure shell rc files for auto ssh-agent

Example:
  $(basename "$0")
EOF
}

configure_ssh_permissions() {
    log_info "Configuring SSH permissions..."
    
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    
    for file in "$SSH_DIR"/id_* "$SSH_DIR"/authorized_keys "$SSH_DIR"/config; do
        [[ -f "$file" && ! "$file" =~ \.pub$ ]] && chmod 600 "$file"
    done
    
    for file in "$SSH_DIR"/*.pub "$SSH_DIR"/known_hosts; do
        [[ -f "$file" ]] && chmod 644 "$file"
    done
    
    log_info "SSH permissions configured"
}

configure_ssh_agent() {
    log_info "Configuring SSH agent..."
    
    if ! pgrep -u "$USER" ssh-agent > /dev/null; then
        eval "$(ssh-agent -s)"
    fi
    
    if [[ -f "$PRIVATE_KEY" ]]; then
        ssh-add "$PRIVATE_KEY" 2>/dev/null || log_warn "Could not add key (may need passphrase)"
    else
        log_warn "No private key found at $PRIVATE_KEY"
    fi
}

configure_shell_ssh() {
    log_info "Configuring shell for SSH agent..."
    
    local agent_snippet='
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null 2>&1
fi
ssh-add -l > /dev/null 2>&1 || ssh-add ~/.ssh/id_ed25519_personal 2>/dev/null
'
    
    for rcfile in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [[ -f "$rcfile" ]] || continue
        if ! grep -q "SSH_AUTH_SOCK" "$rcfile" 2>/dev/null; then
            echo "$agent_snippet" >> "$rcfile"
            log_info "Added SSH agent config to $rcfile"
        fi
    done
}

main() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    check_not_root
    
    configure_ssh_permissions
    configure_ssh_agent
    configure_shell_ssh
    
    log_info "SSH configuration complete"
}

main "$@"
