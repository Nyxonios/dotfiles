# VSCode Configuration
# Applies to NixOS desktop systems

{ config, pkgs, lib, host, customLib, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
  isNixOS = host.platform == "nixos";
  isDesktop = customLib.isDesktop (host.formFactor or "");
in
{
  config = lib.mkIf (isNixOS && isDesktop) {
    programs.vscode = {
      enable = true;
      package = pkgs.vscode;

      profiles = {
        default = {
          userSettings = {
            "excalidraw.theme" = "auto";
          };

          extensions = with pkgs.vscode-extensions; [
            ms-vscode-remote.remote-ssh
          ] ++ (pkgs.vscode-utils.extensionsFromVscodeMarketplace [
            {
              name = "excalidraw-editor";
              publisher = "pomdtr";
              version = "3.9.0";
              sha256 = "sha256-DTmlHiMKnRUOEY8lsPe7JLASEAXmfqfUJdBkV0t08c0=";
            }
          ]);
        };
      };
    };

    # Symlink VSCode config from dotfiles
    xdg.configFile.vscode.source = mkOutOfStoreSymlink "${host.home}/dotfiles/.config/vscode";
  };
}
