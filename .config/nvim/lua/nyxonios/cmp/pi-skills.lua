local cmp = require('cmp')

local M = {}

function M.new()
  return setmetatable({
    skills = nil,
  }, { __index = M })
end

---Only active in Pi external-editor temp files.
function M.is_available()
  local filepath = vim.fn.expand('%:p')
  -- pi-editor creates files like /tmp/pi-editor-XXXXXX/prompt.md
  local is_pi_prompt = vim.fn.fnamemodify(filepath, ':t') == 'prompt.md'
    and filepath:find('pi%-editor%-') ~= nil
  return is_pi_prompt
end

function M.get_position_encoding_kind()
  return 'utf-16'
end

function M.get_trigger_characters()
  return { '/' }
end

function M.get_keyword_pattern()
  -- In Vim regex: one or more non-white characters so the whole
  -- "/skill:commit-message" token is treated as the keyword.
  return [[\S\+]]
end

function M.complete(self, params, callback)
  local line = params.context.cursor_before_line

  -- Only serve completions on lines that start with a slash (e.g. /skill…).
  if not line:match('^%s*/') then
    callback({})
    return
  end

  self:_ensure_skills()

  local items = {}
  local skills = self.skills or {}
  if #skills == 0 then
    callback({})
    return
  end

  for _, skill in ipairs(skills) do
    table.insert(items, {
      label = '/skill:' .. skill.name,
      kind = cmp.lsp.CompletionItemKind.Class,
      detail = skill.description and skill.description:sub(1, 80) or '',
      documentation = skill.description and {
        kind = 'markdown',
        value = string.format('**%s**\n\n%s', skill.name, skill.description),
      } or nil,
      insertText = '/skill:' .. skill.name,
    })
  end

  callback(items)
end

-- Scan all known skill directories and cache the results.
function M:_ensure_skills()
  if self.skills then
    return
  end

  self.skills = {}
  local seen = {}

  local function parse_skill_dir(dir)
    if vim.fn.isdirectory(dir) ~= 1 then
      return
    end

    -- Directories containing SKILL.md
    local mds = vim.fn.globpath(dir, '*/SKILL.md', false, true)
    for _, md in ipairs(mds) do
      local name, desc = M._parse_skill_md(md)
      if name and not seen[name] then
        seen[name] = true
        table.insert(self.skills, { name = name, description = desc })
      end
    end

    -- Root-level .md files that declare themselves as skills
    local root_mds = vim.fn.globpath(dir, '*.md', false, true)
    for _, md in ipairs(root_mds) do
      if vim.fn.fnamemodify(md, ':t') ~= 'SKILL.md' then
        local name, desc = M._parse_skill_md(md)
        if name and not seen[name] then
          seen[name] = true
          table.insert(self.skills, { name = name, description = desc })
        end
      end
    end
  end

  -- Global skill directories
  parse_skill_dir(vim.fn.expand('~/.pi/agent/skills'))
  parse_skill_dir(vim.fn.expand('~/.agents/skills'))

  -- Project-local skill directories (cwd and ancestors up to git root)
  local cwd = vim.fn.getcwd()
  parse_skill_dir(cwd .. '/.pi/skills')
  parse_skill_dir(cwd .. '/.agents/skills')

  local current = cwd
  while current ~= '/' do
    if vim.fn.isdirectory(current .. '/.git') == 1 then
      break
    end
    local parent = vim.fn.fnamemodify(current, ':h')
    if parent == current then
      break
    end
    current = parent
    parse_skill_dir(current .. '/.pi/skills')
    parse_skill_dir(current .. '/.agents/skills')
  end
end

-- Extract `name` and `description` from the YAML frontmatter of a SKILL.md file.
function M._parse_skill_md(filepath)
  local lines = vim.fn.readfile(filepath)
  if not lines or #lines == 0 then
    return nil, nil
  end
  if lines[1] ~= '---' then
    return nil, nil
  end

  local name = nil
  local desc_parts = {}
  local collecting_desc = false
  local desc_indicator = nil -- nil | 'folded' | 'literal'

  for i = 2, #lines do
    local line = lines[i]

    -- End of frontmatter
    if line == '---' then
      break
    end

    -- Continue previous multi-line description block
    if collecting_desc then
      if line:match('^  ') or line:match('^\t') then
        table.insert(desc_parts, (line:gsub('^%s+', '')))
      elseif line == '' then
        if desc_indicator == 'literal' then
          table.insert(desc_parts, '')
        end
      elseif line:match('^[%w_-]+:') then
        -- a new key starts; stop collecting description
        collecting_desc = false
        desc_indicator = nil
      end
    end

    if not collecting_desc then
      local key, value = line:match('^([%w_-]+):%s*(.*)$')
      if key == 'name' then
        name = (value:gsub('^[\'"]', ''):gsub('[\'"]$', '')):match('^%s*(.-)%s*$')
      elseif key == 'description' then
        value = value:gsub('^[\'"]', ''):gsub('[\'"]$', ''):match('^%s*(.-)%s*$')
        if value ~= '' and value ~= '>' and value ~= '|' then
          desc_parts = { value }
          desc_indicator = nil
        elseif value == '>' then
          desc_indicator = 'folded'
          desc_parts = {}
          collecting_desc = true
        elseif value == '|' then
          desc_indicator = 'literal'
          desc_parts = {}
          collecting_desc = true
        else
          -- empty inline value => treat as a folded block
          desc_indicator = 'folded'
          desc_parts = {}
          collecting_desc = true
        end
      end
    end
  end

  local description = nil
  if #desc_parts > 0 then
    if desc_indicator == 'literal' then
      description = table.concat(desc_parts, '\n')
    else
      description = table.concat(desc_parts, ' ')
    end
  end

  return name, description
end

function M:_clear_cache()
  self.skills = nil
end

-- Create one instance, register it with nvim-cmp, and expose debug helpers.
local instance = M.new()
cmp.register_source('pi_skills', instance)

vim.api.nvim_create_user_command('PiSkillsDebug', function()
  local filepath = vim.fn.expand('%:p')
  local is_pi_prompt = vim.fn.fnamemodify(filepath, ':t') == 'prompt.md'
    and filepath:find('pi%-editor%-') ~= nil

  if not is_pi_prompt then
    vim.notify(
      string.format(
        "Pi skills source is NOT active here.\nCurrent file: %s\nExpected: prompt.md inside a pi-editor temp dir.",
        filepath
      ),
      vim.log.levels.WARN
    )
    return
  end

  instance:_clear_cache()
  instance:_ensure_skills()

  local items = instance.skills or {}
  local msg
  if #items == 0 then
    msg = "Active for this buffer, but NO skills were found/loaded."
  else
    local lines = { string.format("Active for this buffer — %d skill(s) loaded:", #items) }
    for _, s in ipairs(items) do
      table.insert(lines, string.format("  /skill:%s  (%s)", s.name, s.description or '<no desc>'))
    end
    msg = table.concat(lines, '\n')
  end

  vim.notify(msg, vim.log.levels.INFO)
end, {})

vim.api.nvim_create_user_command('PiSkillsRefresh', function()
  instance:_clear_cache()
  vim.notify('Pi skills cache refreshed', vim.log.levels.INFO)
end, {})

return M
