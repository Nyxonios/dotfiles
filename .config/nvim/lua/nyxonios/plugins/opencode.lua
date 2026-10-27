return {
  'NickvanDyke/opencode.nvim',
  dependencies = {
    -- Recommended for `ask()` and `select()`.
    -- Required for `snacks` provider.
    ---@module 'snacks' <- Loads `snacks.nvim` types for configuration intellisense.
    -- missing-fields: snacks annotates every module field on `Snacks` as
    -- required; these partial opts intentionally enable just a few modules.
    ---@diagnostic disable-next-line: missing-fields
    { 'folke/snacks.nvim', opts = { input = {}, picker = {}, terminal = {} } },
  },
  config = function()
    ---@type opencode.Opts
    vim.g.opencode_opts = {
      -- Your configuration, if any — see `lua/opencode/config.lua`, or "goto definition".
      provider = {
        snacks = {
          win = {
            position = 'right',
            width = 0.4,
          },
        },
      },
    }

    vim.keymap.set({ 'n', 'x' }, '<C-e>', function()
      require('opencode').ask '@this: '
    end, { desc = 'Ask opencode' })
    vim.keymap.set({ 'n', 't' }, '<C-q>', function()
      require('opencode').toggle()
    end, { desc = 'Toggle opencode' })
  end,
}
