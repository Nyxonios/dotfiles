return {
  'nvim-treesitter/nvim-treesitter',
  branch = 'main',
  lazy = false,
  build = ':TSUpdate',
  config = function()
    require('nvim-treesitter').install {
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
    }

    vim.api.nvim_create_autocmd('FileType', {
      callback = function()
        pcall(vim.treesitter.start)
      end,
    })
  end,
}
