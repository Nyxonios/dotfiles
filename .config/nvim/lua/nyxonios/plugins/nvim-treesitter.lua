return {
  'nvim-treesitter/nvim-treesitter',
  lazy = false,
  build = ':TSUpdate !',
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
      group = vim.api.nvim_create_augroup('treesitter-highlight', { clear = true }),
      callback = function(args)
        local ft = vim.bo[args.buf].filetype
        local lang = vim.treesitter.language.get_lang(ft)
        if lang and vim.treesitter.language.add(lang) then
          vim.treesitter.start(args.buf, lang)
        end
      end,
    })
  end,
}
