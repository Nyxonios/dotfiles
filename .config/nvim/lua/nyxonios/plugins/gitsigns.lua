return {
  'lewis6991/gitsigns.nvim',
  opts = {
    signs = {
      add = { text = '+' },
      change = { text = '~' },
      delete = { text = '_' },
      topdelete = { text = '‾' },
      changedelete = { text = '~' },
    },
    on_attach = function(bufnr)
      local gitsigns = require 'gitsigns'

      local function map(mode, l, r, opts)
        opts = opts or {}
        opts.buffer = bufnr
        vim.keymap.set(mode, l, r, opts)
      end

      -- Navigation
      map('n', ']c', function()
        if vim.wo.diff then
          vim.cmd.normal { ']c', bang = true }
        else
          gitsigns.nav_hunk('next', { target = 'all' })
        end
      end, { desc = 'Jump to next git [c]hange' })

      map('n', '[c', function()
        if vim.wo.diff then
          vim.cmd.normal { '[c', bang = true }
        else
          gitsigns.nav_hunk('prev', { target = 'all' })
        end
      end, { desc = 'Jump to previous git [c]hange' })

      -- Actions
      map('n', '<leader>hs', gitsigns.stage_hunk, { desc = 'git [s]tage hunk' })
      map('n', '<leader>hr', gitsigns.reset_hunk, { desc = 'git [r]eset hunk' })
      map('v', '<leader>hs', function()
        gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
      end, { desc = 'git [s]tage hunk' })
      map('v', '<leader>hr', function()
        gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
      end, { desc = 'git [r]eset hunk' })
      map('n', '<leader>hS', gitsigns.stage_buffer, { desc = 'git [S]tage buffer' })
      map('n', '<leader>hR', gitsigns.reset_buffer, { desc = 'git [R]eset buffer' })
      map('n', '<leader>hp', gitsigns.preview_hunk, { desc = 'git [p]review hunk' })
      map('n', '<leader>hb', gitsigns.blame_line, { desc = 'git [b]lame line' })
      map('n', '<leader>hd', function()
        -- Find windows in this tab showing a gitsigns diff buffer
        local gs_wins = {}
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
          if vim.startswith(bufname, 'gitsigns://') then
            gs_wins[#gs_wins + 1] = win
          end
        end

        -- No diff open yet: show it
        if #gs_wins == 0 then
          gitsigns.diffthis()
          return
        end

        -- Diff open: close it. If pressed from inside the diff split,
        -- move out of it first.
        if vim.tbl_contains(gs_wins, vim.api.nvim_get_current_win()) then
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if not vim.tbl_contains(gs_wins, win) then
              vim.api.nvim_set_current_win(win)
              break
            end
          end
        end

        -- Restore window-local diff options (scrollbind, foldmethod, ...)
        vim.cmd.diffoff()

        -- Closing the split disables diff in the source window via
        -- gitsigns' own BufHidden autocmd.
        for _, win in ipairs(gs_wins) do
          pcall(vim.api.nvim_win_close, win, false)
        end
      end, { desc = 'git [d]iff against index (toggle)' })
      map('n', '<leader>hD', function()
        gitsigns.diffthis '@'
      end, { desc = 'git [D]iff against last commit' })

      -- Toggles
      map('n', '<leader>tb', gitsigns.toggle_current_line_blame, { desc = '[T]oggle git show [b]lame line' })
      map('n', '<leader>td', gitsigns.preview_hunk_inline, { desc = '[T]oggle [d]eleted hunk inline preview' })
    end,
  },
}
