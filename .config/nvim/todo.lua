-- Quick-todo popup config.
-- Launched by hyprland.lua (CAPS+T, the remapped hyper/MOD3 key) --
--   ghostty --title=nvim-todo -e nvim -u ~/.config/nvim/todo.lua ~/todo.md
--
-- Standalone on purpose: no plugins, ~30ms startup, and the Esc mapping
-- below never leaks into your normal nvim sessions.
--
-- In the popup:
--   <Enter>  new list item below (in insert mode it never splits a line)
--   <Esc>    from insert mode: back to normal mode (as usual)
--   <Esc>    in normal mode:   save + hide the popup (hyprland "todo" scratchpad)
--   CAPS+T (hyprland-side): hide/show instantly from any mode

-- Keep the window title stable so the hyprland window rule and the
-- get_windows filter keep matching this window for its whole lifetime.
vim.opt.title = true
vim.opt.titlestring = "nvim-todo"

-- Minimal, distraction-free editing
local opt = vim.opt
opt.number = false
opt.relativenumber = false
opt.wrap = true
opt.linebreak = true -- soft-wrap long items nicely instead of spilling over
opt.signcolumn = "yes:1" -- stable horizontal space even with marks
opt.laststatus = 0 -- no statusline: popup look
opt.showmode = false -- no "-- INSERT --" noise
opt.swapfile = false -- never nag about swap recovery on fast open/close
opt.shortmess:append "A"
opt.updatetime = 200 -- make the autosave below kick in quickly

-- Legacy markdown highlighting without treesitter/plugins
vim.cmd "filetype plugin indent on"
vim.cmd "syntax enable"

local group = vim.api.nvim_create_augroup("TodoPopup", { clear = true })

-- ------------------------------------------------------------------
-- Day sections: "# YYYY-MM-DD" headers, newest day at the top.
-- On every open: wipe unfilled checklist slots from last time, make sure
-- today's header exists (inserting it on top), and drop the cursor on a
-- fresh "- [ ] " slot at the end of today's block, ready to append.
-- ------------------------------------------------------------------

local function today_header()
	return "# " .. os.date "%Y-%m-%d"
end

local function is_day_header(line)
	return line:match "^#%s*%d%d%d%d%-%d%d%-%d%d%s*$" ~= nil
end

local function is_unfilled_item(line)
	return line:match "^%s*%-%s*%[.%]%s*$" ~= nil
end

-- Blank out checklist lines that never got any text (aborted entries/leftover
-- slots). The blank doubles as a section separator, and open_today() re-creates
-- today's slot if needed, so nothing is lost.
local function prune_unfilled_items()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local keep = {}
	local prev_blank = false
	for _, l in ipairs(lines) do
		local blank = l == "" or is_unfilled_item(l)
		if blank and prev_blank then
			-- collapse consecutive blanks (avoids separator creep over reopens)
		else
			keep[#keep + 1] = blank and "" or l
		end
		prev_blank = blank
	end
	if #keep ~= #lines then
		vim.api.nvim_buf_set_lines(0, 0, -1, false, keep)
	end
end

local function open_today()
	prune_unfilled_items()

	local header = today_header()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local header_lnum = nil -- 1-based
	for i, l in ipairs(lines) do
		if l == header then
			header_lnum = i
			break
		end
	end

	if not header_lnum then
		-- Today's block goes on top; a single blank line separates it from older days
		local block = { header }
		if lines[1] ~= "" then
			block[#block + 1] = ""
		end
		vim.api.nvim_buf_set_lines(0, 0, 0, false, block)
		header_lnum = 1
	end

	-- Walk to the end of today's block: the first blank line, the next
	-- day's header, or EOF. That boundary is where a fresh item slot goes.
	local total = vim.api.nvim_buf_line_count(0)
	local slot_lnum = header_lnum + 1
	for i = header_lnum + 1, total do
		local l = vim.fn.getline(i)
		if l == "" or is_day_header(l) then
			break
		end
		slot_lnum = i + 1
	end

	-- Fresh "- [ ] " slot at the boundary. If the boundary is a blank line it
	-- stays below the slot, keeping the day separator intact.
	vim.api.nvim_buf_set_lines(0, slot_lnum - 1, slot_lnum - 1, false, { "- [ ] " })

	-- Land on the slot, ready to type
	vim.cmd("normal! " .. slot_lnum .. "G$")
	vim.cmd "startinsert!"
end

-- Open/groom the list every time the popup starts
vim.api.nvim_create_autocmd("VimEnter", {
	group = group,
	callback = open_today,
})

-- Autosave whenever idle or unfocused, so closing the popup with
-- CAPS+T (hyprland never tells nvim) can't lose more than ~200ms.
vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI", "FocusLost" }, {
	group = group,
	callback = function()
		vim.cmd "silent! update"
	end,
})

local function save_and_hide()
	vim.cmd "silent! write"
	-- Same dispatcher hyprland uses for the CTRL+space bind; verified: hyprctl
	-- accepts lua dispatcher expressions as one argument.
	vim.fn.jobstart { "hyprctl", "dispatch", 'hl.dsp.workspace.toggle_special("todo")' }
end

-- Esc in normal mode: save and hide the popup
vim.keymap.set("n", "<Esc>", save_and_hide, { silent = true })
-- Enter in insert mode: create a fresh item below the current line,
-- continuing its list style, instead of splitting it in half.
-- On a non-list line (header, blank) Enter just opens a plain new line.
vim.keymap.set("i", "<CR>", function()
	local lead = vim.fn.getline("."):match "^(%s*)%-"
	local prefix = lead and (lead .. "- [ ] ") or ""
	local row = vim.fn.line "."
	vim.api.nvim_buf_set_lines(0, row, row, false, { prefix })
	vim.cmd("normal! " .. (row + 1) .. "G$")
	vim.cmd "startinsert!"
end, { silent = true })
