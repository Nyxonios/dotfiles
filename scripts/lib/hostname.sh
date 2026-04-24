#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

DEFAULT_HOSTNAME="mimir"

show_usage() {
    cat << EOF
Usage: $(basename "$0") [HOSTNAME]

Set the system hostname and update /etc/hosts.

Arguments:
  HOSTNAME    The hostname to set (default: $DEFAULT_HOSTNAME)

Options:
  -h, --help  Show this help message

Examples:
  $(basename "$0")              # Set hostname to $DEFAULT_HOSTNAME
  $(basename "$0") myhost       # Set hostname to myhost

Note: On NixOS, this will print instructions for manual configuration.
EOF
}

configure_hostname() {
    local target_hostname="${1:-$DEFAULT_HOSTNAME}"
    
    log_info "Setting hostname to ${target_hostname}..."
    
    if command -v nixos-rebuild &> /dev/null; then
        log_info "NixOS detected - please manually update /etc/nixos/configuration.nix:"
        echo "  networking.hostName = \"${target_hostname}\";"
        echo "Then run: sudo nixos-rebuild switch"
    else
        echo "$target_hostname" | sudo tee /etc/hostname > /dev/null
        
        if ! grep -q "$target_hostname" /etc/hosts 2>/dev/null; then
            echo "127.0.0.1 $target_hostname" | sudo tee -a /etc/hosts > /dev/null
        fi
        
        sudo hostname "$target_hostname"
    fi
    
    log_info "Hostname set to: $(hostname)"
}

main() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    configure_hostname "$@"
}

main "$@"
