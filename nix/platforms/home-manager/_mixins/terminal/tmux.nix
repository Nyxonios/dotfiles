# Tmux Configuration

{ config, pkgs, lib, host, ... }:

{
  config = {
    programs.tmux = {
      enable = true;
      shell = "${pkgs.zsh}/bin/zsh";

      plugins = with pkgs.tmuxPlugins; [
        {
          plugin = sensible;
        }
        {
          plugin = catppuccin;
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
        # Darwin-specific fixes
        set -gu default-command
        set -g default-shell "$SHELL"

        set -g default-terminal "tmux-256color"
        set -ga terminal-overrides ",*256col*:Tc"
        set -ga terminal-overrides '*:Ss=\E[%p1%d q:Se=\E[ q'
        set-environment -g COLORTERM "truecolor"

        set -g prefix C-a
        unbind C-b
        bind-key C-a send-prefix

        set -g base-index 1
        set -g detach-on-destroy off
        set -g escape-time 0
        set -g history-limit 1000000
        set -g renumber-windows on
        set -g status-position top
        set -g pane-active-border-style 'fg=#cad3f5,bg=#cad3f5'
        set -g extended-keys on
        set -g xterm-keys on
        set -g allow-passthrough on
        set -g set-clipboard on

        set -as terminal-features ',*:clipboard'

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

        bind-key -T copy-mode-vi 'v' send -X begin-selection
        bind-key -T copy-mode-vi 'y' send -X copy-selection

        unbind -T copy-mode-vi MouseDragEnd1Pane

        set -sg escape-time 10

        is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
        | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?(-wrapped)?|fzf)(diff)?$'"
        bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
        bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
        bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
        bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'

        unbind C-g
        bind -n C-g display-popup -h 95% -w 95% -d "#{pane_current_path}" -E "${pkgs.lazygit}/bin/lazygit"
        bind-key -T copy-mode-vi 'C-h' select-pane -L
        bind-key -T copy-mode-vi 'C-j' select-pane -D
        bind-key -T copy-mode-vi 'C-k' select-pane -U
        bind-key -T copy-mode-vi 'C-l' select-pane -R
        bind-key -T copy-mode-vi 'C-\' select-pane -l

        bind-key -r f run-shell "tmux neww tmux-sessionizer"
      '';
    };
  };
}
