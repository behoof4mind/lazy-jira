-- lua/lazy_jira/ui/board.lua
local api = require("lazy_jira.api")
local lazy_jira = require("lazy_jira")
local ui_util = require("lazy_jira.ui.util")

local M = {}

local ns_help = vim.api.nvim_create_namespace("lazy_jira_help_hint")
local ns_board = vim.api.nvim_create_namespace("lazy_jira_board")

local function apply_kanban_highlights(bufnr)
	local line_count = vim.api.nvim_buf_line_count(bufnr)

	local function add(group, lnum, col_start, col_end)
		vim.api.nvim_buf_add_highlight(bufnr, ns_board, group, lnum, col_start, col_end)
	end

	for i = 0, line_count - 1 do
		local line = vim.api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1] or ""

		-- header: title + project + board id
		if line:match("^󰙂") or line:match("^") or line:match("^󰧨") then
			add("Title", i, 0, -1)

		-- note line
		elseif line:match("^Note:") then
			add("Comment", i, 0, -1)

		-- column titles
		elseif line:match("^ ") then
			add("Statement", i, 0, -1)

		-- separators
		elseif line:match("^%s*[-─]+%s*$") then
			add("Comment", i, 0, -1)

		-- issue lines
		elseif line:match("^%s*● ") then
			-- ● bullet
			local bs, be = line:find("●")
			if bs then
				add("SpecialChar", i, bs - 1, be)
			end

			-- KEY-123
			local ks, ke = line:find("(%u+%-%d+)")
			if ks then
				add("Identifier", i, ks - 1, ke)
			end

			-- (Type)
			local ts, te = line:find("%b()")
			if ts and te then
				add("Type", i, ts - 1, te)
			end

			-- [Status]
			local ss, se = line:find("%b[]")
			if ss and se then
				add("Constant", i, ss - 1, se)
			end

			-- due: ...
			local ds = line:find("%(due:")
			if ds then
				add("String", i, ds - 1, -1)
			end

			-- trailing avatar [XX]
			local avs, ave = line:find("%[[A-Z%-][A-Z%-]%]%s*$")
			if avs and ave then
				add("Function", i, avs - 1, ave)
			end
		end
	end
end

local function is_excluded_column(name)
	local cfg = lazy_jira.config or {}
	local excluded = cfg.exclude_columns or {}
	for _, n in ipairs(excluded) do
		if n == name then
			return true
		end
	end
	return false
end

local function is_excluded_issue_type(issue)
	local cfg = lazy_jira.config or {}
	local excluded = cfg.exclude_issue_types

	if type(excluded) ~= "table" or #excluded == 0 then
		return false
	end

	local name = ""

	if type(issue) == "string" then
		name = issue
	elseif type(issue) == "table" then
		if issue.fields and issue.fields.issuetype and issue.fields.issuetype.name then
			name = issue.fields.issuetype.name
		elseif issue.issuetype and issue.issuetype.name then
			name = issue.issuetype.name
		end
	end

	if name == "" then
		return false
	end

	for _, t in ipairs(excluded) do
		if t == name then
			return true
		end
	end

	return false
end

local function extract_board_id(url)
	local id = url:match("/boards/(%d+)")
	if not id then
		id = url:match("/board/(%d+)")
	end
	return id
end

local function pick_board_config(name)
	local cfg = lazy_jira.config or {}
	local boards = cfg.boards or {}
	if #boards == 0 then
		return nil, "No boards configured in lazy_jira.setup({ boards = { ... } })"
	end

	if not name or name == "" then
		return boards[1], nil
	end

	local nl = name:lower()
	for _, b in ipairs(boards) do
		if b.name and b.name:lower() == nl then
			return b, nil
		end
	end

	return nil, "Board with name '" .. name .. "' not found"
end

local function open_board_buffer(lines)
	local layout = lazy_jira.config.layout

	if layout == "vsplit" then
		vim.cmd("vsplit")
	elseif layout == "hsplit" then
		vim.cmd("split")
	end

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(0, bufnr)

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "hide"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].modifiable = false
	vim.bo[bufnr].filetype = "lazy_jira_board"
	vim.bo[bufnr].buflisted = true

	vim.api.nvim_buf_set_extmark(bufnr, ns_help, 0, 0, {
		virt_text = { { "[? help]", "Comment" } },
		virt_text_pos = "right_align",
	})

	return bufnr
end

