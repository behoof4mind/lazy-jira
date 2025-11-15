local buf = vim.api.nvim_get_current_buf()
local issue = require("lazy_jira.ui.issue")

vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.breakindent = true
vim.opt_local.breakindentopt = "shift:2"
vim.opt_local.showbreak = "↪ "

local function map(lhs, rhs, desc)
	vim.keymap.set("n", lhs, rhs, {
		buffer = buf,
		silent = true,
		nowait = true,
		desc = desc,
	})
end

local function buf_command(name, fn)
	vim.api.nvim_buf_create_user_command(buf, name, fn, {})
end

local function open_help_popup(lines, title)
	local ui = vim.api.nvim_list_uis()[1]
	if not ui then
		return
	end

	local width = math.floor(ui.width * 0.6)
	local height = math.min(#lines + 4, math.floor(ui.height * 0.7))
	local row = math.floor((ui.height - height) / 3)
	local col = math.floor((ui.width - width) / 2)

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
		title = " " .. (title or "lazy-jira issue keybindings") .. " ",
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

local function current_issue_key()
	local ok, key = pcall(function()
		return vim.b.lazy_jira_issue_key
	end)
	if not ok or not key or key == "" then
		return nil
	end
	return key
end

local function current_issue_url()
	local ok, url = pcall(function()
		return vim.b.lazy_jira_issue_url
	end)
	if not ok or not url or url == "" then
		return nil
	end
	return url
end

buf_command("JiraIssueOpenBrowser", function()
	local url = current_issue_url()
	if not url then
		vim.notify("[lazy_jira] No issue URL in buffer", vim.log.levels.ERROR)
		return
	end
	vim.fn.jobstart({ "open", url }, { detach = true })
end)

buf_command("JiraIssueReload", function()
	local key = current_issue_key()
	if not key then
		vim.notify("[lazy_jira] No issue key in buffer", vim.log.levels.ERROR)
		return
	end
	issue.show_issue(key)
end)

buf_command("JiraIssueChangeStatus", function()
	local key = current_issue_key()
	if not key then
		vim.notify("[lazy_jira] No issue key in buffer", vim.log.levels.ERROR)
		return
	end
	issue.change_status(key)
end)

buf_command("JiraIssueChangeAssignee", function()
	local key = current_issue_key()
	if not key then
		vim.notify("[lazy_jira] No issue key in buffer", vim.log.levels.ERROR)
		return
	end
	issue.change_assignee(key)
end)

buf_command("JiraIssueEditDescription", function()
	issue.edit_description()
end)

buf_command("JiraIssueCommentAdd", function()
	issue.new_comment()
end)

buf_command("JiraIssueCommentEdit", function()
	issue.edit_comment()
end)

buf_command("JiraIssueCommentDelete", function()
	issue.delete_comment()
end)

buf_command("JiraIssueCreateBranch", function()
	local key = current_issue_key()
	if not key then
		vim.notify("[lazy_jira] No issue key found in buffer", vim.log.levels.ERROR)
		return
	end

	local first = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] or ""
	local summary = first:gsub("^#%s*" .. vim.pesc(key) .. "%s*", "")
	summary = summary:gsub("%s+", " "):gsub("%s+$", "")

	if summary == "" then
		vim.notify("[lazy_jira] Cannot detect issue summary", vim.log.levels.ERROR)
		return
	end

	local function make_slug(text)
		text = text:lower()
		text = text:gsub("[^%w%s]", " ")
		text = text:gsub("%s+", " ")

		local stopwords = {
			["the"] = true,
			["a"] = true,
			["an"] = true,
			["and"] = true,
			["or"] = true,
			["of"] = true,
			["for"] = true,
			["to"] = true,
			["in"] = true,
			["on"] = true,
			["with"] = true,
			["by"] = true,
			["at"] = true,
			["from"] = true,
			["as"] = true,
			["is"] = true,
			["are"] = true,
			["be"] = true,
		}

		local words = {}
		for w in text:gmatch("%S+") do
			if not stopwords[w] then
				table.insert(words, w)
			end
			if #words >= 5 then
				break
			end
		end

		if #words == 0 then
			return "task"
		end

		return table.concat(words, "-")
	end

	local slug = make_slug(summary)
	local branch = key .. "/" .. slug

	vim.notify("[lazy_jira] Creating branch: " .. branch, vim.log.levels.INFO)

	vim.fn.jobstart({ "git", "switch", "-c", branch }, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if not data then
				return
			end
			for _, line in ipairs(data) do
				if line ~= "" then
					vim.notify("[git] " .. line, vim.log.levels.DEBUG)
				end
			end
		end,
		on_stderr = function(_, data)
			if not data then
				return
			end
			for _, line in ipairs(data) do
				if line ~= "" then
					vim.notify("[git] " .. line, vim.log.levels.WARN)
				end
			end
		end,
		on_exit = function(_, code)
			if code == 0 then
				vim.notify("✔ Switched to new branch: " .. branch, vim.log.levels.INFO)
			else
				vim.notify("❌ Failed to create/switch branch " .. branch, vim.log.levels.ERROR)
			end
		end,
	})
