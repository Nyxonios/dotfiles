# Waybar Configuration
# Status bar for Hyprland

{ config, pkgs, lib, host, customLib, ... }:

let
  isNixOS = host.platform == "nixos";
  isDesktop = customLib.isDesktop (host.formFactor or "");

  palette = {
    base00 = "1e1e2e"; # base
    base01 = "181825"; # mantle
    base02 = "313244"; # surface0
    base03 = "45475a"; # surface1
    base04 = "585b70"; # surface2
    base05 = "cdd6f4"; # text
    base06 = "f5e0dc"; # rosewater
    base07 = "b4befe"; # lavender
    base08 = "f38ba8"; # red
    base09 = "fab387"; # peach
    base0A = "f9e2af"; # yellow
    base0B = "a6e3a1"; # green
    base0C = "94e2d5"; # teal
    base0D = "89b4fa"; # blue
    base0E = "cba6f7"; # mauve
    base0F = "f2cdcd"; # flamingo
  };

  stop-recording = pkgs.writeShellApplication {
    name = "stop-recording";
    runtimeInputs = [ pkgs.coreutils pkgs.procps pkgs.libnotify ];
    text = ''
      for statefile in /tmp/screen-record-*.state; do
        [ -f "$statefile" ] || continue
        pid=$(head -n1 "$statefile" 2>/dev/null || true)
        file=$(tail -n1 "$statefile" 2>/dev/null || true)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
          kill "$pid"
        fi
        if [ -n "$file" ] && [ -f "$file" ]; then
          timestamp=$(date +%Y%m%d-%H%M%S)
          dest="$HOME/screenrecord-$timestamp.mp4"
          mv "$file" "$dest"
          notify-send "Screen Recording Saved" "$dest"
        else
          notify-send "Screen Recording Stopped" "No output file found"
        fi
        rm -f "$statefile"
      done
      # Update Waybar indicator
      killall -USR1 waybar 2>/dev/null || true
    '';
  };

  recording-indicator = pkgs.writeShellApplication {
    name = "recording-indicator";
    runtimeInputs = [ pkgs.coreutils pkgs.procps ];
    text = ''
      for statefile in /tmp/screen-record-*.state; do
        [ -f "$statefile" ] || continue
        pid=$(head -n1 "$statefile" 2>/dev/null || true)
        if kill -0 "$pid" 2>/dev/null; then
          echo '{"text": "󰻃 REC", "class": "recording", "tooltip": "Screen recording in progress. Click to stop."}'
          exit 0
        else
          rm -f "$statefile"
        fi
      done
      echo '{"text": "", "class": "hidden", "tooltip": "No recording in progress"}'
    '';
  };

  language-indicator = pkgs.writeShellApplication {
    name = "language-indicator";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      map=$(hyprctl devices -j | jq -r '.keyboards[] | select(.main == true) | .active_keymap')
      case "$map" in
        *English*|*US*)
          echo "us"
          ;;
        *Swedish*|*Svenska*)
          echo "se"
          ;;
        *)
          echo "??"
          ;;
      esac
    '';
  };
