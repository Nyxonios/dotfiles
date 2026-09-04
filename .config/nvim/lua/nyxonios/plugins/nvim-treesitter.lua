return {
  'nvim-treesitter/nvim-treesitter',
  lazy = false,
  build = ':TSUpdate !',
  config = function()
    local parsers = { 'lua', 'go', 'rust', 'vim', 'vimdoc', 'bash', 'templ', 'sql', 'gotmpl', 'comment', 'regex', 'nix' }
    local ts = require('nvim-treesitter')
    if vim.is_callable(ts.install) then
      ts.install(parsers)
    else
      require('nvim-treesitter.install').ensure_installed(parsers)
    end

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