function M.show_kanban(board_name)
	local board_cfg, err = pick_board_config(board_name)
	if not board_cfg then
		vim.notify("[lazy_jira] " .. err, vim.log.levels.ERROR)
		return
	end

	if not board_cfg.url then
		vim.notify("[lazy_jira] Board '" .. (board_cfg.name or "?") .. "' has no url in config", vim.log.levels.ERROR)
		return
	end

	local board_id = extract_board_id(board_cfg.url)
	if not board_id then
		vim.notify("[lazy_jira] Cannot extract board id from url: " .. board_cfg.url, vim.log.levels.ERROR)
		return
	end

	local conf, cerr = api.get_board_configuration(board_id)
	if not conf then
		vim.notify("[lazy_jira] Failed to load board configuration: " .. cerr, vim.log.levels.ERROR)
		return
	end

	local columns = (conf.columnConfig and conf.columnConfig.columns) or {}

	local lanes_res = api.get_board_swimlanes(board_id)
	local lanes = (lanes_res and lanes_res.values) or {}
	local has_lanes = #lanes > 0

	local lines = {}

	table.insert(lines, "󰙂  Jira Kanban: " .. (board_cfg.name or ("Board " .. board_id)))
	table.insert(lines, string.format("  Project: %s (%s)", conf.location.name or "?", conf.location.key or "?"))
	table.insert(lines, "󰧨  Board id: " .. tostring(board_id))
	table.insert(lines, "")
	table.insert(lines, "Note: this is a read-only Kanban view rendered by lazy_jira.")
	table.insert(lines, "")

	local function render_column(col, extra_jql)
		local status_ids = {}
		if col.statuses then
			for _, s in ipairs(col.statuses) do
				local sid = s.id
				if (not sid) and type(s.self) == "string" then
					sid = s.self:match("/status/(%d+)")
				end
				if sid then
					table.insert(status_ids, sid)
				end
			end
		end

		if not status_ids or #status_ids == 0 then
			table.insert(lines, "  (no statuses mapped to this column)")
			table.insert(lines, "")
			return
		end

		local cfg = lazy_jira.config or {}
		local max_col = cfg.max_issues_per_column or 100

		local result, ierr = api.get_board_issues_for_statuses(board_id, status_ids, max_col, extra_jql)

		local arr = result.issues or {}
		if #arr == 0 then
			table.insert(lines, "  (no issues)")
			table.insert(lines, "")
			return
		end

		local seen = {}

		for _, iss in ipairs(arr) do
			local key = iss.key or iss.id
			if key and not seen[key] then
				seen[key] = true

				local f = iss.fields or {}
				local summary = f.summary or ""

				local status = ""
				if type(f.status) == "table" and f.status.name then
					status = f.status.name
				end

				local itype = ""
				if type(f.issuetype) == "table" and f.issuetype.name then
					itype = f.issuetype.name
				end

				if is_excluded_issue_type(itype) then
					goto continue_issue
				end

				local due = ""
				if type(f.duedate) == "string" then
					due = f.duedate
				end

				local ass = ""
				if type(f.assignee) == "table" and f.assignee.displayName then
					ass = f.assignee.displayName
				end

				local avatar = "[--]"
				if ass ~= "" then
					local initials = ""
					for w in ass:gmatch("%S+") do
						initials = initials .. w:sub(1, 1)
						if #initials >= 2 then
							break
						end
					end
					if initials ~= "" then
						avatar = "[" .. initials .. "]"
					end
				end

				local line = ui_util.build_board_issue_line({
					key = key,
					type_name = itype,
					status = status,
					summary = summary,
					due = due,
					assignee = ass,
					avatar = avatar,
				})

				table.insert(lines, line)
			end

			::continue_issue::
		end

		table.insert(lines, "")
	end

	if has_lanes then
		for _, lane in ipairs(lanes) do
			local lane_name = lane.name or ("Swimlane " .. tostring(lane.id))
			local lane_query = lane.jql or lane.query or ""

			table.insert(lines, "──────────────")
			table.insert(lines, "󰓎  " .. lane_name)
			table.insert(lines, "──────────────")
			table.insert(lines, "")

			for _, col in ipairs(columns) do
				local col_name = col.name or "<no name>"

				if not is_excluded_column(col_name) then
					table.insert(lines, " " .. col_name)
					table.insert(lines, string.rep("-", 70))

					render_column(col, lane_query)
				end
			end

			table.insert(lines, "")
		end
	else
		for _, col in ipairs(columns) do
			local col_name = col.name or "<no name>"

			if not is_excluded_column(col_name) then
				table.insert(lines, " " .. col_name)
				table.insert(lines, string.rep("-", 70))

				render_column(col, nil)
				table.insert(lines, "")
			end
		end
	end

	local bufnr = open_board_buffer(lines)

	apply_kanban_highlights(bufnr)

	pcall(vim.api.nvim_buf_set_var, bufnr, "lazy_jira_board_id", tonumber(board_id))
	pcall(vim.api.nvim_buf_set_var, bufnr, "lazy_jira_board_name", board_cfg.name or ("Board " .. board_id))

	return bufnr
end

return M
