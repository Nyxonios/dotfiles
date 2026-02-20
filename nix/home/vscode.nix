{ config, pkgs, ... }:
{
  enable = true;
  package = pkgs.vscode;

  profiles = {
    default = {

      userSettings = {
        "excalidraw.theme" = "auto";
      };

      # Extensions (plugins)
      extensions = with pkgs.vscode-extensions;
        [
          ms-vscode-remote.remote-ssh
        ] ++ (pkgs.vscode-utils.extensionsFromVscodeMarketplace [
          # For extensions not in Nixpkgs, use this to fetch from Marketplace
          {
            name = "excalidraw-editor"; # Example: GitHub Copilot
            publisher = "pomdtr";
            version = "3.9.0"; # Specify latest version
            sha256 = "sha256-DTmlHiMKnRUOEY8lsPe7JLASEAXmfqfUJdBkV0t08c0="; # Compute SHA via prefetch or tools
          }
        ]);
    };
  };
}

