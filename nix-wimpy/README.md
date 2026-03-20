# Nix Configuration (Wimpysworld Style)

A Nix Flake managing NixOS, macOS (nix-darwin), and Home Manager configurations across all systems from a single repo.

**Inspired by [wimpysworld/nix-config](https://github.com/wimpysworld/nix-config)** - Uses the "broadcast-and-gate" pattern where every module is imported everywhere and decides internally whether to activate based on host metadata.

## Naming Convention

Hosts are named after **mythological figures**:
- **Work machines** use **Greek mythology**
- **Personal machines** use **Norse mythology**

| Hostname | Mythology | Figure | Domain | Description |
|----------|-----------|--------|--------|-------------|
| `athena` | Greek | Athena | Wisdom, Warfare, Crafts | Work MacBook Pro |
| `hephaestus` | Greek | Hephaestus | Fire, Metalworking, Craftsmen | Work Development VM |
| `odin` | Norse | Odin | Wisdom, Poetry, War | Personal NixOS Desktop |

## Structure

```
.
├── lib/
│   └── default.nix              # Noughty module system helpers
├── systems.toml                 # Host definitions and metadata
├── darwin/
│   ├── default.nix              # Darwin entry point
│   └── _mixins/                 # Self-gating macOS modules
│       ├── desktop/
│       ├── services/
│       └── system/
├── nixos/
│   ├── default.nix              # NixOS entry point
│   └── _mixins/                 # Self-gating NixOS modules
│       ├── desktop/
│       ├── hardware/
│       ├── network/
│       ├── services/
│       └── users/
├── home-manager/
│   ├── default.nix              # Home Manager entry point
│   └── _mixins/                 # Self-gating user modules
│       ├── desktop/
│       ├── development/
│       ├── services/
│       └── terminal/
├── hosts/
│   ├── athena/                  # Work MacBook Pro (Greek: Goddess of wisdom)
│   ├── hephaestus/              # Work VM (Greek: God of fire and craftsmen)
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
lib.mkIf (host.desktop && host.platform == "nixos") {
  # This config only applies to NixOS desktop systems
  services.displayManager.gdm.enable = true;
}
```

### System Registry

All hosts are defined in `systems.toml` (at the root) with their properties:

```toml
[athena]
platform = "darwin"
system = "aarch64-darwin"
username = "nyxonios"
formFactor = "laptop"
desktop = true
gpu = ["apple"]
tags = ["work", "development"]
description = "Work MacBook Pro - Athena: Greek goddess of wisdom, warfare, and crafts"

[odin]
platform = "nixos"
system = "x86_64-linux"
username = "nyxonios"
formFactor = "desktop"
desktop = true
gpu = ["nvidia"]
tags = ["personal", "gaming", "development"]
description = "Personal NixOS Desktop - Odin: Norse Allfather, god of wisdom, poetry, and war"
```

### Benefits

1. **Adding a new feature**: Drop a directory containing a self-gating module. No import lists to edit.
2. **Adding a new host**: Add entry to registry + hardware config. That's it.
3. **Host-specific directories** only contain hardware: disk layouts, kernel modules.
4. **All behavior lives in self-gating modules** reacting to host properties.

## Hosts

### Work Machines (Greek Mythology)

| Hostname | Platform | Type | GPU | Description |
|----------|----------|------|-----|-------------|
| `athena` | Darwin | Laptop | Apple | MacBook Pro - Athena: Goddess of wisdom, warfare, and crafts |
| `hephaestus` | Home Manager | VM | - | Development VM - Hephaestus: God of fire, metalworking, and craftsmen |

### Personal Machines (Norse Mythology)

| Hostname | Platform | Type | GPU | Description |
|----------|----------|------|-----|-------------|
| `odin` | NixOS | Desktop | NVIDIA | NixOS Desktop - Odin: Allfather, god of wisdom, poetry, and war |

## Usage

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
formFactor = "laptop"
desktop = true
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
# nixos/_mixins/desktop/my-feature.nix
{ config, lib, host, ... }:

let
  # Define activation conditions
  shouldEnable = host.desktop && builtins.elem "mytag" host.tags;
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
# nixos/_mixins/desktop/default.nix
{ ... }:
{
  imports = [
    ./my-feature.nix  # Add here
  ];
}
```

## Available Conditions

Use these helpers from `lib/default.nix`:

- `host.platform` - "nixos", "darwin", or "home-manager"
- `host.system` - "x86_64-linux", "aarch64-darwin", etc.
- `host.username` - Username
- `host.home` - Home directory path
- `host.email` - Email address
- `host.formFactor` - "laptop", "desktop", "vm"
- `host.desktop` - true/false
- `host.gpu` - List of GPUs: ["nvidia"], ["amd"], ["intel"], ["apple"]
- `host.tags` - List of arbitrary tags
- `host.description` - Human-readable description

## Notes

- **NixOS hardware configs** need to be generated with `sudo nixos-generate-config`
- **macOS** uses nix-homebrew for Homebrew packages
- **Dotfiles** are symlinked from `~/dotfiles/.config/` using `mkOutOfStoreSymlink`
- The LSP errors in zsh.nix are false positives - the file is valid Nix

## Credits

Inspired by [wimpysworld/nix-config](https://github.com/wimpysworld/nix-config) - "The deep end" of Nix configurations.
