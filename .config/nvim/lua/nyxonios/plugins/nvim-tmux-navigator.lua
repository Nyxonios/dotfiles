return {
  'christoomey/vim-tmux-navigator',
  lazy = false,
  cmd = {
    'TmuxNavigateLeft',
    'TmuxNavigateDown',
    'TmuxNavigateUp',
    'TmuxNavigateRight',
    'TmuxNavigatePrevious',
  },
  keys = {
    { '<c-h>', '<cmd><C-U>TmuxNavigateLeft<cr>' },
    { '<c-j>', '<cmd><C-U>TmuxNavigateDown<cr>' },
    { '<c-k>', '<cmd><C-U>TmuxNavigateUp<cr>' },
    { '<c-l>', '<cmd><C-U>TmuxNavigateRight<cr>' },
    { '<c-\\>', '<cmd><C-U>TmuxNavigatePrevious<cr>' },
  },
  config = function()
    -- Terminal mode mappings to allow tmux navigation from terminal buffers
    vim.keymap.set('t', '<c-h>', '<c-\\><c-n><cmd>TmuxNavigateLeft<cr>', { silent = true })
    vim.keymap.set('t', '<c-j>', '<c-\\><c-n><cmd>TmuxNavigateDown<cr>', { silent = true })
    vim.keymap.set('t', '<c-k>', '<c-\\><c-n><cmd>TmuxNavigateUp<cr>', { silent = true })
    vim.keymap.set('t', '<c-l>', '<c-\\><c-n><cmd>TmuxNavigateRight<cr>', { silent = true })
    vim.keymap.set('t', '<c-\\>', '<c-\\><c-n><cmd>TmuxNavigatePrevious<cr>', { silent = true })
  end,
}
