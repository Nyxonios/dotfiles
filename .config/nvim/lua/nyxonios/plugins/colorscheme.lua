return {
  'catppuccin/nvim',
  name = 'catppuccin',
  priority = 1000,
  config = function()
    require('catppuccin').setup {
      integrations = {
        treesitter = true,
        native_lsp = {
          enabled = true,
        },
      },
      highlight_overrides = {
        all = function(colors)
          return {
            ['@variable'] = { fg = colors.text },
            ['@lsp.type.variable'] = { fg = colors.text },
          }
        end,
      },
    }
    vim.cmd.colorscheme 'catppuccin'

    vim.defer_fn(function()
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[buf].filetype and vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_is_valid(buf) then
          local ft = vim.bo[buf].filetype
          local lang = vim.treesitter.language.get_lang(ft)
          if lang and vim.treesitter.language.add(lang) then
            vim.treesitter.stop(buf)
            vim.treesitter.start(buf, lang)
          end
        end
      end
    end, 100)
  end,
}
