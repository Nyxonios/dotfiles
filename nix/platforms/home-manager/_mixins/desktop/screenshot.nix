# Screenshot & Screen Recording Utilities
# grim + slurp + wl-clipboard for Wayland screenshots
# wf-recorder + libnotify for Wayland screen recording
# Self-gating: Only activates on NixOS desktop systems

{ config, pkgs, lib, host, customLib, ... }:

let
  isNixOS = host.platform == "nixos";
  isDesktop = customLib.isDesktop (host.formFactor or "");

  screenshot-region = pkgs.writeShellApplication {
    name = "screenshot-region";
    runtimeInputs = [ pkgs.grim pkgs.slurp pkgs.wl-clipboard ];
    text = ''
      timestamp=$(date +%Y%m%d-%H%M%S)
      output="$HOME/screenshot-$timestamp.png"
      grim -g "$(slurp)" "$output"
      wl-copy -t image/png < "$output"
      echo "Saved to $output"
    '';
  };

  screenshot-full = pkgs.writeShellApplication {
    name = "screenshot-full";
    runtimeInputs = [ pkgs.grim pkgs.wl-clipboard ];
    text = ''
      timestamp=$(date +%Y%m%d-%H%M%S)
      output="$HOME/screenshot-$timestamp.png"
      grim "$output"
      wl-copy -t image/png < "$output"
      echo "Saved to $output"
    '';
  };

  # wf-recorder avoids the HiDPI scaling issues that plague OBS when using the
  # XDG Desktop Portal for region selection (physical vs logical pixel mismatch).
  # These are toggle scripts: run once to start, run again to stop and save.
  mkScreenRecord = { name, useSlurp }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.wf-recorder pkgs.libnotify pkgs.procps ]
        ++ lib.optionals useSlurp [ pkgs.slurp ];
      text = ''
        statefile="/tmp/${name}.state"

        if [ -f "$statefile" ]; then
          pid=$(head -n1 "$statefile")
          file=$(tail -n1 "$statefile")
          if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
          fi
          if [ -f "$file" ]; then
            timestamp=$(date +%Y%m%d-%H%M%S)
            dest="$HOME/screenrecord-$timestamp.mp4"
            mv "$file" "$dest"
            notify-send "Screen Recording Saved" "$dest"
          else
            notify-send "Screen Recording Stopped" "No output file found"
          fi
          rm -f "$statefile"

          # Update Waybar indicator
          killall -USR1 waybar 2>/dev/null || true
        else
          timestamp=$(date +%Y%m%d-%H%M%S)
          output="/tmp/${name}-$timestamp.mp4"
          ${if useSlurp then ''
            region=$(slurp)
            wf-recorder -g "$region" -f "$output" &
          '' else ''
            wf-recorder -f "$output" &
          ''}
          pid=$!
          echo "$pid" > "$statefile"
          echo "$output" >> "$statefile"

          # Update Waybar indicator
          killall -USR1 waybar 2>/dev/null || true

          notify-send --hint=int:transient:1 "Screen Recording Started" \
            "Run '${name}' again to stop and save"
        fi
      '';
    };

  screen-record-full = mkScreenRecord {
    name = "screen-record-full";
    useSlurp = false;
  };

  screen-record-region = mkScreenRecord {
    name = "screen-record-region";
    useSlurp = true;
  };
in
{
  config = lib.mkIf (isNixOS && isDesktop) {
    home.packages = [
      pkgs.grim
      pkgs.slurp
      pkgs.wl-clipboard
      screenshot-region
      screenshot-full
      screen-record-full
      screen-record-region
    ];

    xdg.desktopEntries.screenshot-region = {
      name = "Screenshot Region";
      genericName = "Screenshot Tool";
      exec = "${screenshot-region}/bin/screenshot-region";
      categories = [ "Utility" "Graphics" ];
      comment = "Select a region and save screenshot to home directory";
      terminal = false;
      type = "Application";
    };

    xdg.desktopEntries.screenshot-full = {
      name = "Screenshot Full";
      genericName = "Screenshot Tool";
      exec = "${screenshot-full}/bin/screenshot-full";
      categories = [ "Utility" "Graphics" ];
      comment = "Screenshot entire screen and save to home directory";
      terminal = false;
      type = "Application";
    };

    xdg.desktopEntries.screen-record-full = {
      name = "Screen Record Full";
      genericName = "Screen Recording";
      exec = "${screen-record-full}/bin/screen-record-full";
      categories = [ "Utility" "AudioVideo" ];
      comment = "Record full screen (run again to stop and save to home directory)";
      terminal = false;
      type = "Application";
    };

    xdg.desktopEntries.screen-record-region = {
      name = "Screen Record Region";
      genericName = "Screen Recording";
      exec = "${screen-record-region}/bin/screen-record-region";
      categories = [ "Utility" "AudioVideo" ];
      comment = "Select a screen region to record (run again to stop and save to home directory)";
      terminal = false;
      type = "Application";
    };
  };
}
