-- lua/lazy_jira/ui/issue.lua
local api = require("lazy_jira.api")
local lazy_jira = require("lazy_jira")
local util = require("lazy_jira.ui.util")

local M = {}

local function render_issue_in_current_buf(lines)
	local layout = lazy_jira.config.layout
	local cur_ft = vim.bo.filetype

	if cur_ft ~= "lazy_jira_board" then
		if layout == "vsplit" then
			vim.cmd("vsplit")
		elseif layout == "hsplit" then
			vim.cmd("split")
		end
	end

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(0, bufnr)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].modifiable = true
	vim.bo[bufnr].filetype = "lazy_jira_issue"

	return bufnr
end

local function get_comment_meta()
	return vim.b.lazy_jira_comments or {}
end

local function get_comment_at_cursor()
	local lnum = vim.api.nvim_win_get_cursor(0)[1]

	for _, c in ipairs(get_comment_meta()) do
		if c.header == lnum then
			return c
		end
	end
	return nil
end

local function open_popup(title, initial_markdown, on_submit)
	local buf = vim.api.nvim_create_buf(false, true)
	local ui = vim.api.nvim_list_uis()[1]
	if not ui then
		return
	end

	local width = math.floor(ui.width * 0.60)
	local height = math.floor(ui.height * 0.50)
	local col = math.floor((ui.width - width) / 2)
	local row = math.floor((ui.height - height) / 4)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = row,
		col = col,
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = " " .. title .. " (Ctrl-S / Enter = save, Esc = cancel) ",
		title_pos = "center",
	})

	local lines = vim.split(initial_markdown or "", "\n", { plain = true })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	vim.bo[buf].modifiable = true
	vim.bo[buf].filetype = "lazy_jira_comment"

	local function submit_and_close()
		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local text = table.concat(content, "\n")

		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end

		on_submit(text)
	end

	-- Esc in NORMAL mode = cancel
	vim.keymap.set("n", "<Esc>", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = buf, silent = true })

	-- Ctrl-S in NORMAL mode = save
	vim.keymap.set("n", "<C-s>", function()
		submit_and_close()
	end, { buffer = buf, silent = true })

	-- Ctrl-S in INSERT mode = save
	vim.keymap.set("i", "<C-s>", function()
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
		submit_and_close()
	end, { buffer = buf, silent = true })

	-- Enter in NORMAL mode = save
	vim.keymap.set("n", "<CR>", function()
		submit_and_close()
	end, { buffer = buf, silent = true })

	return buf, win
end

function M.change_status(issue_key)
	issue_key = issue_key or vim.b.lazy_jira_issue_key
	if not issue_key then
		vim.notify("[lazy_jira] No issue key", vim.log.levels.ERROR)
		return
	end

	local transitions, err = api.get_transitions(issue_key)
	if err or not transitions or #transitions == 0 then
		vim.notify("[lazy_jira] No transitions available", vim.log.levels.INFO)
		return
	end

	local ok_telescope, pickers = pcall(require, "telescope.pickers")
	if ok_telescope then
		local finders = require("telescope.finders")
		local conf = require("telescope.config").values
		local actions = require("telescope.actions")
		local action_state = require("telescope.actions.state")

		pickers
			.new({}, {
				prompt_title = "Change Status",
				layout_strategy = "cursor",
				layout_config = { width = 0.4, height = 0.3 },

				finder = finders.new_table({
					results = transitions,
					entry_maker = function(tr)
						local from = tr.name or "?"
						local to = tr.to and tr.to.name or from
						local label = ("%s → %s"):format(from, to)
						return {
							value = tr,
							display = label,
							ordinal = label,
						}
					end,
				}),

				sorter = conf.generic_sorter({}),

				attach_mappings = function(prompt_bufnr)
					actions.select_default:replace(function()
						actions.close(prompt_bufnr)
						local entry = action_state.get_selected_entry()
						if not entry or not entry.value then
							return
						end
						local tr = entry.value

						local ok2, terr = api.transition_issue(issue_key, tr.id)
						if not ok2 then
							vim.notify("[lazy_jira] " .. terr, vim.log.levels.ERROR)
							return
						end

						vim.notify("[lazy_jira] Status changed → " .. tr.to.name)
						M.show_issue(issue_key)
					end)
					return true
				end,
			})
			:find()

		return
	end

	-- Fallback: simple select (if Telescope not installed)
	local items = {}
	for _, tr in ipairs(transitions) do
		local from = tr.name or "?"
		local to = (tr.to and tr.to.name) or from
		table.insert(items, {
			label = string.format("%s → %s", from, to),
			id = tr.id,
			to_name = to,
		})
	end

	vim.ui.select(items, {
		prompt = "Select new status for " .. issue_key .. ":",
		format_item = function(item)
			return item.label
		end,
	}, function(choice)
		if not choice then
			return
		end
		local ok2, terr2 = api.transition_issue(issue_key, choice.id)
		if not ok2 then
			vim.notify("[lazy_jira] Failed to change status: " .. tostring(terr2), vim.log.levels.ERROR)
			return
		end
		vim.notify("[lazy_jira] Status changed to: " .. choice.to_name, vim.log.levels.INFO)
		M.show_issue(issue_key)
	end)