end)

buf_command("JiraCreateBranch", function()
	vim.cmd("JiraIssueCreateBranch")
end)

buf_command("JiraIssueBack", function()
	issue.go_back()
end)

map("go", "<cmd>JiraIssueOpenBrowser<CR>", "Open in browser")

map("gr", "<cmd>JiraIssueReload<CR>", "Reload Jira issue")

map("cd", "<cmd>JiraIssueEditDescription<CR>", "Edit description (popup)")

map("cs", "<cmd>JiraIssueChangeStatus<CR>", "Change Jira status")

map("cA", "<cmd>JiraIssueChangeAssignee<CR>", "Change assignee")

map("ca", "<cmd>JiraIssueCommentAdd<CR>", "Add Jira comment")

map("ce", "<cmd>JiraIssueCommentEdit<CR>", "Edit Jira comment")

map("cr", "<cmd>JiraIssueCommentDelete<CR>", "Delete Jira comment")

map("cb", "<cmd>JiraIssueCreateBranch<CR>", "Create git branch from issue")

map("gb", "<cmd>JiraIssueBack<CR>", "Go back to previous issue")

map("<CR>", function()
	local line = vim.api.nvim_get_current_line()
	local key = line:match("(%u+%-%d+)")
	if not key then
		return
	end
	require("lazy_jira.ui").show_issue(key)
end, "Open issue under cursor")

map("?", function()
	local key = current_issue_key() or "<unknown>"

	local lines = {
		"lazy-jira: Issue buffer keybindings",
		"",
		"Buffer is showing issue: " .. key,
		"",
		"Navigation / actions:",
		"  <CR>       Open issue under cursor (e.g. linked issue)",
		"  gb         Go back to previous issue (lazy-jira history)",
		"  go         Open issue in browser",
		"  gr         Reload issue",
		"",
		"Issue workflow:",
		"  cd         Edit description (floating markdown popup)",
		"  cs         Change issue status (Telescope if available)",
		"  cA         Change assignee (Telescope / select)",
		"",
		"Comments:",
		"  ca         Add new comment (popup; markdown + code fences)",
		"  ce         Edit comment under cursor (popup)",
		"  cr         Delete comment under cursor",
		"",
		"Git:",
		"  cb         Create git branch from issue summary",
		"",
		"Commands:",
		"  :JiraIssueOpenBrowser",
		"  :JiraIssueReload",
		"  :JiraIssueEditDescription",
		"  :JiraIssueChangeStatus",
		"  :JiraIssueChangeAssignee",
		"  :JiraIssueCommentAdd",
		"  :JiraIssueCommentEdit",
		"  :JiraIssueCommentDelete",
		"  :JiraIssueCreateBranch",
		"  :JiraIssueBack",
	}

	open_help_popup(lines, "lazy-jira Issue keymap (?)")
end, "Show Jira issue keybindings")
