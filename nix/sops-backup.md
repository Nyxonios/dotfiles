# SOPS-NIX Configuration Backup

This document preserves the sops-nix configuration that was removed.
To restore sops-nix support, reverse the changes described below.

## Files Modified

### 1. flake.nix

#### A. Add to inputs (around line 20):
```nix
sops-nix.url = "github:Mic92/sops-nix";
sops-nix.inputs.nixpkgs.follows = "nixpkgs";
```

#### B. Add to outputs parameters (line 24):
```nix
outputs = { self, nixpkgs, nixpkgs-stable, nix-darwin, nix-homebrew, home-manager, sops-nix, ... } @ inputs:
```

#### C. Add sops-nix module to nixosConfigurations (around line 75):
```nix
# sops-nix for secret management
sops-nix.nixosModules.sops
```

#### D. Add sops package to devShells (around line 191):
```nix
sops
age
ssh-to-age
```

#### E. Update shellHook (around line 202):
Add these lines:
```
echo "  just sops-check   - Check sops-nix setup"
echo "  just secrets      - Edit secrets"
```

### 2. platforms/common/default.nix

Add `sops` to system packages (around line 12):
```nix
environment.systemPackages = with pkgs; [
  git
  just
  sops
  jq
  yq
  fzf
  ripgrep
];
```

### 3. platforms/nixos/_mixins/services/default.nix

Add sops.nix to imports (around line 9):
```nix
imports = [
  ./printing.nix
  ./sops.nix
];
```

### 4. platforms/nixos/_mixins/services/sops.nix

Create this file with the full sops-nix configuration (see original content below).

## Original sops.nix Content

```nix
# SOPS-NIX Secret Management
# 
# This module configures sops-nix for atomic, declarative secret management.
# Secrets are decrypted during system activation and placed in /run/secrets/
#
# Usage:
# - Add secrets to secrets/secrets.yaml (encrypted with sops)
# - Define secrets in this module
# - Reference secrets in other modules via config.sops.secrets.<name>.path

{ config, lib, host, ... }:

let
  # Only enable on NixOS hosts (not on Darwin or standalone home-manager)
  isNixOS = host.platform == "nixos";

  # SSH directory for the user
  sshDir = "/home/${host.username}/.ssh";
in
{
  config = lib.mkIf isNixOS {
    # SOPS configuration
    sops = {
      # Use age for encryption (modern alternative to GPG)
      age = {
        # Path to the host's age private key
        # This key should be generated on the host with:
        #   sudo mkdir -p /var/lib/private/sops/age
        #   sudo age-keygen -o /var/lib/private/sops/age/keys.txt
        keyFile = "/var/lib/private/sops/age/keys.txt";

        # Don't generate a key automatically - we want to manage keys explicitly
        generateKey = false;

        # Disable SSH key scanning to avoid circular dependencies
        # We use the age keyFile directly instead
        sshKeyPaths = [ ];
      };

      # Disable GPG SSH key scanning for the same reason
      gnupg.sshKeyPaths = [ ];

      # Default secrets file for all secrets
      defaultSopsFile = ../secrets/secrets.yaml;

      # Secrets configuration
      secrets = {
        # Example secret:
        # example_api_key = {
        #   mode = "0400";
        #   owner = host.username;
        #   group = "users";
        # };

        # ============================================
        # SSH Keys - Automatically deployed to ~/.ssh/
        # ============================================
        # 
        # Add your SSH keys to secrets/ssh.yaml in the format:
        #   personal_private: |
        #     -----BEGIN OPENSSH PRIVATE KEY-----
        #     ...
        #     -----END OPENSSH PRIVATE KEY-----
        #   personal_public: ssh-ed25519 AAAAC3NzaC... comment
        #
        # Then uncomment and customize the entries below:

        # Personal SSH key (Ed25519) - Default key
        # personal_ssh_private = {
        #   mode = "0600";
        #   owner = host.username;
        #   group = "users";
        #   path = "${sshDir}/id_ed25519";
        #   sopsFile = ../secrets/ssh.yaml;
        # };
        # 
        # personal_ssh_public = {
        #   mode = "0644";
        #   owner = host.username;
        #   group = "users";
        #   path = "${sshDir}/id_ed25519.pub";
        #   sopsFile = ../secrets/ssh.yaml;
        # };

        # Work SSH key (RSA)
        # work_ssh_private = {
        #   mode = "0600";
        #   owner = host.username;
        #   group = "users";
        #   path = "${sshDir}/id_rsa_work";
        #   sopsFile = ../secrets/ssh.yaml;
        # };
        # 
        # work_ssh_public = {
        #   mode = "0644";
        #   owner = host.username;
        #   group = "users";
        #   path = "${sshDir}/id_rsa_work.pub";
        #   sopsFile = ../secrets/ssh.yaml;
        # };

        # GitHub/GitLab deploy key
        # deploy_ssh_private = {
        #   mode = "0600";
        #   owner = host.username;
        #   group = "users";
        #   path = "${sshDir}/id_deploy";
        #   sopsFile = ../secrets/ssh.yaml;
        # };
        # 
        # deploy_ssh_public = {
        #   mode = "0644";
        #   owner = host.username;
        #   group = "users";
        #   path = "${sshDir}/id_deploy.pub";
        #   sopsFile = ../secrets/ssh.yaml;
        # };

        # ============================================
        # Per-Host SSH Keys (host-specific access)
        # ============================================
        # These keys are only deployed to specific hosts
        # Uncomment and add to secrets/host-<hostname>.yaml

        # host_specific_ssh_private = lib.mkIf (host.name == "odin") {
        #   mode = "0600";
        #   owner = host.username;
        #   group = "users";
        #   path = "${sshDir}/id_host_specific";
        #   sopsFile = ../secrets/host-${host.name}.yaml;
        # };
      };

      # Templates allow embedding secrets in configuration files
      # templates = {
      #   "my-config.toml".content = ''
      #     api_key = "${config.sops.placeholder.example_api_key}"
      #   '';
      # };
    };

    # Ensure the .ssh directory exists with correct permissions
    # sops-nix creates the parent directories automatically, but we ensure
    # the .ssh directory has the correct permissions
    systemd.tmpfiles.rules = [
      "d ${sshDir} 0700 ${host.username} users -"
    ];

    # Ensure the sops directory exists with correct permissions
    # This is handled automatically by sops-nix, but we document it here
    # The directory /var/lib/private/sops/age should be:
    # - Owned by root
    # - Permissions 0750 (drwxr-x---)
    # The keys.txt file should be:
    # - Owned by root
    # - Permissions 0600 (-rw-------)
  };
}
```

## Secret Files

The following secret files exist in `nix/secrets/` and are preserved but not in use:
- `.sops.yaml` - SOPS configuration with age keys
- `secrets.yaml` - General secrets
- `ssh.yaml` - SSH keys

## Justfile Commands

These just commands may reference sops:
- `just sops-check` - Check sops-nix setup
- `just secrets` - Edit secrets

Check and update the justfile if needed.
