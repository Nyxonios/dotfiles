{ config, pkgs, ... }:
{
  enable = true;
  shell = "${pkgs.zsh}/bin/zsh";
  plugins = with pkgs; [
    {
      plugin = tmuxPlugins.sensible;
    }
    {
      plugin = tmuxPlugins.catppuccin;
      extraConfig = ''
        set -g @catppuccin_flavour "mocha"
        set -g @catppuccin_window_left_separator ""
        set -g @catppuccin_window_right_separator " "
        set -g @catppuccin_window_middle_separator " █"
        set -g @catppuccin_window_number_position "right"
        set -g @catppuccin_window_default_fill "number"
        set -g @catppuccin_window_default_text "#W"
        set -g @catppuccin_window_current_fill "number"
        set -g @catppuccin_window_current_text "#W#{?window_zoomed_flag,(),}"
        set -g @catppuccin_status_modules_right "directory meetings date_time"
        set -g @catppuccin_status_modules_left "session"
        set -g @catppuccin_status_left_separator  " "
        set -g @catppuccin_status_right_separator " "
        set -g @catppuccin_status_right_separator_inverse "no"
        set -g @catppuccin_status_fill "icon"
        set -g @catppuccin_status_connect_separator "no"
        set -g @catppuccin_directory_text "#{b:pane_current_path}"
        set -g @catppuccin_date_time_text "%H:%M"
      '';
    }
  ];
  extraConfig = ''
    # These are currently needed on Darwin as there seems
    # to be a bug in the tmux sensible plugin.
    # https://github.com/nix-community/home-manager/issues/5952
    set -gu default-command
    set -g default-shell "$SHELL"

    set -g default-terminal "tmux-256color"
    set -ga terminal-overrides ",*256col*:Tc"
    set -ga terminal-overrides '*:Ss=\E[%p1%d q:Se=\E[ q'
    set-environment -g COLORTERM "truecolor"

    set -g prefix C-a
    unbind C-b
    bind-key C-a send-prefix

    set -g base-index 1              # start indexing windows at 1 instead of 0
    set -g detach-on-destroy off     # don't exit from tmux when closing a session
    set -g escape-time 0             # zero-out escape time delay
    set -g history-limit 1000000     # increase history size (from 2,000)
    set -g renumber-windows on       # renumber all windows when any window is closed
    set -g set-clipboard on          # use system clipboard
    set -g status-position top       # macOS / darwin style
    set -g pane-active-border-style 'fg=#cad3f5,bg=#cad3f5'

    unbind %
    bind -n 'C-\' split-window -h -c '#{pane_current_path}'

    unbind '"'
    bind - split-window -v -c '#{pane_current_path}'
    bind -n 'C-_' split-window -v -c '#{pane_current_path}'

    unbind r
    bind r source-file ${config.xdg.configHome}/tmux/tmux.conf

    bind -r j resize-pane -D 5
    bind -r k resize-pane -U 5
    bind -r l resize-pane -R 5
    bind -r h resize-pane -L 5

    bind -r m resize-pane -Z

    set -g mouse on

    set-window-option -g mode-keys vi

    bind-key -T copy-mode-vi 'v' send -X begin-selection # start selecting text with "v"
    bind-key -T copy-mode-vi 'y' send -X copy-selection # copy text with "y"

    unbind -T copy-mode-vi MouseDragEnd1Pane # don't exit copy mode when dragging with mouse

    # remove delay for exiting insert mode with ESC in Neovim
    set -sg escape-time 10

    is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
    | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?(-wrapped)?|fzf)(diff)?$'"
    bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
    bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
    bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
    bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'
    tmux_version='$(tmux -V | sed -En "s/^tmux ([0-9]+(.[0-9]+)?).*/\1/p")'
    if-shell -b '[ "$(echo "$tmux_version < 3.0" | bc)" = 1 ]' \
    "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\'  'select-pane -l'"
    if-shell -b '[ "$(echo "$tmux_version >= 3.0" | bc)" = 1 ]' \
    "bind-key -n 'C-\\' if-shell \"$is_vim\" 'send-keys C-\\\\'  'select-pane -l'"

    unbind C-g
    bind -n C-g display-popup -h 95% -w 95% -d "#{pane_current_path}" -E "lazygit"
    bind-key -T copy-mode-vi 'C-h' select-pane -L
    bind-key -T copy-mode-vi 'C-j' select-pane -D
    bind-key -T copy-mode-vi 'C-k' select-pane -U
    bind-key -T copy-mode-vi 'C-l' select-pane -R
    bind-key -T copy-mode-vi 'C-\' select-pane -l

    bind-key -r f run-shell "tmux neww tmux-sessionizer"
  '';
}