in
{
  config = lib.mkIf (isNixOS && isDesktop) {
    home.packages = [ recording-indicator stop-recording language-indicator pkgs.networkmanagerapplet ];

    # Configure & Theme Waybar via home-manager
    programs.waybar = {
      enable = true;
      package = pkgs.waybar;
      settings = [
        {
          layer = "top";
          position = "top";
          modules-center = [
            "hyprland/workspaces"
            "custom/recording"
            "clock"
          ];
          modules-right = [
            "custom/language"
            "bluetooth"
            "network"
            "tray"
            "custom/screenshot"
            "custom/screen-record"
            "custom/exit"
          ];
          modules-left = [
            "pulseaudio"
            "cpu"
            "memory"
            "disk"
          ];

          "hyprland/workspaces" = {
            format = "{name}";
            format-icons = {
              default = " ";
              active = " ";
              urgent = " ";
            };
            on-scroll-up = "hyprctl dispatch workspace e+1";
            on-scroll-down = "hyprctl dispatch workspace e-1";
          };
          "clock" = {
            format = " {:L%H:%M}";
            tooltip = true;
            tooltip-format = "<big>{:%A, %d.%B %Y }</big>\n<tt><small>{calendar}</small></tt>";
          };
          "memory" = {
            interval = 5;
            format = " {}%";
            tooltip = true;
          };
          "cpu" = {
            interval = 5;
            format = " {usage:2}%";
            tooltip = true;
          };
          "disk" = {
            format = " {free}";
            tooltip = true;
          };
          "network" = {
            format-icons = [
              "󰤯"
              "󰤟"
              "󰤢"
              "󰤥"
              "󰤨"
            ];
            format-ethernet = " {bandwidthDownOctets}";
            format-wifi = "{icon} {signalStrength}%";
            format-disconnected = "󰤮";
            tooltip = true;
            tooltip-format-wifi = "{essid} ({signalStrength}%)";
            tooltip-format-ethernet = "{ifname}";
            tooltip-format-disconnected = "Disconnected";
            on-click = "sleep 0.1 && nm-connection-editor";
          };
          "tray" = {
            spacing = 12;
          };
          "bluetooth" = {
            format = "";
            format-disabled = "󰂲";
            format-connected = " {num_connections}";
            tooltip-format = "{controller_alias}\t{controller_address}";
            tooltip-format-connected = "{controller_alias}\t{controller_address}\n\n{device_enumerate}";
            tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
            on-click = "sleep 0.1 && blueman-manager";
          };
          "custom/language" = {
            exec = "${language-indicator}/bin/language-indicator";
            interval = 1;
            format = "⌨ {}";
            tooltip = false;
          };
          "pulseaudio" = {
            format = "{icon} {volume}% {format_source}";
            format-bluetooth = "{volume}% {icon} {format_source}";
            format-bluetooth-muted = " {icon} {format_source}";
            format-muted = " {format_source}";
            format-source = " {volume}%";
            format-source-muted = "";
            format-icons = {
              headphone = "";
              hands-free = "";
              headset = "";
              phone = "";
              portable = "";
              car = "";
              default = [
                ""
                ""
                ""
              ];
            };
            on-click = "sleep 0.1 && pavucontrol";
          };
          "custom/exit" = {
            tooltip = false;
            format = "";
            on-click = "sleep 0.1 && wleave";
          };
          "custom/recording" = {
            exec = "${recording-indicator}/bin/recording-indicator";
            interval = 1;
            return-type = "json";
            format = "{}";
            on-click = "stop-recording";
          };
          "custom/screenshot" = {
            tooltip = "Screenshot Region";
            format = "󰄀";
            on-click = "sleep 0.1 && screenshot-region";
          };
          "custom/screen-record" = {
            tooltip = "Screen Record Region";
            format = "󰻃";
            on-click = "sleep 0.1 && screen-record-region";
          };
        }
      ];
      style = ''
        * {
            border: none;
            border-radius: 0;
            font-family: monospace;
            font-weight: bold;
            font-size: 14px;
            min-height: 0;
        }

        window#waybar {
            background: rgba(21, 18, 27, 0);
            color: #${palette.base0F};
        }

        tooltip {
            background: #${palette.base00};
            border-radius: 10px;
            border-width: 2px;
            border-style: solid;
            border-color: #11111b;
        }

        #workspaces button {
            color: #${palette.base05};
            padding: 5px;
            margin-right: 5px;
        }

        #workspaces button.active {
            color: #${palette.base09};
        }

        #workspaces button.focused {
            color: #${palette.base05};
            background: #eba0ac;
            border-radius: 10px;
        }

        #workspaces button.urgent {
            color: #${palette.base05};
            background: #${palette.base0B};
            border-radius: 10px;
        }

        #workspaces button:hover {
            background: #11111b;
            color: #${palette.base05};
            border-radius: 10px;
        }

        #custom-language,
        #custom-updates,
        #custom-caffeine,
        #custom-exit,
        #custom-recording,
        #custom-screenshot,
        #custom-screen-record,
        #window,
        #hyprland-workspaces,
        #clock,
        #battery,
        #pulseaudio,
        #network,
        #workspaces,
        #cpu,
        #memory,
        #bluetooth,
        #disk,
        #tray {
            background: #${palette.base00};
            padding: 0px 10px;
            margin: 3px 0px;
            margin-top: 10px;
            border: 1px solid #181825;
        }

        #tray {
            border-radius: 10px;
            margin-right: 10px;
        }

        #workspaces {
            background: #${palette.base00};
            border-radius: 10px;
            margin-left: 10px;
            padding-right: 0px;
            padding-left: 5px;
        }

        #custom-language {
            color: #${palette.base05};
            border-radius: 10px 0px 0px 10px;
            border-right: 0px;
            margin-left: 10px;
            margin-right: 0px;
        }

        #custom-updates {
          color: #${palette.base05};
          border-left: 0px;
          border-right: 0px;
        }

        #window {
            border-radius: 10px;
            margin-left: 60px;
            margin-right: 60px;
        }

        #clock {
            color: #${palette.base05};
            border-radius: 10px;
            margin-left: 10px;
        }

        #cpu {
          color: #${palette.base05};
          border-left: 0px;
          border-right: 0px;
        }
        #memory {
          color: #${palette.base05};
          border-left: 0px;
          border-right: 0px;
        }
        #disk {
          color: #${palette.base05};
          border-radius: 0 10px 10px 0;
          margin-right: 10px;
          border-left: 0px;
        }

        #network {
          color: #${palette.base05};
          border-left: 0px;
          border-radius: 0 10px 10px 0;
        }
        #bluetooth {
          color: #${palette.base05};
          border-radius: 0px;
          border-left: 0px;
          border-right: 0px;
          margin-left: 0px;
        }

        #pulseaudio {
          color: #${palette.base05};
          border-radius: 10px 0 0 10px;
          margin-left: 10px;
        }
        #custom-screenshot {
          color: #${palette.base05};
          border-radius: 10px 0 0 10px;
          margin-left: 10px;
          border-right: 0px;
        }
        #custom-screen-record {
          color: #${palette.base05};
          border-radius: 0 10px 10px 0;
          border-left: 0px;
        }
        #custom-recording {
            color: #f38ba8;
            border-radius: 10px;
            padding-left: 12px;
            padding-right: 12px;
            margin-left: 10px;
            margin-right: 10px;
        }
        #custom-recording.hidden {
            color: transparent;
            background: transparent;
            padding: 0px;
            margin: 0px;
            border: none;
        }
        #custom-recording.recording {
            color: #ffffff;
            background: #f38ba8;
        }
        #custom-exit {
          color: #${palette.base05};
          border-radius: 10px;
          margin-right: 10px;
          margin-left: 15px;
        }
      '';
    };
  };
}
