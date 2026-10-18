-- Debugging setup: nvim-dap + nvim-dap-ui (general)
--
-- Language-specific debugging lives in sibling modules and is registered from
-- this spec's config function:
--   * zig.lua — Zig adapters + launch configurations (lldb-zig via nix,
--     codelldb fallback, single-file and test-debug workflows)
--
-- TODO (carried over from previous config):
--   * Load a .debug.env file from the project root into debug sessions.
--   * Support go build flags in the go debugger (useful for integration tests).

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

    require('dapui').setup()

    ---------------------------------------------------------------------------
    -- Generic adapters
    ---------------------------------------------------------------------------

    -- codelldb — generic LLDB-family adapter (Zig/C/C++/Rust).
    -- Install via `:MasonInstall codelldb` (≥1.11 supports the stdio form).
    -- Zig configs that use it register in ./zig.lua; it is also available for
    -- other filetypes if wanted.
    local codelldb = vim.fn.exepath 'codelldb'
    if codelldb ~= '' then
      dap.adapters.codelldb = {
        type = 'executable',
        command = codelldb,
      }
    end

    ---------------------------------------------------------------------------
    -- Language-specific adapters + configurations
    ---------------------------------------------------------------------------

    require('nyxonios.plugins.debug.zig').setup()

    ---------------------------------------------------------------------------
    -- dap-ui auto open/close
    ---------------------------------------------------------------------------
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

    ---------------------------------------------------------------------------
    -- Keymaps
    ---------------------------------------------------------------------------

    vim.keymap.set('n', '<leader>dt', function()
      local ft = vim.bo.filetype
      if ft == 'zig' then
        require('nyxonios.plugins.debug.zig').debug_test()
      elseif ft == 'go' then
        dapgo.debug_test()
      else
        vim.notify('No test debugging configured for ' .. ft .. ' buffers', vim.log.levels.INFO)
      end
    end, { desc = '(d)ebug (t)est under cursor' })

    vim.keymap.set('n', '<leader>dl', dap.run_last, {}) -- (d)ebug run (l)ast
    vim.keymap.set('n', '<leader>dr', dap.restart, {}) -- (d)ebug (r)estart
    vim.keymap.set('n', '<leader>dq', dap.terminate, {}) -- (d)ebug (q)uit

    vim.keymap.set('n', '<leader>sb', dap.toggle_breakpoint, {}) -- (s)et (b)reakpoint
    vim.keymap.set('n', '<leader>cb', dap.clear_breakpoints, {}) -- (c)lear (b)reakpoints
    vim.keymap.set('n', '<leader>rc', dap.run_to_cursor, {})
    vim.keymap.set('n', '<leader>c', dap.continue, {})
    vim.keymap.set('n', '<leader>si', dap.step_into, {})
    vim.keymap.set('n', '<leader>s', dap.step_over, {}) -- (s)tep over
    vim.keymap.set('n', '<leader>tu', dapui.toggle, {}) -- (t)oggle (u)i

    -- Zig: pick a launch config for the current context
    vim.keymap.set('n', '<leader>dz', function()
      dap.continue()
    end, { desc = 'Zig: debug (pick config)' })
  end,
}
