vim.g.mapleader = ' '
vim.g.localleader = ' '

vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

vim.keymap.set('n', '<leader>fe', '<cmd>Neotree position=left toggle<cr>')

-- Move selected portions in visual mode with jk.
vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv")
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv")

-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- Diagnostic key maps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous [D]iagnostic message' })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next [D]iagnostic message' })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic [E]rror messages' })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Reset highlight after search
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Open new tmux session directly from neovim
vim.keymap.set('n', '<C-f>', '<cmd>silent !tmux neww tmux-sessionizer<CR>')

-- Navigate quick fix list
vim.keymap.set('n', '<leader>k', '<cmd>cnext<CR>')
vim.keymap.set('n', '<leader>j', '<cmd>cprev<CR>')

local function find_and_run_build_script()
  -- Detect platform
  local is_windows = vim.fn.has 'win32' == 1 or vim.fn.has 'win64' == 1

  -- Prioritize platform-specific script
  local primary_pattern = is_windows and '**/build.bat' or '**/build.sh'
  local fallback_pattern = is_windows and '**/build.sh' or '**/build.bat' -- Optional fallback

  local build_file = nil
  local matches = vim.fn.glob(primary_pattern, 1, true) -- pathspec=1 for absolute paths, list=true

  if #matches > 0 then
    build_file = matches[1] -- Use first match
  else
    -- Try fallback if primary not found
    matches = vim.fn.glob(fallback_pattern, 1, true)
    if #matches > 0 then
      build_file = matches[1]
    end
  end

  if not build_file then
    vim.notify('No build script found in workspace.', vim.log.levels.WARN)
    return
  end

  -- Ensure absolute path
  build_file = vim.fn.fnamemodify(build_file, ':p')
  vim.notify('Running build script: ' .. build_file)

  -- Retrieve or create output buffer
  local buf = vim.g.build_output_buf
  local is_reusing = false
  if buf and vim.api.nvim_buf_is_valid(buf) then
    is_reusing = true
  else
    -- Create new buffer
    vim.cmd 'new | setlocal buftype=nofile bufhidden=hide nomodifiable nonumber'
    buf = vim.api.nvim_get_current_buf()
    vim.g.build_output_buf = buf
  end

  -- Switch to the buffer if not already current
  if vim.api.nvim_get_current_buf() ~= buf then
    vim.api.nvim_set_current_buf(buf)
  end

  -- Prepare for new output: enable modification first
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  -- Clear existing content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
  -- Add header
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { build_file .. ' output:', '' })

  -- Prepare command: Run via shell to handle non-executable scripts
  local cmd
  if is_windows then
    cmd = { 'cmd.exe', '/c', build_file }
  else
    cmd = { '/bin/sh', build_file }
  end

  -- Run asynchronously and stream output
  local job = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data, _)
      for _, line in ipairs(data) do
        if line ~= '' and line ~= nil then
          vim.api.nvim_buf_set_lines(buf, -1, -1, false, { line }) -- Append line
        end
      end
    end,
    on_stderr = function(_, data, _)
      for _, line in ipairs(data) do
        if line ~= '' and line ~= nil then
          vim.api.nvim_buf_set_lines(buf, -1, -1, false, { line }) -- Append (stderr mixed in)
        end
      end
    end,
    on_exit = function(_, code, _)
      local status = code == 0 and 'completed successfully.' or 'failed with exit code: ' .. code
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, { '', 'Build ' .. status })
      -- Lock buffer after execution
      vim.api.nvim_buf_set_option(buf, 'modifiable', false)
      vim.api.nvim_buf_set_option(buf, 'readonly', true)
    end,
  })

  if vim.fn.jobwait({ job }, 0)[1] == -3 then -- Check if job started successfully
    vim.notify('Failed to start build job.', vim.log.levels.ERROR)
    -- Clean up if job failed to start
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, { '', 'Failed to start build job.' })
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(buf, 'readonly', true)
  end
end
vim.keymap.set('', '<C-m>', find_and_run_build_script, { desc = 'Find and run a C build script' })
