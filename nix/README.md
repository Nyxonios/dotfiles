# Nix Configuration (Wimpysworld Style)

A Nix Flake managing NixOS, macOS (nix-darwin), and Home Manager configurations across all systems from a single repo.

**Inspired by [wimpysworld/nix-config](https://github.com/wimpysworld/nix-config)** - Uses the "broadcast-and-gate" pattern where every module is imported everywhere and decides internally whether to activate based on host metadata.

## Naming Convention

Hosts are named after **mythological figures**:
- **Work machines** use **Greek mythology**
- **Personal machines** use **Norse mythology**

| Hostname       | Mythology | Figure     | Domain                        | Description            |
|----------------|-----------|------------|-------------------------------|------------------------|
| `athena`       | Greek     | Athena     | Wisdom, Warfare, Crafts       | Work MacBook Pro       |
| `hephaestus`   | Greek     | Hephaestus | Fire, Metalworking, Craftsmen | Work Development VM    |
| `mimir`        | Norse     | Mimir      | Wisdom, Knowledge             | Personal Development VM |
| `odin`         | Norse     | Odin       | Wisdom, Poetry, War           | Personal NixOS Desktop |

## Structure

```
.
├── lib/
│   └── default.nix              # Module system helpers
├── pkgs/
│   └── default.nix              # Custom local packages
├── platforms/
│   ├── common/
│   │   └── default.nix          # Shared NixOS/Darwin configuration
│   ├── darwin/
│   │   ├── default.nix          # Darwin entry point
│   │   └── _mixins/             # Self-gating macOS modules
│   │       ├── desktop/
│   │       ├── services/
│   │       └── system/
│   ├── home-manager/
│   │   ├── default.nix          # Home Manager entry point
│   │   └── _mixins/             # Self-gating user modules
│   │       ├── desktop/
│   │       ├── development/
│   │       ├── services/
│   │       └── terminal/
│   └── nixos/
│       ├── default.nix          # NixOS entry point
│       └── _mixins/             # Self-gating NixOS modules
│           ├── desktop/
│           ├── hardware/
│           ├── network/
│           ├── services/
│           ├── system/
│           └── users/
├── secrets/                     # Encrypted secrets (sops-nix)
│   ├── .sops.yaml              # SOPS key configuration
│   └── secrets.yaml            # General secrets
├── systems.toml                 # Host definitions and metadata
├── hosts/
│   ├── athena/                  # Work MacBook Pro (Greek: Goddess of wisdom)
│   ├── hephaestus/              # Work VM (Greek: God of fire and craftsmen)
│   ├── mimir/                   # Personal VM (Norse: God of wisdom)
│   └── odin/                    # Personal Desktop (Norse: Allfather)
├── overlays/
│   └── default.nix              # Package overlays
├── flake.nix                    # Main flake configuration
└── justfile                     # Convenience commands
```

## How It Works

### The "Broadcast-and-Gate" Pattern

Most Nix configurations use **selective imports** - each host cherry-picks which modules to include. This configuration does the opposite.

**Every module is imported by every host.** Modules decide *internally* whether to activate, based on typed host metadata from the registry.

```nix
# Example self-gating module
{ config, lib, host, ... }:

let
  # Desktop is derived from formFactor
  isDesktop = lib.isDesktop (host.formFactor or "");
in
lib.mkIf (isDesktop && host.platform == "nixos") {
  # This config only applies to NixOS desktop systems
  services.displayManager.gdm.enable = true;
}
```

### System Registry

All hosts are defined in `systems.toml` (at the root) with their properties. The **section name** (e.g., `[athena]`, `[odin]`) becomes the host's `name` and is used as the hostname.

```toml
[athena]                    # Host name - used as hostname
platform = "darwin"
system = "aarch64-darwin"
username = "nyxonios"
formFactor = "laptop"
gpu = ["apple"]
tags = ["work", "development"]
description = "Work MacBook Pro - Athena: Greek goddess of wisdom, warfare, and crafts"

[odin]                      # Host name - used as hostname
platform = "nixos"
system = "x86_64-linux"
username = "nyxonios"
formFactor = "desktop"
gpu = ["nvidia"]
tags = ["personal", "gaming", "development"]
description = "Personal NixOS Desktop - Odin: Norse Allfather, god of wisdom, poetry, and war"
```

**Note:** The `desktop` property is automatically derived from `formFactor`. A system is considered a desktop if `formFactor` is "laptop" or "desktop".

### Benefits

1. **Adding a new feature**: Drop a directory containing a self-gating module. No import lists to edit.
2. **Adding a new host**: Add entry to registry + hardware config. That's it.
3. **Host-specific directories** only contain hardware: disk layouts, kernel modules.
4. **All behavior lives in self-gating modules** reacting to host properties.

## Platforms

The configuration supports three distinct platforms, each with different capabilities and use cases:

### NixOS (`platforms/nixos/`)

**Use when:** You have a machine running NixOS (a Linux distribution built on Nix).

**What it does:**
- Manages the entire operating system (kernel, systemd services, system packages)
- Handles hardware drivers, bootloaders, and system configuration
- Integrates with Home Manager for user environments
- Provides system-level services (printing, networking, display managers)

**Best for:**
- Bare metal desktops and laptops
- VMs where you control the entire OS
- Servers
- Your primary development machine

**Examples in this repo:** `odin` - Personal NixOS Desktop

### Darwin (`platforms/darwin/`)

**Use when:** You have a Mac running macOS with nix-darwin.

**What it does:**
- Manages macOS system settings and preferences
- Installs Homebrew packages and casks
- Configures macOS-specific features (dock, Finder, launchd services)
- Integrates with Home Manager for user environments

**Best for:**
- MacBook Pro/Air laptops
- Mac Studio/Mac Pro workstations
- Any macOS machine where you want declarative configuration

**Examples in this repo:** `athena` - Work MacBook Pro

### Home Manager (Standalone) (`platforms/home-manager/`)

**Use when:** You want to manage user configuration on a system you don't fully control, or alongside an existing OS.

**What it does:**
- Manages user dotfiles and application configurations
- Installs user packages (not system-wide)
- Provides per-user application settings
- Can run on NixOS, macOS, or any Linux distribution

**Best for:**
- Development VMs on corporate/work machines
- Remote servers where you only have user access
- Systems running another Linux distribution (Ubuntu, Fedora, etc.)
- Testing configurations without affecting the system
- Secondary machines where full NixOS isn't practical

**Examples in this repo:** `hephaestus` - Work Development VM, `mimir` - Personal Development VM

### Common (`platforms/common/`)

**Not a platform itself, but shared configuration.**

**What it does:**
- Contains settings that apply to BOTH NixOS and Darwin
- Manages overlays, fonts, Nix settings, shell configuration
- Shared packages (git, just, sops)
- Common user settings (zsh as default shell)

**This is imported by all NixOS and Darwin hosts automatically.**

### When to Choose Each Platform

| Scenario | Recommended Platform |
|----------|---------------------|
| MacBook Pro/Air | **Darwin** |
| Bare metal Linux desktop/laptop | **NixOS** |
| VM on cloud provider | **NixOS** (full control) |
| VM on corporate Mac | **Home Manager** (standalone) |
| Remote server you don't admin | **Home Manager** (standalone) |
| Ubuntu/Debian laptop with Nix | **Home Manager** (standalone) |
| Testing new configurations | **Home Manager** (standalone) |

## Hosts

### Work Machines (Greek Mythology)

| Hostname | Platform | Type | GPU | Description |
|----------|----------|------|-----|-------------|
| `athena` | Darwin | Laptop | Apple | MacBook Pro - Athena: Goddess of wisdom, warfare, and crafts |
| `hephaestus` | Home Manager | VM | - | Development VM - Hephaestus: God of fire, metalworking, and craftsmen |

### Personal Machines (Norse Mythology)

| Hostname | Platform | Type | GPU | Description |
|----------|----------|------|-----|-------------|
| `mimir` | Home Manager | VM | - | Development VM - Mimir: God of wisdom and knowledge, guardian of the Well of Wisdom |
| `odin` | NixOS | Desktop | NVIDIA | NixOS Desktop - Odin: Allfather, god of wisdom, poetry, and war |

## Usage

### Development Shell

A development shell is available with all necessary tools:

```bash
# Enter the development shell
nix develop

# The shell automatically:
# - Installs git pre-commit hooks
# - Provides sops, age, ssh-to-age tools
# - Sets up the environment
```

### Building & Switching

```bash
# Show all available commands
just

# Show mythology host reference
just hosts

# Build and switch host configuration
just host

# Build and switch home configuration
just home

# Build and switch both
just switch

# Only build (don't switch)
just build
```

### Platform-Specific

**macOS (Darwin) - athena:**
```bash
just switch-host athena
just switch-home athena
```

**NixOS - odin:**
```bash
just switch-host odin
just switch-home odin
```

**Home Manager (standalone) - hephaestus:**
```bash
just switch-home hephaestus
```

### Maintenance

```bash
# Update flake inputs
just update

# Garbage collect
just gc

# Optimize store
just optimise

# Format all nix files
just fmt

# Check flake
just check

# Show flake outputs
just show

# Show host mythology reference
just hosts
```

## Adding a New Host

1. **Add to registry** (`systems.toml`):
```toml
[zeus]
platform = "nixos"  # or "darwin" or "home-manager"
system = "x86_64-linux"
username = "nyxonios"
home = "/home/nyxonios"
email = "you@example.com"
formFactor = "laptop"  # "laptop", "desktop", or "vm"
gpu = ["nvidia"]
tags = ["work", "development"]
description = "Work Laptop - Zeus: Greek god of the sky, thunder, and justice"
```

2. **Create host directory** (`hosts/zeus/`):
   - Copy from existing similar host
   - Adjust hardware configuration
   - Keep only hardware-specific settings (disks, kernel modules)

3. **Build and switch**:
```bash
just switch-host zeus
```

## Adding a New Module

Create a self-gating module in the appropriate `_mixins` directory:

```nix
# platforms/nixos/_mixins/desktop/my-feature.nix
{ config, lib, host, ... }:

let
  # Define activation conditions
  isDesktop = lib.isDesktop (host.formFactor or "");
  shouldEnable = isDesktop && builtins.elem "mytag" host.tags;
in
{
  config = lib.mkIf shouldEnable {
    # Your configuration here
    services.my-feature.enable = true;
  };
}
```

Add to the parent `default.nix`:

```nix
# platforms/nixos/_mixins/desktop/default.nix
{ ... }:
{
  imports = [
    ./my-feature.nix  # Add here
  ];
}
```

## Available Conditions

Use these helpers from `lib/default.nix`:

### Host Properties
- `host.platform` - "nixos", "darwin", or "home-manager"
- `host.system` - "x86_64-linux", "aarch64-darwin", etc.
- `host.username` - Username
- `host.home` - Home directory path
- `host.email` - Email address
- `host.formFactor` - "laptop", "desktop", "vm"
- `host.gpu` - List of GPUs: ["nvidia"], ["amd"], ["intel"], ["apple"]
- `host.tags` - List of arbitrary tags
- `host.description` - Human-readable description

### Helper Functions
- `lib.isDesktop formFactor` - Returns true if formFactor is "laptop" or "desktop"
- `lib.hasTag host tag` - Check if host has a specific tag
- `lib.isFormFactor host factor` - Check if host matches a form factor
- `lib.mkIfDesktop config host` - Wrapper for desktop-only config
- `lib.mkIfPlatform platform config host` - Wrapper for platform-specific config
- `lib.mkIfTag tag config host` - Wrapper for tag-based config
- `lib.mkIfGPU vendor config host` - Wrapper for GPU-specific config

## Secrets Management with sops-nix

This configuration uses [sops-nix](https://github.com/Mic92/sops-nix) for secure secret management. Secrets are encrypted with [age](https://github.com/FiloSottile/age) keys and decrypted during system activation.

### Quick Start

1. **Generate your user age key** (run on your development machine):
   ```bash
   just sops-gen-user-key
   ```

2. **Add your public key to `.sops.yaml`**:
   ```bash
   # Copy the public key from the output above
   # Edit secrets/.sops.yaml and replace PLACEHOLDER_USER_AGE_KEY
   ```

3. **On your NixOS host, generate a host key**:
   ```bash
   just sops-gen-host-key
   ```

4. **Add the host public key to `.sops.yaml`**

5. **Rekey existing secrets** (if any):
   ```bash
   just sops-rekey
   ```

The git pre-commit hook is automatically installed when you run `just switch` or enter the development shell with `nix develop`.

### File Structure

```
secrets/
├── .sops.yaml          # Key configuration and creation rules
├── secrets.yaml        # General secrets (API keys, tokens)
└── host-<hostname>.yaml # Per-host secrets (SSH keys)
```

**Important:** See `secrets/README.md` for detailed security guidelines on what to commit and where to place private keys.

### Available Just Commands

- `just secrets` - Edit the main secrets file
- `just sops-edit <file>` - Edit a specific secrets file
- `just sops-check` - Verify sops setup is complete
- `just sops-gen-user-key` - Generate user age key
- `just sops-gen-host-key` - Generate host age key
- `just sops-rekey` - Rekey all secrets after updating keys
- `just sops-view <file> [key]` - View decrypted secrets
- `just install-git-hooks` - Install pre-commit hook

### Git Pre-commit Hook

A pre-commit hook is provided to prevent accidentally committing unencrypted secrets. It checks all files in `secrets/` and aborts the commit if any unencrypted files are found.

**Automatic Installation:**

The hook is automatically installed in two ways:

1. **Home Manager activation** - When you run `just switch` or `just switch-home`, the hook is automatically installed/updated
2. **Development shell** - When you enter `nix develop`, the hook is installed in the current shell

**Manual Installation:**

If you need to install it manually:
```bash
just install-git-hooks
```

**Bypassing the Hook:**

To bypass (not recommended):
```bash
git commit --no-verify
```

### Adding New Secrets

1. Edit the secrets file:
   ```bash
   just secrets
   # or
   sops secrets/secrets.yaml
   ```

2. Add your secrets in YAML format:
   ```yaml
   my_api_key: secret_value_here
   database_password: another_secret
   ```

3. Save and exit - sops automatically encrypts the file

4. Stage and commit:
   ```bash
   git add secrets/secrets.yaml
   git commit -m "Add new API key"
   ```

### Using Secrets in NixOS Configuration

Secrets are configured in `platforms/nixos/_mixins/services/sops.nix`:

```nix
sops.secrets.my_api_key = {
  mode = "0400";
  owner = config.users.users.nyxonios.name;
  group = config.users.users.nyxonios.group;
};
```

Reference in services:
```nix
services.myservice = {
  enable = true;
  apiKeyFile = config.sops.secrets.my_api_key.path;
};
```

Secrets are available at `/run/secrets/my_api_key` after system activation.

### SSH Key Management

SSH keys can be automatically deployed to `~/.ssh/` on all NixOS hosts. See `secrets/SSH_KEYS.md` for detailed documentation.

**Quick Start:**

1. **Add existing SSH key to sops:**
   ```bash
   just ssh-add-key ~/.ssh/id_ed25519 personal
   ```

2. **Or generate a new key:**
   ```bash
   just ssh-gen-key personal ed25519
   ```

3. **Enable key deployment** in `platforms/nixos/_mixins/services/sops.nix`:
   ```nix
   sops.secrets.personal_ssh_private = {
     mode = "0600";
     owner = host.username;
     group = "users";
     path = "/home/${host.username}/.ssh/id_ed25519";
     sopsFile = ../secrets/ssh.yaml;
   };
   ```

4. **Rebuild to deploy:**
   ```bash
   just switch
   ```

The SSH key will be automatically placed in `~/.ssh/` with correct permissions.

## Notes

- **NixOS hardware configs** need to be generated with `sudo nixos-generate-config`
- **macOS** uses nix-homebrew for Homebrew packages
- **Dotfiles** are symlinked from `~/dotfiles/.config/` using `mkOutOfStoreSymlink`
- **Common configuration** is in `platforms/common/default.nix` and applies to both NixOS and Darwin
- **Custom packages** can be added to `pkgs/` directory
- **Overlays** follow the wimpysworld pattern with `localPackages`, `modifiedPackages`, etc.

## Credits

Inspired by [wimpysworld/nix-config](https://github.com/wimpysworld/nix-config) - "The deep end" of Nix configurations.
