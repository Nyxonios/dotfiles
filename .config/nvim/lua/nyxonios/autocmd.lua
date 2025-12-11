vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking text',
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  desc = 'Sets the compiler to tsc when entering a typescript file',
  pattern = 'typescript,typescriptreact',
  group = vim.api.nvim_create_augroup('set-tsc-compiler', { clear = true }),
  command = 'compiler tsc | setlocal makeprg=npx\\ tsc\\ --noEmit',
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'markdown,md',
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_option_value('tabstop', 2, { scope = 'local', buf = buf })
    vim.api.nvim_set_option_value('textwidth', 100, { scope = 'local', buf = buf })
  end,
})

vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter' }, {
  command = "if mode() != 'c' | checktime | endif",
  pattern = '*',
})