end

function M.edit_description()
	local issue_key = vim.b.lazy_jira_issue_key
	if not issue_key or issue_key == "" then
		vim.notify("[lazy_jira] No issue key in buffer", vim.log.levels.ERROR)
		return
	end

	local desc_adf = vim.b.lazy_jira_description_raw
	local md = util.adf_to_markdown(desc_adf)

	open_popup("Edit Description", md, function(new_md)
		local adf = util.markdown_to_adf(new_md or "")
		local ok, err = api.update_description(issue_key, adf)
		if not ok then
			vim.notify("[lazy_jira] Failed to update description: " .. tostring(err), vim.log.levels.ERROR)
			return
		end
		vim.notify("[lazy_jira] Description updated ✓", vim.log.levels.INFO)
		M.show_issue(issue_key)
	end)
end

function M.edit_comment()
	local issue_key = vim.b.lazy_jira_issue_key
	if not issue_key or issue_key == "" then
		vim.notify("[lazy_jira] No issue key in buffer", vim.log.levels.ERROR)
		return
	end

	local meta = get_comment_at_cursor()
	if not meta then
		vim.notify("[lazy_jira] Cursor not on a comment", vim.log.levels.WARN)
		return
	end

	local body_md = util.adf_to_markdown(meta.body_raw)

	open_popup("Edit Comment", body_md, function(new_md)
		local ok, err = api.update_comment(issue_key, meta.id, new_md or "")
		if err then
			vim.notify("[lazy_jira] Failed: " .. err, vim.log.levels.ERROR)
		else
			vim.notify("[lazy_jira] Comment updated ✓")
			M.show_issue(issue_key)
		end
	end)
end

function M.new_comment()
	local issue_key = vim.b.lazy_jira_issue_key
	if not issue_key or issue_key == "" then
		vim.notify("[lazy_jira] No issue key in buffer", vim.log.levels.ERROR)
		return
	end

	open_popup("New Comment", "", function(md)
		local ok, err = api.add_comment(issue_key, md or "")
		if err then
			vim.notify("[lazy_jira] Failed: " .. err, vim.log.levels.ERROR)
		else
			vim.notify("[lazy_jira] Comment added ✓")
			M.show_issue(issue_key)
		end
	end)
end

function M.delete_comment()
	local issue_key = vim.b.lazy_jira_issue_key
	if not issue_key or issue_key == "" then
		vim.notify("[lazy_jira] No issue key in buffer", vim.log.levels.ERROR)
		return
	end

	local meta = get_comment_at_cursor()
	if not meta or not meta.id then
		vim.notify("[lazy_jira] Not a comment", vim.log.levels.WARN)
		return
	end

	if vim.fn.confirm("Delete this comment?", "&Yes\n&No", 2) ~= 1 then
		return
	end

	local _, err = api.delete_comment(issue_key, meta.id)
	if err then
		vim.notify("[lazy_jira] Failed: " .. err, vim.log.levels.ERROR)
	else
		vim.notify("[lazy_jira] Comment deleted ✓")
		M.show_issue(issue_key)
	end
end

