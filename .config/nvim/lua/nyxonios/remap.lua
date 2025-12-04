vim.g.mapleader = ' '
vim.g.localleader = ' '

vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Move selected portions in visual mode with jk.
vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv")
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv")

-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- Diagnostic key maps
vim.keymap.set('n', '[d', function()
  vim.diagnostic.jump { count = -1, float = true }
end, { desc = 'Go to previous [D]iagnostic message' })

vim.keymap.set('n', ']d', function()
  vim.diagnostic.jump { count = 1, float = true }
end, { desc = 'Go to next [D]iagnostic message' })

vim.keymap.set('n', '<leader>e', function()
  vim.diagnostic.open_float {}
end, { desc = 'Show diagnostic [E]rror messages' })

vim.keymap.set('n', '<leader>q', function()
  vim.diagnostic.setqflist { severity = 1 }
end, { desc = 'Open error diagnostic in [Q]uickfix list' })

vim.keymap.set('n', '<leader>Q', function()
  vim.diagnostic.setqflist {}
end, { desc = 'Open all diagnostics in [Q]uickfix list' })

-- Reset highlight after search
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Open new tmux session directly from neovim
vim.keymap.set('n', '<C-f>', '<cmd>silent !tmux neww tmux-sessionizer<CR>')

-- Navigate quick fix list
vim.keymap.set('n', '<leader>k', '<cmd>cnext<CR>')
vim.keymap.set('n', '<leader>j', '<cmd>cprev<CR>')

-- Zen mode
vim.keymap.set('n', '<leader>z', '<cmd>ZenMode<CR>')

-- Copy/paste/deleting stuff
vim.keymap.set('n', 'p', '"0p') -- Always copy from the "copy" buffer (ignoring stuff deleted with dd)
vim.keymap.set('n', 'P', '"1p')
