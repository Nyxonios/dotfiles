return {
  'nvim-treesitter/nvim-treesitter',
  branch = 'main',
  lazy = false,
  build = ':TSUpdate',
  config = function()
    require('nvim-treesitter').setup {
      ensure_installed = {
        'lua',
        'go',
        'rust',
        'vim',
        'vimdoc',
        'bash',
        'templ',
        'sql',
        'gotmpl',
        'comment',
        'regex',
        'nix',
      },
      highlight = { 
        enable = true,
        disable = function(lang, buf)
          return lang == "markdown"
        end,
      },
      auto_install = true,
      sync_install = false,
    }
  end,
}
