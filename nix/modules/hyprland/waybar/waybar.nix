{ pkgs, ... }:
let
  inherit (import ./../../../vars.nix { inherit pkgs; }) userData;
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
in
{

  home-manager.users."${userData.user}" = { ... }: {
    # Configure & Theme Waybar
    programs.waybar = {
      enable = true;
      package = pkgs.waybar;
      settings = [
        {
          layer = "top";
          position = "top";
          modules-center = [
            "hyprland/workspaces"
            "clock"
          ];
          modules-left = [
            "pulseaudio"
            "cpu"
            "memory"
            "disk"
          ];
          modules-right = [
            "bluetooth"
            "network"
            "custom/notification"
            "tray"
            "custom/exit"
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
            tooltip = false;
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
            # TODO: Get the number of buttons from wlogut and use that as input to the command below. 
            on-click = "sleep 0.1 && wlogout -b 5";
          };
          # "custom/hyprbindings" = {
          #   tooltip = false;
          #   format = "";
          #   on-click = "sleep 0.1 && list-hypr-bindings";
          # };
          # "custom/notification" = {
          #   tooltip = false;
          #   format = "{icon} {}";
          #   format-icons = {
          #     notification = "<span foreground='red'><sup></sup></span>";
          #     none = "";
          #     dnd-notification = "<span foreground='red'><sup></sup></span>";
          #     dnd-none = "";
          #     inhibited-notification = "<span foreground='red'><sup></sup></span>";
          #     inhibited-none = "";
          #     dnd-inhibited-notification = "<span foreground='red'><sup></sup></span>";
          #     dnd-inhibited-none = "";
          #   };
          #   return-type = "json";
          #   exec-if = "which swaync-client";
          #   exec = "swaync-client -swb";
          #   on-click = "sleep 0.1 && task-waybar";
          #   escape = true;
          # };
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
            border-left: 0px;
            border-right: 0px;
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
          border-right: 0px;
        }
        #bluetooth {
          color: #${palette.base05};
          border-radius: 10px 0px 0px 10px;
          border-right: 0px;
          margin-left: 10px;
        }

        #pulseaudio {
          color: #${palette.base05};
          border-radius: 10px 0 0 10px;
          margin-left: 10px;
        }
        #custom-exit {
          color: #${palette.base05};
          border-radius: 0 10px 10px 0;
          margin-right: 10px;
          border-left: 0px; 
        }
      '';
    };
  };
} 

