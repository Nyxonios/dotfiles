{ pkgs, ... }:
let
  inherit (import ./../../home.nix {inherit pkgs;}) userData;

  icons = (import ./icons.nix {inherit pkgs;});
  colors = (import ./colors.nix {inherit pkgs;});
  aerospace = (import ./plugins/aerospace.nix {inherit pkgs;});

  sketchybarrc = pkgs.writeShellScript "sketchybarrc" ''
    source ${icons}
    source ${colors}
    source ${aerospace}

    FONT="FiraCode" # Needs to have Regular, Bold, Semibold, Heavy and Black variants
    PADDINGS=3 # All paddings use this value (icon, label, background)
    POPUP_BORDER_WIDTH=2
    POPUP_CORNER_RADIUS=11
    SHADOW=on

    # Setting up the general bar appearance and default values
    sketchybar --bar     height=50                                         \
                         color=$BAR_COLOR                                  \
                         shadow=$SHADOW                                    \
                         position=right                                    \
                         sticky=on                                         \
                         padding_right=18                                  \
                         padding_left=18                                   \
                         corner_radius=9                                   \
                         y_offset=10                                       \
                         margin=10                                         \
                         blur_radius=20                                    \
                                                                           \
               --default updates=when_shown                                \
                         icon.font="$FONT:Bold:14.0"                       \
                         icon.color=$ICON_COLOR                            \
                         icon.padding_left=$PADDINGS                       \
                         icon.padding_right=$PADDINGS                      \
                         label.font="$FONT:Semibold:13.0"                  \
                         label.color=$LABEL_COLOR                          \
                         label.padding_left=$PADDINGS                      \
                         label.padding_right=$PADDINGS                     \
                         background.padding_right=$PADDINGS                \
                         background.padding_left=$PADDINGS                 \
                         popup.background.border_width=2                   \
                         popup.background.corner_radius=11                 \
                         popup.background.border_color=$POPUP_BORDER_COLOR \
                         popup.background.color=$POPUP_BACKGROUND_COLOR    \
                         popup.background.shadow.drawing=$SHADOW
  '';
in
{
  environment.systemPackages = [
    pkgs.sketchybar
  ];


  home-manager.users."${userData.user}" = { ... }:
    {
      xdg.configFile.sketcybar.source = sketchybarrc;
    };
}



