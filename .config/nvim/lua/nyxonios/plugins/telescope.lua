-- Telescope live_grep in git root
-- Function to find the git root directory based on the current buffer's path
local function find_git_root()
  -- Use the current buffer's path as the starting point for the git search
  local current_file = vim.api.nvim_buf_get_name(0)
  local current_dir
  local cwd = vim.fn.getcwd()
  -- If the buffer is not associated with a file, return nil
  if current_file == '' then
    current_dir = cwd
  else
    -- Extract the directory from the current file's path
    current_dir = vim.fn.fnamemodify(current_file, ':h')
  end

  -- Find the Git root directory from the current file's path
  local git_root = vim.fn.systemlist('git -C ' .. vim.fn.escape(current_dir, ' ') .. ' rev-parse --show-toplevel')[1]
  if vim.v.shell_error ~= 0 then
    print 'Not a git repository. Searching on current working directory'
    return cwd
  end
  return git_root
end

-- ── Smart prompt syntax: `query  .ext` ─────────────────────────────────────
-- End a prompt with two spaces and a file extension to filter by extension:
--   `foo  .go`        -> search "foo", only in .go files
--   `foo  .go,.lua`   -> several extensions at once
-- `foo  go` / `foo  *.go` also work. Without the two-space suffix the
-- pickers behave exactly like the stock ones.
--
-- Splits a prompt into (query, { extensions }); returns the full prompt and
-- nil when no two-space pattern is present (or the ext part is unfinished).
local function parse_prompt(prompt)
  if type(prompt) ~= 'string' then
    return '', nil
  end

  local gap = prompt:find('  ', 1, true)
  if not gap then
    return prompt, nil
  end

  local query = prompt:sub(1, gap - 1)
  local ext_part = vim.trim(prompt:sub(gap + 2))

  if ext_part ~= '' and not ext_part:find '%s' then
    local seen = {}
    local exts = {}
    for token in ext_part:gmatch '[^,]+' do
      token = token:gsub('^%*', ''):gsub('^%.', ''):lower()
      if token ~= '' and not seen[token] then
        seen[token] = true
        table.insert(exts, token)
      end
    end
    if #exts > 0 then
      return query, exts
    end
  end

  -- Two spaces typed but no usable extension yet (`foo  `, `foo  .`):
  -- treat it as the query-only state before the filter kicks in, so results
  -- don't blink while the extension is being typed.
  return query, nil
end

