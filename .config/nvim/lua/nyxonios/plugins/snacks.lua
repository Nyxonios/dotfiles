return {
  'folke/snacks.nvim',
  ---@type snacks.Config
  opts = {
    explorer = {
      enable = true,
      replace_netrw = true, -- Replace netrw with the snacks explorer
      trash = true, -- Use the system trash when deleting files
    },
  },
  keys = {
    {
      '<leader>fe',
      function()
        Snacks.explorer()
      end,
      desc = 'File Explorer',
    },
  },
}
