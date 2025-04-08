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
  end,
}
