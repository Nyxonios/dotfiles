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

-- Quickfix list: delete entry with 'dd'
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'qf',
  callback = function()
    local del_qf_item = function()
      local items = vim.fn.getqflist()
      local line = vim.fn.line('.')
      table.remove(items, line)
      vim.fn.setqflist(items, 'r')
      local new_line = math.min(line, #items)
      if new_line > 0 then
        vim.api.nvim_win_set_cursor(0, { new_line, 0 })
      end
    end

    local del_qf_range = function()
      local items = vim.fn.getqflist()
      local start_line = vim.fn.line("'<")
      local end_line = vim.fn.line("'>")
      local count = end_line - start_line + 1
      for i = 1, count do
        table.remove(items, start_line)
      end
      vim.fn.setqflist(items, 'r')
      local new_line = math.min(start_line, #items)
      if new_line > 0 then
        vim.api.nvim_win_set_cursor(0, { new_line, 0 })
      end
    end

    vim.keymap.set('n', 'dd', del_qf_item, { silent = true, buffer = true, desc = 'Remove entry from QF' })
    vim.keymap.set('v', 'd', del_qf_range, { silent = true, buffer = true, desc = 'Remove selected entries from QF' })
  end,
})
