vim.api.nvim_create_user_command('Cppath', function(opts)
  local path = vim.api.nvim_buf_get_name(0)
  if path == '' then
    vim.notify('Cppath: no file in current buffer', vim.log.levels.WARN, {})
    return
  end

  local has_range = opts.range > 0
  if has_range then
    path = path .. ' L' .. opts.line1 .. '-L' .. opts.line2
  end

  vim.fn.setreg('"', path)
  vim.fn.setreg('+', path)
  vim.notify('Copied: ' .. path, vim.log.levels.INFO, {})
end, { desc = 'Copy the absolute path of the current buffer to the default register and clipboard', range = true })

vim.api.nvim_create_user_command('Uuid', function()
  local handle = io.popen("uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '\n'", 'r')
  if handle then
    local result = handle:read '*a'
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))

    -- Plus one in the column since I want to insert the same way a
    -- regular paste would.
    vim.api.nvim_buf_set_text(0, row - 1, col + 1, row - 1, col + 1, { result })
    vim.notify('Uuid: ' .. result, vim.log.levels.INFO, {})
  else
    vim.notify('Uuid: could not get handle', vim.log.levels.ERROR, {})
  end
end, { desc = 'Inserts a UUID at the current cursor position' })

-- character table string
vim.api.nvim_create_user_command('DecodeBase64File', function()
  local content = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(0), false)
  local text = table.concat(content, '\n')
  local decoded = Base64dec(text)
end, { desc = 'Decodes a base64 string' })

vim.api.nvim_create_user_command('AlignMarkdownTable', function(opts)
  local start_line = opts.line1
  local end_line = opts.line2
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

  if #lines < 2 then
    vim.notify('AlignMarkdownTable: selection must contain at least a header and separator row', vim.log.levels.WARN)
    return
  end

  local rows = {}
  local is_separator = {}

  for _, line in ipairs(lines) do
    if line:match('%S') then
      local cells = {}
      local trimmed_line = line:gsub('|$', '')
      local is_sep = true
      for cell in trimmed_line:gmatch('|([^|]*)') do
        local trimmed = cell:gsub('^%s+', ''):gsub('%s+$', '')
        table.insert(cells, trimmed)
        if trimmed ~= '' and not trimmed:match('^%-+$') then
          is_sep = false
        end
      end
      while #cells > 0 and cells[#cells] == '' do
        table.remove(cells)
      end
      if #cells > 0 then
        table.insert(rows, cells)
        table.insert(is_separator, is_sep)
      end
    end
  end

  if #rows < 2 then
    vim.notify('AlignMarkdownTable: could not parse table', vim.log.levels.WARN)
    return
  end

  local col_count = #rows[1]
  local col_widths = {}
  for i = 1, col_count do
    col_widths[i] = 0
  end

  for row_idx, row in ipairs(rows) do
    if not is_separator[row_idx] then
      for i, cell in ipairs(row) do
        if i <= col_count then
          col_widths[i] = math.max(col_widths[i], vim.fn.strdisplaywidth(cell))
        end
      end
    end
  end

  local formatted_lines = {}
  for row_idx, row in ipairs(rows) do
    local formatted_cells = {}
    for i = 1, col_count do
      if is_separator[row_idx] then
        table.insert(formatted_cells, string.rep('-', col_widths[i] + 2))
      else
        local cell = row[i] or ''
        table.insert(formatted_cells, ' ' .. cell .. string.rep(' ', col_widths[i] - vim.fn.strdisplaywidth(cell)) .. ' ')
      end
    end
    table.insert(formatted_lines, '|' .. table.concat(formatted_cells, '|') .. '|')
  end

  vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, formatted_lines)
end, {
  desc = 'Aligns a markdown table within the selected range',
  range = true,
})

-- Utility functions

local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- Base64enc encodes a string as base64.
---@param data string
---@return string
function Base64enc(data)
  return (
    (data:gsub('.', function(x)
      local r, b = '', x:byte()
      for i = 8, 1, -1 do
        r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0')
      end
      return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
      if #x < 6 then
        return ''
      end
      local c = 0
      for i = 1, 6 do
        c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0)
      end
      return b:sub(c + 1, c + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1]
  )
end

-- Base64dec decodes a string from base64 encoding.
---@param data string
---@return string
function Base64dec(data)
  data = string.gsub(data, '[^' .. b .. '=]', '')
  return (
    data
      :gsub('.', function(x)
        if x == '=' then
          return ''
        end
        local r, f = '', (b:find(x) - 1)
        for i = 6, 1, -1 do
          r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0')
        end
        return r
      end)
      :gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x ~= 8 then
          return ''
        end
        local c = 0
        for i = 1, 8 do
          c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0)
        end
        return string.char(c)
      end)
  )
end
