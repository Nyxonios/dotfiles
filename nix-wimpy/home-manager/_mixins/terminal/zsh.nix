# Zsh Configuration

{ config, pkgs, lib, host, ... }:

let
  # Determine rebuild command based on platform
  rebuildCmd =
    if host.platform == "darwin" then
      "darwin-rebuild switch --flake ~/dotfiles/nix-wimpy#${host.username}"
    else if host.platform == "nixos" then
      "sudo nixos-rebuild switch --flake ~/dotfiles/nix-wimpy#${host.username}"
    else
      "home-manager switch --flake ~/dotfiles/nix-wimpy#${host.username}";
in
{
  config = {
    programs.zsh = {
      enable = true;
      dotDir = ".config/zsh";

      history = {
        size = 10000;
        path = "${config.xdg.dataHome}/zsh/history";
        ignoreDups = true;
        ignoreAllDups = true;
        ignoreSpace = true;
        share = true;
      };

      shellAliases = {
        vim = "nvim";
        ls = "ls --color";
        clean = "clear";
        cnvim = "cd ~/.config/nvim && nvim";
        cdot = "cd ~/dotfiles && nvim";
        devv = "cd ~/development";
        rebuild = rebuildCmd;
      };

      initContent = ''
        ZSH_DISABLE_COMPFIX=true
        export EDITOR=nvim

        # Disable sort when completing `git checkout`
        zstyle ':completion:*:git-checkout:*' sort false

        # Set descriptions format to enable group support
        zstyle ':completion:*:descriptions' format '[%d]'

        # Set list-colors to enable filename colorizing
        zstyle ':completion:*' list-colors "\''${(s.:.)LS_COLORS}"

        # Force zsh not to show completion menu, which allows fzf-tab to capture the unambiguous prefix
        zstyle ':completion:*' menu no

        # Completion styling
        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
        zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'

        zle_highlight+=(paste:none)

        setopt appendhistory
        setopt sharehistory
        setopt hist_ignore_space
        setopt hist_ignore_all_dups
        setopt hist_save_no_dups
        setopt hist_find_no_dups

        # Tmux sessionizer shortcut
        bindkey -s ^f "tmux-sessionizer\n"

        # Direnv hook
        _direnv_hook() {
          trap -- '' SIGINT
          eval "$(${pkgs.direnv}/bin/direnv export zsh)"
          trap - SIGINT
        }
        typeset -ag precmd_functions
        if (( ! "\''${precmd_functions[(I)_direnv_hook]}" )); then
          precmd_functions=(_direnv_hook $precmd_functions)
        fi
        typeset -ag chpwd_functions
        if (( ! "\''${chpwd_functions[(I)_direnv_hook]}" )); then
          chpwd_functions=(_direnv_hook $chpwd_functions)
        fi

        # Source work-specific config if it exists
        if [ -f ~/bin/work.sh ]; then
          source ~/bin/work.sh
        fi

        export PATH=$PATH:/usr/bin
      '';

      oh-my-zsh = {
        enable = true;
        plugins = [
          "git"
          "sudo"
          "golang"
          "vi-mode"
        ];
      };

      plugins = [
        {
          name = "zsh-autosuggestions";
          src = pkgs.zsh-autosuggestions;
          file = "share/zsh-autosuggestions/zsh-autosuggestions.zsh";
        }
        {
          name = "zsh-completions";
          src = pkgs.zsh-completions;
          file = "share/zsh-completions/zsh-completions.zsh";
        }
        {
          name = "zsh-syntax-highlighting";
          src = pkgs.zsh-syntax-highlighting;
          file = "share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
        }
        {
          name = "powerlevel10k";
          src = pkgs.zsh-powerlevel10k;
          file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
        }
        {
          name = "fzf-tab";
          src = pkgs.zsh-fzf-tab;
          file = "share/fzf-tab/fzf-tab.plugin.zsh";
        }
      ];
    };

    # Powerlevel10k config symlink
    home.file.".config/zsh/p10k.zsh".source = config.lib.file.mkOutOfStoreSymlink "${host.home}/dotfiles/.config/zsh/p10k.zsh";
  };
}
