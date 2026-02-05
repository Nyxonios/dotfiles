return {
  'NickvanDyke/opencode.nvim',
  dependencies = {
    -- Recommended for `ask()` and `select()`.
    -- Required for `snacks` provider.
    ---@module 'snacks' <- Loads `snacks.nvim` types for configuration intellisense.
    { 'folke/snacks.nvim', opts = { input = {}, picker = {}, terminal = {} } },
  },
  config = function()
    ---@type opencode.Opts
    vim.g.opencode_opts = {
      -- Your configuration, if any — see `lua/opencode/config.lua`, or "goto definition".
    }

    vim.keymap.set({ 'n', 'x' }, '<C-a>', function()
      require('opencode').ask('@this: ', { submit = true })
    end, { desc = 'Ask opencode' })
    -- vim.keymap.set({ 'n', 'x' }, '<leader>o', function()
    --   require('opencode').select()
    -- end, { desc = 'Execute opencode action…' })
    vim.keymap.set({ 'n', 't' }, '<C-o>', function()
      require('opencode').toggle()
    end, { desc = 'Toggle opencode' })
  end,
}
