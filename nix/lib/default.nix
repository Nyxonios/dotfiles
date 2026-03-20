{ nixpkgs }:

let
  inherit (nixpkgs) lib;

  # Load and parse the TOML registry file
  # Automatically adds 'name' field from the TOML section name
  loadFromTOML = path: 
    let
      raw = builtins.fromTOML (builtins.readFile path);
    in
      lib.mapAttrs (sectionName: system: 
        system // { name = sectionName; }
      ) raw;

  # Filter hosts by type
  getNixOSHosts = systems:
    lib.filterAttrs (name: system: system.platform == "nixos") systems;

  getDarwinHosts = systems:
    lib.filterAttrs (name: system: system.platform == "darwin") systems;

  getHomeManagerHosts = systems:
    lib.filterAttrs (name: system: system.platform == "home-manager") systems;

  # Helper to check if a host has a specific tag
  hasTag = host: tag: builtins.elem tag (host.tags or [ ]);

  # Helper to check if a host matches a form factor
  isFormFactor = host: factor: host.formFactor or "" == factor;

  # Helper to check if a form factor represents a desktop system
  isDesktop = formFactor: formFactor == "laptop" || formFactor == "desktop";

in
{
  inherit loadFromTOML getNixOSHosts getDarwinHosts getHomeManagerHosts hasTag isFormFactor isDesktop;

  # Re-export lib functions we use
  inherit (lib) mapAttrs filterAttrs;

  # mkIf wrapper for self-gating modules
  mkIfHost = condition: config: lib.mkIf condition config;

  # mkIf wrapper for platform checks
  mkIfPlatform = platform: config: host: lib.mkIf (host.platform == platform) config;

  # mkIf wrapper for tag checks
  mkIfTag = tag: config: host: lib.mkIf (hasTag host tag) config;

  # mkIf wrapper for form factor checks
  mkIfFormFactor = factor: config: host: lib.mkIf (isFormFactor host factor) config;

  # mkIf wrapper for GPU checks
  mkIfGPU = vendor: config: host: lib.mkIf (builtins.elem vendor (host.gpu or [ ])) config;

  # mkIf wrapper for desktop checks
  mkIfDesktop = config: host: lib.mkIf (isDesktop (host.formFactor or "")) config;
}