function M.change_assignee(issue_key)
	issue_key = issue_key or vim.b.lazy_jira_issue_key
	if not issue_key or issue_key == "" then
		vim.notify("[lazy_jira] No issue key in buffer", vim.log.levels.ERROR)
		return
	end

	local users, err = api.get_assignable_users(issue_key)
	if err then
		vim.notify("[lazy_jira] Failed to load assignees: " .. tostring(err), vim.log.levels.ERROR)
		return
	end
	if not users or #users == 0 then
		vim.notify("[lazy_jira] Jira returned no assignable users", vim.log.levels.INFO)
		return
	end

	local ok_telescope, pickers = pcall(require, "telescope.pickers")
	if ok_telescope then
		local finders = require("telescope.finders")
		local conf = require("telescope.config").values
		local actions = require("telescope.actions")
		local action_state = require("telescope.actions.state")

		pickers
			.new({}, {
				prompt_title = "Change assignee for " .. issue_key,
				layout_strategy = "cursor",
				layout_config = { width = 0.5, height = 0.4 },

				finder = finders.new_table({
					results = users,
					entry_maker = function(u)
						local name = u.displayName or u.name or "?"
						local email = u.emailAddress or ""
						local display = email ~= "" and (name .. " <" .. email .. ">") or name

						return {
							value = u,
							display = display,
							ordinal = table.concat({
								display,
								u.accountId or "",
								u.name or "",
							}, " "),
						}
					end,
				}),

				sorter = conf.generic_sorter({}),

				attach_mappings = function(prompt_bufnr)
					actions.select_default:replace(function()
						actions.close(prompt_bufnr)
						local entry = action_state.get_selected_entry()
						if not entry or not entry.value then
							return
						end

						local u = entry.value
						local account_id = u.accountId
						if not account_id or account_id == "" then
							vim.notify("[lazy_jira] Selected user has no accountId", vim.log.levels.ERROR)
							return
						end

						local ok2, err2 = api.set_assignee(issue_key, account_id)
						if not ok2 then
							vim.notify(
								"[lazy_jira] Failed to change assignee: " .. tostring(err2),
								vim.log.levels.ERROR
							)
							return
						end

						local who = u.displayName or u.name or account_id
						vim.notify("[lazy_jira] Assignee → " .. who, vim.log.levels.INFO)
						M.show_issue(issue_key)
					end)
					return true
				end,
			})
			:find()

		return
	end

	local items = {}
	for _, u in ipairs(users) do
		local name = u.displayName or u.name or "?"
		local email = u.emailAddress or ""
		local label = email ~= "" and (name .. " <" .. email .. ">") or name
		table.insert(items, {
			label = label,
			user = u,
		})
	end

	vim.ui.select(items, {
		prompt = "Select assignee for " .. issue_key .. ":",
		format_item = function(it)
			return it.label
		end,
	}, function(choice)
		if not choice or not choice.user then
			return
		end
		local u = choice.user
		local account_id = u.accountId
		if not account_id or account_id == "" then
			vim.notify("[lazy_jira] Selected user has no accountId", vim.log.levels.ERROR)
			return
		end

		local ok2, err2 = api.set_assignee(issue_key, account_id)
		if not ok2 then
			vim.notify("[lazy_jira] Failed to change assignee: " .. tostring(err2), vim.log.levels.ERROR)
			return
		end

		local who = u.displayName or u.name or account_id
		vim.notify("[lazy_jira] Assignee → " .. who, vim.log.levels.INFO)
		M.show_issue(issue_key)
	end)
end

function M.show_issue(key)
	local issue, err = api.get_issue(key)
	if not issue then
		vim.notify("[lazy_jira] " .. err, vim.log.levels.ERROR)
		return
	end

	local f = issue.fields or {}
	local key_str = issue.key
	local summary = f.summary or ""
	local url = issue.self:gsub("/rest/api/.+$", "") .. "/browse/" .. key_str

	local lines = {}
	table.insert(lines, "# " .. key_str .. "  " .. summary)
	table.insert(
		lines,
		"──────────────────────────────────────────────"
	)
	table.insert(lines, "")

	-- Metadata
	table.insert(lines, "■ Metadata")
	for _, pair in ipairs({
		{ "Type", f.issuetype and f.issuetype.name or "" },
		{ "Status", f.status and f.status.name or "" },
		{ "Assignee", (type(f.assignee) == "table" and f.assignee.displayName) or "Unassigned" },
		{ "Priority", f.priority and f.priority.name or "" },
		{ "Created", util.format_datetime(f.created) },
		{ "Updated", util.format_datetime(f.updated) },
		{ "URL", url },
	}) do
		table.insert(lines, ("  • %-10s %s"):format(pair[1] .. ":", pair[2]))
	end

	table.insert(lines, "")
	table.insert(lines, "■ Description")
	table.insert(lines, "")

	for _, ln in ipairs(util.format_description(f.description)) do
		table.insert(lines, "  " .. ln)
	end

	local comments = f.comment and f.comment.comments or {}

	table.insert(lines, "")
	table.insert(
		lines,
		"──────────────────────────────────────────────"
	)
	table.insert(lines, "")
	table.insert(lines, "■ Comments (" .. #comments .. ")")
	table.insert(lines, "")

	local meta = {}

	for _, c in ipairs(comments) do
		local header = #lines + 1
		table.insert(lines, ("  • %s — %s"):format(c.author.displayName, util.format_datetime(c.created)))

		for _, ln in ipairs(util.format_description(c.body)) do
			table.insert(lines, "    " .. ln)
		end
		table.insert(lines, "")

		table.insert(meta, {
			id = c.id,
			header = header,
			body_raw = c.body,
		})
	end

	render_issue_in_current_buf(lines)

	-- buffer vars for later actions
	vim.b.lazy_jira_issue_key = key_str
	vim.b.lazy_jira_issue_url = url
	vim.b.lazy_jira_comments = meta
	vim.b.lazy_jira_description_raw = f.description

	return true
end

return M
