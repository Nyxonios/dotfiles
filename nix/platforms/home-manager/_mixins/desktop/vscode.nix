# VSCode Configuration
# Applies to all desktop systems

{ config, pkgs, lib, host, customLib, ... }:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;
in
{
  config = lib.mkIf (customLib.isDesktop (host.formFactor or "")) {
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
