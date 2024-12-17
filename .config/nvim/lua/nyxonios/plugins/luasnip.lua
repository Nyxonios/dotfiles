return {
  'L3MON4D3/LuaSnip',
  version = 'v2.*',
  -- install jsregexp (optional!).
  build = 'make install_jsregexp',
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
  },
  config = function()
    vim.keymap.set('i', '<c-u>', require 'luasnip.extras.select_choice')
    vim.keymap.set({ 'i' }, '<C-K>', function()
      ls.expand()
    end, { silent = true })
    vim.keymap.set({ 'i', 's' }, '<C-L>', function()
      ls.jump(1)
    end, { silent = true })
    vim.keymap.set({ 'i', 's' }, '<C-J>', function()
      ls.jump(-1)
    end, { silent = true })

    vim.keymap.set({ 'i', 's' }, '<C-E>', function()
      if ls.choice_active() then
        ls.change_choice(1)
      end
    end, { silent = true })
    require('luasnip.loaders.from_lua').lazy_load { paths = { vim.fn.stdpath 'config' .. '/lua/nyxonios/luasnippets' } }
  end,
}
