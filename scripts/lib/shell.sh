#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

DEFAULT_SHELL="/run/current-system/sw/bin/zsh"

show_usage() {
    cat << EOF
Usage: $(basename "$0") [SHELL_PATH]

Change the default login shell for the current user.

Arguments:
  SHELL_PATH    Path to the shell (default: $DEFAULT_SHELL)

Options:
  -h, --help    Show this help message

Examples:
  $(basename "$0")              # Change to zsh (default)
  $(basename "$0") /bin/bash    # Change to bash
  $(basename "$0") /usr/bin/fish # Change to fish

Note: You will need to log out and back in for changes to take effect.
EOF
}

detect_package_manager() {
    if command -v nix-env &> /dev/null; then
        echo "nix"
    elif command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

install_shell() {
    local shell_path="$1"
    local shell_name
    shell_name="$(basename "$shell_path")"
    
    if command -v "$shell_name" &> /dev/null; then
        log_info "$shell_name is already installed"
        return 0
    fi
    
    log_info "$shell_name not found. Attempting to install..."
    
    local pkg_manager
    pkg_manager="$(detect_package_manager)"
    
    case "$pkg_manager" in
        nix)
            log_info "Installing $shell_name with nix..."
            nix-env -iA nixpkgs."$shell_name" || {
                log_warn "Could not install with nix-env. You may need to add it to your configuration.nix"
                return 1
            }
            ;;
        apt)
            sudo apt-get update && sudo apt-get install -y "$shell_name"
            ;;
        yum)
            sudo yum install -y "$shell_name"
            ;;
        dnf)
            sudo dnf install -y "$shell_name"
            ;;
        pacman)
            sudo pacman -S --noconfirm "$shell_name"
            ;;
        *)
            log_error "Could not detect package manager. Please install $shell_name manually."
            return 1
            ;;
    esac
    
    log_info "$shell_name installed successfully"
}

verify_shell_exists() {
    local shell_path="$1"
    
    if [[ ! -f "$shell_path" ]]; then
        log_error "Shell not found: $shell_path"
        log_info "Available shells:"
        cat /etc/shells 2>/dev/null || log_warn "Could not read /etc/shells"
        return 1
    fi
    
    if [[ ! -x "$shell_path" ]]; then
        log_error "Shell is not executable: $shell_path"
        return 1
    fi
}

add_shell_to_etc_shells() {
    local shell_path="$1"
    
    if ! grep -q "^${shell_path}$" /etc/shells 2>/dev/null; then
        log_info "Adding $shell_path to /etc/shells"
        echo "$shell_path" | sudo tee -a /etc/shells > /dev/null
    fi
}

change_default_shell() {
    local shell_path="$1"
    local current_shell
    current_shell="$(getent passwd "$USER" | cut -d: -f7)"
    
    if [[ "$current_shell" == "$shell_path" ]]; then
        log_info "Default shell is already $shell_path"
        return 0
    fi
    
    log_info "Changing default shell from $current_shell to $shell_path..."
    
    if ! command -v chsh &> /dev/null; then
        log_error "chsh command not found. Cannot change shell."
        return 1
    fi
    
    echo "$shell_path" | chsh -s "$shell_path" || {
        log_error "Failed to change shell. You may need to run this interactively."
        return 1
    }
    
    log_info "Default shell changed to $shell_path"
    log_info "Log out and log back in for changes to take effect"
}

main() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    local target_shell="${1:-$DEFAULT_SHELL}"
    
    check_not_root
    
    log_info "Configuring shell: $target_shell"
    
    install_shell "$target_shell" || log_warn "Continuing without installing shell"
    
    verify_shell_exists "$target_shell" || exit 1
    
    add_shell_to_etc_shells "$target_shell"
    
    change_default_shell "$target_shell"
    
    log_info "Shell configuration complete"
}

main "$@"
