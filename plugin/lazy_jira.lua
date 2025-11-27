-- plugin/lazy_jira.lua
if vim.g.loaded_lazy_jira then
	return
end
vim.g.loaded_lazy_jira = true

local ok_ui, ui = pcall(require, "lazy_jira.ui")
if not ok_ui then
	return
end

vim.api.nvim_create_user_command("JiraSearchTitle", function()
	require("lazy_jira.ui").search_by_title()
end, { desc = "Search Jira issues by title" })

vim.api.nvim_create_user_command("JiraMyIssuesAll", function()
	require("lazy_jira.ui").show_my_issues_all_status()
end, { desc = "Show all issues assigned to me (any status)" })

-- Change status of current Jira issue
vim.api.nvim_create_user_command("JiraChangeStatus", function()
	local ok, issue_ui = pcall(require, "lazy_jira.ui.issue")
	if not ok then
		vim.notify("[lazy_jira] issue UI module not available", vim.log.levels.ERROR)
		return
	end
	issue_ui.change_status()
end, {
	desc = "Change status of current Jira issue",
})

-- Open issue by key or keyword under cursor
vim.api.nvim_create_user_command("JiraIssue", function(args)
	local key = args.args
	if key == "" then
		key = vim.fn.expand("<cword>")
	end
	ui.show_issue(key)
end, { nargs = "?" })

-- My issues → quickfix
vim.api.nvim_create_user_command("JiraMyIssues", function()
	local api = require("lazy_jira.api")
	local res, err = api.search_my_issues()
	if not res then
		vim.notify("[lazy_jira] " .. err, vim.log.levels.ERROR)
		return
	end

	local issues = res.issues or {}
	if #issues == 0 then
		vim.notify("[lazy_jira] No issues found", vim.log.levels.INFO)
		return
	end

	local qf = {}
	for _, issue in ipairs(issues) do
		local f = issue.fields or {}
		local status = (f.status and f.status.name) or ""
		local summary = f.summary or ""
		table.insert(qf, {
			filename = issue.key or issue.id,
			lnum = 1,
			col = 1,
			text = string.format("[%s] %-10s %s", issue.key or issue.id, status, summary),
		})
	end

	vim.fn.setqflist(qf, "r")
	vim.cmd("copen")
end, {})

-- My issues → Telescope picker
vim.api.nvim_create_user_command("JiraMyIssuesPicker", function()
	local ok, t = pcall(require, "lazy_jira.telescope")
	if not ok then
		vim.notify("[lazy_jira] telescope integration not available", vim.log.levels.ERROR)
		return
	end
	t.my_issues_picker()
end, {})

vim.api.nvim_create_user_command("JiraSaveComment", function()
	pcall(function()
		require("lazy_jira.ui").save_inline_comment()
	end)
end, {})

vim.api.nvim_create_user_command("JiraKanban", function(opts)
	require("lazy_jira.ui").show_kanban(opts.args)
end, {
	nargs = "?",
	complete = function(ArgLead)
		local lazy_jira = require("lazy_jira")
		local boards = (lazy_jira.config and lazy_jira.config.boards) or {}
		local items = {}
		for _, b in ipairs(boards) do
			if b.name then
				table.insert(items, b.name)
			end
		end
		return vim.tbl_filter(function(item)
			return item:lower():find(ArgLead:lower(), 1, true) ~= nil
		end, items)
	end,
})
