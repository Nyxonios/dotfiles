-- Create a script that can load a .debug.env file from the project root
-- and use it to load in envs into the debug session.
--
-- Create a function/config/command/something that can accept
-- go build flags when starting the go debugger. This would help
-- a lot when debugging integration tests as they are usually behind
-- a build flag.
return {
  'mfussenegger/nvim-dap',
  dependencies = {
    'rcarriga/nvim-dap-ui',
    'leoluz/nvim-dap-go',
    'theHamsta/nvim-dap-virtual-text',
    'nvim-neotest/nvim-nio',
    'ray-x/guihua.lua',
  },
  config = function()
    local dap = require 'dap'
    local dapui = require 'dapui'
    local dapgo = require 'dap-go'
    dapgo.setup()
    print 'Setting up debug'

    require('dapui').setup()

    -- CODELLB ADAPTER for Zig (and C/C++/Rust)
    -- Install codelldb via one of:
    --   macOS: brew install llvm (includes lldb, codelldb usually via extension)
    --   Alternatively download VSCode codelldb extension and point to the binary
    --   https://github.com/vadimcn/codelldb/releases
    dap.adapters.codelldb = {
      type = 'server',
      port = '${port}',
      executable = {
        -- Adjust this path to your codelldb location:
        command = vim.fn.exepath 'codelldb' or '/usr/local/bin/codelldb',
        args = { '--port', '${port}' },
      },
    }

    -- ZIG CONFIGURATION
    dap.configurations.zig = {
      {
        name = 'Debug current Zig project',
        type = 'codelldb',
        request = 'launch',
        program = function()
          -- Build first, then debug
          vim.fn.system 'zig build'
          -- Try to find the binary in standard zig output paths
          local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ':t')
          local candidates = {
            'zig-out/bin/' .. project_name,
            'zig-out/bin/main',
            'zig-cache/bin/' .. project_name,
            'zig-cache/bin/main',
          }
          for _, path in ipairs(candidates) do
            if vim.fn.filereadable(path) == 1 then
              return vim.fn.getcwd() .. '/' .. path
            end
          end
          -- Fallback: ask user
          return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
        end,
        cwd = '${workspaceFolder}',
        stopOnEntry = false,
        args = {},
        env = function()
          local variables = {}
          for k, v in pairs(vim.fn.environ()) do
            table.insert(variables, string.format('%s=%s', k, v))
          end
          return variables
        end,
      },
      {
        name = 'Debug Zig with args',
        type = 'codelldb',
        request = 'launch',
        program = function()
          vim.fn.system 'zig build'
          return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/zig-out/bin/', 'file')
        end,
        cwd = '${workspaceFolder}',
        stopOnEntry = false,
        args = function()
          local args_string = vim.fn.input('Arguments: ')
          return vim.split(args_string, ' +')
        end,
      },
    }

    dap.listeners.before.attach.dapui_config = function()
      dapui.open()
    end
    dap.listeners.before.launch.dapui_config = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated.dapui_config = function()
      dapui.close()
    end
    dap.listeners.before.event_exited.dapui_config = function()
      dapui.close()
    end

    vim.keymap.set('n', '<leader>dt', dapgo.debug_test, {})

    vim.keymap.set('n', '<leader>dl', dap.run_last, {}) -- (d)bug run (l)ast
    vim.keymap.set('n', '<leader>dr', dap.restart, {}) -- (d)ebug (r)estart
    vim.keymap.set('n', '<leader>dq', dap.terminate, {}) -- (d)ebug (q)uit

    vim.keymap.set('n', '<leader>sb', dap.toggle_breakpoint, {}) -- (s)et (b)reakpoint
    vim.keymap.set('n', '<leader>cb', dap.clear_breakpoints, {}) -- (c)lear (b)reakpoints
    vim.keymap.set('n', '<leader>rc', dap.run_to_cursor, {})
    vim.keymap.set('n', '<leader>c', dap.continue, {})
    vim.keymap.set('n', '<leader>si', dap.step_into, {})
    vim.keymap.set('n', '<leader>s', dap.step_over, {}) -- (s)tep over
    vim.keymap.set('n', '<leader>tu', dapui.toggle, {}) -- (t)oggle (u)i

    -- Zig specific keymaps
    vim.keymap.set('n', '<leader>dz', function()
      dap.continue()
    end, { desc = '(d)ebug (z)ig current project' })
  end,
}
