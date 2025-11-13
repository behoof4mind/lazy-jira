-- after/ftplugin/lazy_jira_board.lua
local buf = vim.api.nvim_get_current_buf()
local ui = require("lazy_jira.ui")

-- Soft wrapping is not super important here, but keep it tidy
vim.opt_local.wrap = false

local function map(lhs, rhs, desc)
	vim.keymap.set("n", lhs, rhs, {
		buffer = buf,
		silent = true,
		nowait = true,
		desc = desc,
	})
end

local function current_board_name()
	local ok, name = pcall(function()
		return vim.b.lazy_jira_board_name
	end)
	if not ok or not name or name == "" then
		return nil
	end
	return name
end

local function current_board_id()
	local ok, id = pcall(function()
		return vim.b.lazy_jira_board_id
	end)
	if not ok then
		return nil
	end
	return id
end

local function open_help_popup(lines, title)
	local uiinfo = vim.api.nvim_list_uis()[1]
	if not uiinfo then
		return
	end

	local width = math.floor(uiinfo.width * 0.6)
	local height = math.min(#lines + 4, math.floor(uiinfo.height * 0.7))
	local row = math.floor((uiinfo.height - height) / 3)
	local col = math.floor((uiinfo.width - width) / 2)

	local help_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(help_buf, 0, -1, false, lines)

	local help_win = vim.api.nvim_open_win(help_buf, true, {
		relative = "editor",
		row = row,
		col = col,
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = " " .. (title or "lazy-jira board keybindings") .. " ",
		title_pos = "center",
	})

	vim.bo[help_buf].buftype = "nofile"
	vim.bo[help_buf].bufhidden = "wipe"
	vim.bo[help_buf].swapfile = false
	vim.bo[help_buf].modifiable = false
	vim.bo[help_buf].filetype = "help"

	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(help_win) then
			vim.api.nvim_win_close(help_win, true)
		end
	end, { buffer = help_buf, nowait = true, silent = true })

	vim.keymap.set("n", "<Esc>", function()
		if vim.api.nvim_win_is_valid(help_win) then
			vim.api.nvim_win_close(help_win, true)
		end
	end, { buffer = help_buf, nowait = true, silent = true })
end

vim.api.nvim_buf_create_user_command(buf, "JiraBoardReload", function()
	local name = current_board_name()
	-- ui.show_kanban accepts board_name; if nil, it will pick default
	ui.show_kanban(name)
end, {})

vim.api.nvim_buf_create_user_command(buf, "JiraBoardOpenIssue", function()
	local line = vim.api.nvim_get_current_line()
	local key = line:match("(%u+%-%d+)")
	if not key then
		vim.notify("[lazy_jira] No issue key on this line", vim.log.levels.WARN)
		return
	end
	ui.show_issue(key)
end, {})

-- q: close board buffer
map("q", "<cmd>bd!<CR>", "Close Jira board")

-- <CR>: open issue under cursor
map("<CR>", "<cmd>JiraBoardOpenIssue<CR>", "Open issue under cursor")

-- r: reload board
map("r", "<cmd>JiraBoardReload<CR>", "Reload Jira board")

-- ? : show keybindings for board buffer
map("?", function()
	local name = current_board_name() or ("Board " .. (current_board_id() or "?"))

	local lines = {
		"lazy-jira: Board buffer keybindings",
		"",
		"Board: " .. tostring(name),
		"",
		"Navigation / actions:",
		"  q           Close Jira board buffer",
		"  <CR>        Open issue under cursor in issue view",
		"  r           Reload board (re-run Kanban query)",
		"",
		"Commands:",
		"  :JiraBoardOpenIssue   (open issue under cursor)",
		"  :JiraBoardReload      (reload Kanban board)",
	}

	open_help_popup(lines, "lazy-jira Board keymap (?)")
end, "Show Jira board keybindings")
