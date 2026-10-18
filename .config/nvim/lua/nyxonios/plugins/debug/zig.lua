-- Zig debugging for nvim-dap (plain module, required from ./init.lua).
--
-- Adapters:
--   * lldb-zig  (nix package: ~/dotfiles/nix/pkgs/lldb-zig)
--     Zig-aware LLDB fork — https://github.com/jacobly0/llvm-project (lldb-zig-dev).
--     Renders Zig types natively (slices, optionals, tagged unions, std types)
--     for binaries built by Zig's self-hosted backend — the default backend
--     on x86_64-linux since Zig 0.16. Exposes `zig-lldb-dap` for DAP clients.
--   * codelldb  (generic fallback, adapter registered in ./init.lua via Mason)
--
-- Launch configurations:
--   * Project (build.zig present): `zig build -Doptimize=Debug`, then a picker
--     over zig-out/bin executables.
--   * Single file: `zig build-exe` the current buffer into the nvim cache dir
--     (no build.zig needed — see ~/development/learning-zig).
--   * Tests: `zig test --test-no-exec -femit-bin=...` builds the test runner
--     without executing it, so it can be debugged like any other binary.

local M = {}

-- Nearest project root (containing build.zig) from the current buffer.
local function zig_root()
  local buf = vim.api.nvim_buf_get_name(0)
  local start = (buf ~= '' and vim.fs.dirname(buf)) or vim.uv.cwd()
  local found = vim.fs.find('build.zig', { upward = true, path = start })[1]
  return found and vim.fs.dirname(found) or nil
end

local function zig_cwd()
  return zig_root() or vim.uv.cwd()
end

-- Run a zig command synchronously. Captures stdout *and* stderr (zig
-- reports compile errors on stderr, and vim.fn.system() would swallow them).
-- On failure, raises an error so nvim-dap aborts the launch cleanly with a
-- proper message instead of continuing with a missing `program`.
local function zig_build(cmd, cwd)
  local result = vim.system(cmd, { text = true, cwd = cwd }):wait()
  if result.code ~= 0 then
    local out = vim.trim(((result.stdout or '') .. '\n' .. (result.stderr or '')))
    local exit
    if result.signal and result.signal > 0 then
      exit = ('killed by signal %d (compiler crashed)'):format(result.signal)
    else
      exit = ('exit code %d'):format(result.code)
    end
    if out == '' then
      out = '(no output — likely a compiler crash)'
    end
    error(('`%s` failed (%s):\n%s'):format(table.concat(cmd, ' '), exit, out), 0)
  end
end

local function zig_debug_dir()
  local dir = vim.fn.stdpath 'cache' .. '/zig-debug'
  vim.fn.mkdir(dir, 'p')
  return dir
end

-- zig 0.16.0 has a compiler bug: source with self-referential function
-- return types (e.g. `fn Node(comptime T: type) Node(T)`) can make it emit a
-- corrupt binary while still exiting 0. The debugger then fails with
-- confusing messages like "doesn't contain any 'host' platform architectures".
-- Guard: verify the binary is a real ELF before handing it to the adapter.
local function assert_valid_elf(bin)
  local f = io.open(bin, 'rb')
  if not f then
    error(('expected binary %s to exist after the build'):format(bin), 0)
  end
  local header = f:read(16)
  f:close()
  if not header or #header < 16 or header:sub(1, 4) ~= '\x7fELF' then
    error(
      ('zig emitted a corrupt binary (%s is not a valid ELF). '
        .. 'This is a zig 0.16.0 compiler bug, reproducible with self-referential '
        .. 'function return types, e.g. `fn Node(comptime T: type) Node(T)`. '
        .. 'Fix the source and try again.'):format(bin),
      0
    )
  end
end

