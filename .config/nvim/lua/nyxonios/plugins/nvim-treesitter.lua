return {
  'nvim-treesitter/nvim-treesitter',
  build = ':TSUpdate',
  config = function()
    local config = require 'nvim-treesitter.configs'

    config.setup {
      ensure_installed = { 'lua', 'go', 'rust', 'lua', 'vim', 'vimdoc', 'bash', 'templ', 'sql', 'gotmpl', 'comment', 'regex', 'nix' },
      auto_install = true,
      highlight = { enable = true, disable = { "ssh_config" } },
      indent = { enable = true },
      textobjects = {
        move = {
          enable = true,
          set_jumps = true,

          goto_next_start = {
            [']p'] = '@parameter.inner',
            [']m'] = '@function.outer',
            [']]'] = '@class.outer',
          },
          goto_next_end = {
            [']M'] = '@function.outer',
            [']['] = '@class.outer',
          },
          goto_previous_start = {
            ['[p'] = '@parameter.inner',
            ['[m'] = '@function.outer',
            ['[['] = '@class.outer',
          },
          goto_previous_end = {
            ['[M'] = '@function.outer',
            ['[]'] = '@class.outer',
          },
        },

        select = {
          enable = true,
          lookahead = true,

          keymaps = {
            ['af'] = '@function.outer',
            ['if'] = '@function.inner',

            ['ac'] = '@conditional.outer',
            ['ic'] = '@conditional.inner',

            ['aa'] = '@parameter.outer',
            ['ia'] = '@parameter.inner',

            ['av'] = '@variable.outer',
            ['iv'] = '@variable.inner',
          },
        },

        swap = {
          enable = true,
          swap_next = {
            ['<leader>a'] = '@parameter.inner',
          },
          swap_previous = {
            ['<leader>A'] = '@parameter.inner',
          },
        },
      },
    }
  end,
}
