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

  -- Run the build.sh script in its directory without changing Neovim's global cwd
  local result = vim.system({ './build.sh' }, { cwd = dir }):wait()
  if result.code == 0 then
    vim.notify('Build succeeded in ' .. dir, vim.log.levels.INFO)
  else
    local output_msg = 'Build failed in ' .. dir .. ' with exit code ' .. result.code
    if result.stdout and result.stdout ~= '' then
      output_msg = output_msg .. '\nSTDOUT:\n' .. result.stdout
    end
    vim.notify(output_msg, vim.log.levels.ERROR)
  end
end

return M