-- Decide which binary to debug:
--  * build.zig project → zig build + pick an executable from zig-out/bin
--  * single file        → zig build-exe into the nvim cache dir
local function zig_program()
  local root = zig_root()

  if root ~= nil then
    zig_build({ 'zig', 'build', '-Doptimize=Debug' }, root)
    local bins = vim.tbl_filter(function(p)
      return vim.fn.executable(p) == 1
    end, vim.fn.globpath(root .. '/zig-out/bin', '*', false, true) or {})

    if #bins == 0 then
      error(('No executables found in %s/zig-out/bin'):format(root), 0)
    end
    if #bins == 1 then
      assert_valid_elf(bins[1])
      return bins[1]
    end

    -- Multiple executables: let the user pick (nvim-dap runs this function
    -- inside a coroutine, so we can yield on vim.ui.select).
    local co = coroutine.running()
    if co then
      local cb = vim.schedule_wrap(function(choice)
        coroutine.resume(co, choice)
      end)
      vim.ui.select(bins, {
        prompt = 'Debug binary:',
        format_item = function(p)
          return vim.fn.fnamemodify(p, ':t')
        end,
      }, cb)
      local choice = coroutine.yield()
      if not choice then
        error('No binary selected', 0)
      end
      assert_valid_elf(choice)
      return choice
    end
    assert_valid_elf(bins[1])
    return bins[1]
  end

  -- Single-file mode: compile the current buffer (Debug info kept).
  local file = vim.api.nvim_buf_get_name(0)
  local bin = zig_debug_dir() .. '/' .. vim.fn.fnamemodify(file, ':t:r')
  zig_build({ 'zig', 'build-exe', file, '-femit-bin=' .. bin, '-fno-strip' }, vim.fs.dirname(file))
  assert_valid_elf(bin)
  return bin
end

-- Build the test runner for the current file without running the tests,
-- so it can be debugged (set breakpoints inside `test` blocks freely).
local function zig_test_program()
  local file = vim.api.nvim_buf_get_name(0)
  local bin = zig_debug_dir() .. '/' .. vim.fn.fnamemodify(file, ':t:r') .. '-test'
  zig_build({ 'zig', 'test', file, '--test-no-exec', '-femit-bin=' .. bin, '-fno-strip' }, vim.fs.dirname(file))
  assert_valid_elf(bin)
  return bin
end

local function zig_args()
  return vim.split(vim.fn.input 'Program args: ', ' +')
end

function M.setup()
  local dap = require 'dap'
  local zig_configs = {}

  ---------------------------------------------------------------------------
  -- lldb-zig (Zig-aware LLDB fork via nix)
  ---------------------------------------------------------------------------
  local zig_lldb_dap = vim.fn.exepath 'zig-lldb-dap'
  if zig_lldb_dap ~= '' then
    dap.adapters['lldb-zig'] = {
      type = 'executable',
      command = zig_lldb_dap,
    }

    vim.list_extend(zig_configs, {
      {
        name = 'Zig: debug program (lldb-zig)',
        type = 'lldb-zig',
        request = 'launch',
        program = zig_program,
        cwd = zig_cwd,
        stopOnEntry = false,
        args = {},
      },
      {
        name = 'Zig: debug program with args (lldb-zig)',
        type = 'lldb-zig',
        request = 'launch',
        program = zig_program,
        cwd = zig_cwd,
        stopOnEntry = false,
        args = zig_args,
      },
      {
        name = 'Zig: debug tests in file (lldb-zig)',
        type = 'lldb-zig',
        request = 'launch',
        program = zig_test_program,
        cwd = zig_cwd,
        stopOnEntry = false,
        args = {},
      },
    })
  else
    vim.notify_once(
      'zig-lldb-dap not on PATH.\n'
        .. 'Build/install the nix package: `nix build ~/dotfiles/nix#lldb-zig`, '
        .. 'then rebuild your home configuration.',
      vim.log.levels.WARN
    )
  end

  ---------------------------------------------------------------------------
  -- codelldb fallback (adapter registered in ./init.lua when installed)
  ---------------------------------------------------------------------------
  if dap.adapters.codelldb then
    vim.list_extend(zig_configs, {
      {
        name = 'Zig: debug program (codelldb)',
        type = 'codelldb',
        request = 'launch',
        program = zig_program,
        cwd = zig_cwd,
        stopOnEntry = false,
        args = {},
      },
      {
        name = 'Zig: debug tests in file (codelldb)',
        type = 'codelldb',
        request = 'launch',
        program = zig_test_program,
        cwd = zig_cwd,
        stopOnEntry = false,
        args = {},
      },
    })
  end

  if #zig_configs > 0 then
    dap.configurations.zig = zig_configs
  end
end