-- find_files sorter that understands `query  .ext`: drops entries whose
-- extension does not match and scores the query part with fzy, exactly like
-- telescope's default file sorter.
local function smart_file_sorter(opts)
  opts = opts or {}
  local sorters = require 'telescope.sorters'
  local fzy = opts.fzy_mod or require 'telescope.algos.fzy'
  local OFFSET = -fzy.get_score_floor()

  -- Telescope's discard cache assumes prompts only ever grow in ways that keep
  -- previously filtered entries filtered (`Sorter:_start` compares the raw
  -- prompts). The `  .ext` syntax breaks that: typing `lazy ` (a single space)
  -- discards every entry, while the next keystroke makes `lazy  ` valid again.
  -- Reset the cache whenever the parsed query is not a plain extension of the
  -- previously seen one, so those entries get a chance to be re-scored.
  local prev_query, prev_exts

  return sorters.Sorter:new {
    discard = true,
    start = function(self, prompt)
      local query, exts = parse_prompt(prompt)
      if prev_query ~= nil then
        local query_grew = prev_query == query or (#prev_query <= #query and query:sub(1, #prev_query) == prev_query)
        -- an extension list appearing or changing always invalidates
        -- (e.g. `js` was filtered out under `j`)
        local exts_same = prev_exts == nil and exts == nil
        if not query_grew or not exts_same then
          self._discard_state.filtered = {}
        end
      end
      prev_query, prev_exts = query, exts
    end,
    scoring_function = function(_, prompt, line, entry)
      local query, exts = parse_prompt(prompt)

      if exts then
        local ext = vim.fn.fnamemodify(tostring(entry.value), ':e'):lower()
        local keep = false
        for _, e in ipairs(exts) do
          -- substring of the file ending: `.js` keeps `.json` as well
          if ext:find(e, 1, true) then
            keep = true
            break
          end
        end
        if not keep then
          return -1
        end
        if query == '' then
          return 1 -- only an extension given: list everything that matches
        end
      end

      if query == '' then
        return 1
      end
      if not fzy.has_match(query, line) then
        return -1
      end

      local fzy_score = fzy.score(query, line)
      if fzy_score == fzy.get_score_min() then
        return 1
      end
      return 1 / (fzy_score + OFFSET)
    end,

    highlighter = function(_, prompt, display)
      local query = parse_prompt(prompt)
      if query == '' or not fzy.has_match(query, display) then
        return {}
      end
      return fzy.positions(query, display)
    end,
  }
end

-- find_files, but the prompt may end in `  .ext` to restrict the extension
local function smart_find_files(opts)
  opts = opts or {}
  opts.sorter = opts.sorter or smart_file_sorter(opts)
  require('telescope.builtin').find_files(opts)
end

-- live_grep, but the prompt may end in `  .ext`: the extension part is turned
-- into `--glob *.<ext>` arguments for ripgrep.
local function smart_live_grep(opts)
  opts = opts or {}
  local conf = require('telescope.config').values
  local finders = require 'telescope.finders'
  local make_entry = require 'telescope.make_entry'
  local pickers = require 'telescope.pickers'
  local utils = require 'telescope.utils'
  local sorters = require 'telescope.sorters'

  local vimgrep_arguments = opts.vimgrep_arguments or conf.vimgrep_arguments
  if vim.fn.executable(vimgrep_arguments[1]) == 0 then
    vim.notify('smart_live_grep: ' .. vimgrep_arguments[1] .. ' is not installed', vim.log.levels.WARN)
    return
  end

  opts.cwd = opts.cwd and utils.path_expand(opts.cwd) or vim.uv.cwd()

  local search_dirs = opts.search_dirs
  if search_dirs then
    for i, path in ipairs(search_dirs) do
      search_dirs[i] = utils.path_expand(path)
    end
  end

  -- Keep in sync with `pickers.live_grep` in telescope.setup below
  local additional_args = opts.additional_args or { '--hidden', '-L' }
  if type(additional_args) == 'function' then
    additional_args = additional_args(opts)
  end

  local live_grepper = finders.new_job(function(prompt)
    if not prompt or prompt == '' then
      return nil
    end

    local query, exts = parse_prompt(prompt)
    if query == '' then
      return nil -- extension only, nothing to grep for yet
    end

    local args = vim.deepcopy(vimgrep_arguments)
    vim.list_extend(args, additional_args)
    for _, e in ipairs(exts or {}) do
      table.insert(args, '-g')
      -- trailing `*` so that the token matches anywhere in the ending
      -- (like `lazy  .js` matching `lazy-lock.json`)
      table.insert(args, '*.' .. e .. '*')
    end
    table.insert(args, '--')
    table.insert(args, query)
    if search_dirs then
      vim.list_extend(args, search_dirs)
    end
    return args
  end, opts.entry_maker or make_entry.gen_from_vimgrep(opts), nil, opts.cwd)

  local fzy = require 'telescope.algos.fzy'

  pickers
    .new(opts, {
      prompt_title = 'Live Grep (query  .ext)',
      finder = live_grepper,
      previewer = conf.grep_previewer(opts),
      -- Everything ripgrep returns is already a match: accept all entries and
      -- only highlight the query part of the prompt.
      sorter = sorters.Sorter:new {
        scoring_function = function()
          return 1
        end,
        highlighter = function(_, prompt, display)
          local query = parse_prompt(prompt)
          if query == '' or not fzy.has_match(query, display) then
            return {}
          end
          return fzy.positions(query, display)
        end,
      },
      push_cursor_on_edit = true,
    })
    :find()
end

-- Custom live_grep function to search in git root
local function live_grep_git_root()
  local git_root = find_git_root()
  if git_root then
    smart_live_grep {
      search_dirs = { git_root },
    }
  end
end

vim.api.nvim_create_user_command('LiveGrepGitRoot', live_grep_git_root, {})

return {
  'nvim-telescope/telescope.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    { 'nvim-telescope/telescope-ui-select.nvim' },
    { 'nvim-tree/nvim-web-devicons' },
  },
  config = function()
    local telescope = require 'telescope'
    local previewers = require 'telescope.previewers'

    -- Prevent crashes on macOS by skipping image previews Telescope can't handle
    local image_exts = {
      svg = true,
      png = true,
      jpg = true,
      jpeg = true,
      gif = true,
      webp = true,
      bmp = true,
    }
    local new_maker = function(filepath, bufnr, opts)
      local ext = vim.fn.fnamemodify(filepath, ':e'):lower()
      if image_exts[ext] then
        return
      end
      previewers.buffer_previewer_maker(filepath, bufnr, opts)
    end

    telescope.setup {
      pickers = {
        find_files = {
          hidden = true,
          additional_args = { '--hidden', '-L' },
        },
        live_grep = {
          additional_args = { '--hidden', '-L' },
        },
      },
      defaults = {
        buffer_previewer_maker = new_maker,
        file_ignore_patterns = {
          '.git',
          'node_modules',
          'vendor',
          '.zig-cache',
          'zig-out',
        },
      },
      extensions = {
        ['ui-select'] = {
          require('telescope.themes').get_dropdown(),
        },
      },
    }
    -- Enable telescope fzf native, if installed
    pcall(telescope.load_extension, 'fzf')
    pcall(telescope.load_extension, 'ui-select')

    local builtin = require 'telescope.builtin'

    vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = '[F]ind [H]elp' })
    vim.keymap.set('n', '<leader>fk', builtin.keymaps, { desc = '[F]ind [K]eymaps' })

    vim.keymap.set('n', '<leader>ff', function()
      smart_find_files { hidden = true }
    end, { desc = '[F]ind [F]iles (  .ext)' })
    vim.keymap.set('n', '<leader>fg', function()
      smart_live_grep()
    end, { desc = '[F]ind [G]rep (  .ext)' })
    vim.keymap.set('n', '<leader>fG', ':LiveGrepGitRoot<cr>', { desc = '[F]ind by [G]rep in Git Root' })
    vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = '[F]ind in [B]uffers' })
    vim.keymap.set('n', '<leader>fd', builtin.diagnostics, { desc = '[F]ind [D]iagnostics' })

    vim.keymap.set('n', '<leader>/', function()
      -- You can pass additional configuration to telescope to change theme, layout, etc.
      require('telescope.builtin').current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
        winblend = 10,
        previewer = false,
      })
    end, { desc = '[/] Fuzzily search in current buffer' })

    vim.keymap.set('n', '<leader>fn', function()
      smart_find_files { cwd = vim.fn.stdpath 'config' }
    end, { desc = '[F]ind [N]eovim files' })
  end,
}
