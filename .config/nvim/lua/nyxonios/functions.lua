local M = {}

function M.run_build_script()
  -- Get the current working directory as the starting point (workspace folder)
  local start_dir = vim.fn.getcwd()
  if start_dir == '' then
    vim.notify('Current working directory not available', vim.log.levels.WARN)
    return
  end

  -- Recursively search upward for build.sh
  local paths = vim.fs.find('build.sh', { upward = true, path = start_dir })
  if #paths == 0 then
    vim.notify('No build.sh file found searching upward from ' .. start_dir, vim.log.levels.WARN)
    return
  end

  -- Use the first (closest) match
  local build_path = paths[1]
  local dir = vim.fn.fnamemodify(build_path, ':h')

  -- Save the current window ID to switch back later if desired
  local prev_win_id = vim.api.nvim_get_current_win()

  -- Open a new horizontal split below with a new buffer
  vim.cmd 'belowright new'

  -- Get the buffer number of the new window
  local bufnr = vim.api.nvim_get_current_buf()

  -- Define the command to run
  local cmd = './build.sh'

  -- Start the terminal job in the new buffer
  local job_id = vim.fn.jobstart(cmd, {
    cwd = dir,
    -- term = true,
    on_exit = function(_, code, _)
      local msg = 'Build in ' .. dir
      if code == 0 then
        vim.notify(msg .. ' succeeded', vim.log.levels.INFO)
      else
        vim.notify(msg .. ' failed with exit code ' .. code, vim.log.levels.ERROR)
      end
    end,
  })

  if job_id == 0 then
    vim.notify('Failed to start terminal job', vim.log.levels.ERROR)
    return
  end

  -- Optionally rename the buffer for clarity
  vim.api.nvim_buf_set_name(bufnr, 'build-output-' .. vim.fn.fnamemodify(dir, ':t'))

  -- Start in normal mode (not insert mode) for the terminal
  vim.cmd 'startinsert!'

  -- Optionally switch back to the previous window to continue editing
  -- Uncomment the next line if you want to return focus to the original window
  vim.api.nvim_set_current_win(prev_win_id)

  -- -- Get the current working directory as the starting point (workspace folder)
  -- local start_dir = vim.fn.getcwd()
  -- if start_dir == '' then
  --   vim.notify('Current working directory not available', vim.log.levels.WARN)
  --   return
  -- end
  --
  -- -- Recursively search upward for build.sh
  -- local paths = vim.fs.find('build.sh', { upward = true, path = start_dir })
  -- if #paths == 0 then
  --   vim.notify('No build.sh file found searching upward from ' .. start_dir, vim.log.levels.WARN)
  --   return
  -- end
  --
  -- -- Use the first (closest) match
  -- local build_path = paths[1]
  -- local dir = vim.fn.fnamemodify(build_path, ':h')
  --
  -- -- Run the build.sh script in its directory without changing Neovim's global cwd
  -- local result = vim.system({ './build.sh' }, { cwd = dir }):wait()
  -- if result.code == 0 then
  --   vim.notify('Build succeeded in ' .. dir, vim.log.levels.INFO)
  -- else
  --   local output_msg = 'Build failed in ' .. dir .. ' with exit code ' .. result.code
  --   if result.stdout and result.stdout ~= '' then
  --     output_msg = output_msg .. '\nSTDOUT:\n' .. result.stdout
  --   end
  --   vim.notify(output_msg, vim.log.levels.ERROR)
  -- end
end

return M