-- ---------------------------------------------------------------------------
-- Debug the test under the cursor (<leader>dt), mirroring nvim-dap-go's
-- `debug_test`. Builds a filtered test binary (only tests matching the
-- cursor's test name), runs it under the debug adapter, and reports
-- pass/fail from the exit code + the runner's output lines.
-- ---------------------------------------------------------------------------

-- Extract the test name from a `test "NAME" {` / `test NAME {` declaration.
local function test_name_from_line(line)
  return line:match '^%s*test%s+"(.*)"' or line:match '^%s*test%s+([%w_]+)%s*{'
end

-- Find the test block containing the cursor. Prefers treesitter (exact
-- containment), falls back to a nearest-decl-above regex heuristic.
-- Returns: name (string|nil), lnum (integer|nil), in_test (boolean).
local function enclosing_test()
  local ok, node = pcall(vim.treesitter.get_node)
  if ok and node then
    local n = node
    while n and n:type() ~= 'test_declaration' do
      if n:type() == 'source_file' then
        n = nil
        break
      end
      n = n:parent()
    end
    if n then
      local row = n:start()
      return test_name_from_line(vim.fn.getline(row + 1)), row + 1, true
    end
    return nil, nil, false
  end

  -- treesitter unavailable: nearest `test` decl above the cursor
  for l = vim.api.nvim_win_get_cursor(0)[1], 1, -1 do
    local name = test_name_from_line(vim.fn.getline(l))
    if name then
      return name, l, true -- approximation: not verified containment
    end
  end
  return nil, nil, false
end

function M.debug_test()
  local dap = require 'dap'
  local file = vim.api.nvim_buf_get_name(0)
  if file == '' then
    vim.notify('Save the buffer before debugging its tests', vim.log.levels.WARN)
    return
  end

  local name, _, in_test = enclosing_test()

  local bin = zig_debug_dir() .. '/' .. vim.fn.fnamemodify(file, ':t:r') .. '-test'
  local cmd = { 'zig', 'test', file, '--test-no-exec', '-femit-bin=' .. bin, '-fno-strip' }
  -- --test-filter is a case-sensitive substring match against the registered
  -- test names (instantiation-prefixed for nested/generic tests).
  if in_test and name then
    vim.list_extend(cmd, { '--test-filter', name })
  elseif not in_test then
    vim.notify('Cursor is not inside a test block — debugging all tests in the file', vim.log.levels.INFO)
  end

  zig_build(cmd, vim.fs.dirname(file)) -- raises with zig's diagnostics on failure
  assert_valid_elf(bin)

  -- Capture runner output through DAP output events; used with the exit code
  -- to report the result of the test under the cursor.
  local out = {}
  local key = 'zig_dt'
  local function cleanup()
    dap.listeners.after.event_output[key] = nil
    dap.listeners.after.event_exited[key] = nil
    dap.listeners.after.event_terminated[key] = nil
  end
  dap.listeners.after.event_output[key] = function(_, body)
    if body and body.output then
      for token in body.output:gmatch '[^\r\n]+' do
        out[#out + 1] = token
      end
    end
  end
  dap.listeners.after.event_terminated[key] = cleanup
  dap.listeners.after.event_exited[key] = function(_, body)
    cleanup()
    local code = (body and body.exitCode) or -1
    local passed = code == 0
    if in_test and name then
      for _, l in ipairs(out) do
        if l:find(name, 1, true) then
          if l:find('...OK', 1, true) then
            passed = true
          elseif l:find('FAIL', 1, true) then
            passed = false
          end
        end
      end
    end
    local label = (in_test and name) and ('test "' .. name .. '"') or 'tests in file'
    if passed then
      vim.notify('✅ ' .. label .. ' passed', vim.log.levels.INFO)
    else
      vim.notify('❌ ' .. label .. ' failed (exit ' .. tostring(code) .. ') — see the dap-ui console', vim.log.levels.WARN)
    end
  end

  dap.run {
    name = 'Zig: debug ' .. ((in_test and name) and ('test: ' .. name) or 'all tests'),
    type = 'lldb-zig',
    request = 'launch',
    program = bin,
    cwd = vim.fs.dirname(file),
    stopOnEntry = false,
    args = {},
  }
end

return M
