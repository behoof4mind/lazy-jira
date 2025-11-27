-- lua/lazy_jira/ui/search.lua

local api = require("lazy_jira.api")
local issue = require("lazy_jira.ui.issue")

local M = {}

-- Telescope + fallback search by title (summary)
function M.search_by_title(opts)
	opts = opts or {}
	local max_results = opts.max_results or 50

	vim.ui.input({ prompt = "Search issue title: " }, function(query)
		if not query or query == "" then
			return
		end

		local data, err = api.search_issues_by_summary(query, { max_results = max_results })
		if not data then
			vim.notify("[lazy_jira] Failed to search issues: " .. tostring(err), vim.log.levels.ERROR)
			return
		end

		local issues = data.issues or {}
		if #issues == 0 then
			vim.notify("[lazy_jira] No issues found", vim.log.levels.INFO)
			return
		end

		-- Telescope available?
		local ok, pickers = pcall(require, "telescope.pickers")
		if not ok then
			-- Fallback using vim.ui.select
			local items = {}
			for _, issue_obj in ipairs(issues) do
				local f = issue_obj.fields or {}
				local label = string.format(
					"%s  [%s]  %s",
					issue_obj.key or "?",
					(f.status and f.status.name) or "",
					f.summary or ""
				)
				table.insert(items, { key = issue_obj.key, label = label })
			end

			vim.ui.select(items, {
				prompt = "Open issue:",
				format_item = function(it)
					return it.label
				end,
			}, function(choice)
				if choice then
					issue.show_issue(choice.key)
				end
			end)

			return
		end

		-- Telescope picker
		local finders = require("telescope.finders")
		local conf = require("telescope.config").values
		local actions = require("telescope.actions")
		local action_state = require("telescope.actions.state")

		pickers
			.new({}, {
				prompt_title = "Search Jira Issues",
				layout_strategy = "cursor",
				layout_config = { width = 0.8, height = 0.6 },
				finder = finders.new_table({
					results = issues,
					entry_maker = function(obj)
						local f = obj.fields or {}
						local disp = string.format(
							"%-10s %-10s %s",
							obj.key or "?",
							(f.status and f.status.name) or "",
							f.summary or ""
						)
						return {
							value = obj.key,
							display = disp,
							ordinal = disp,
						}
					end,
				}),
				sorter = conf.generic_sorter({}),
				attach_mappings = function(prompt_bufnr)
					actions.select_default:replace(function()
						local entry = action_state.get_selected_entry()
						actions.close(prompt_bufnr)
						if entry then
							issue.show_issue(entry.value)
						end
					end)
					return true
				end,
			})
			:find()
	end)
end

function M.show_my_issues_all_status(opts)
	opts = opts or {}
	local max_results = opts.max_results or 100

	local data, err = api.search_my_issues_all_status({ max_results = max_results })
	if not data then
		vim.notify("[lazy_jira] Failed to load my issues: " .. tostring(err), vim.log.levels.ERROR)
		return
	end

	local issues = data.issues or {}
	if #issues == 0 then
		vim.notify("[lazy_jira] No issues assigned to you", vim.log.levels.INFO)
		return
	end

	local ok, pickers = pcall(require, "telescope.pickers")
	if not ok then
		local items = {}
		for _, obj in ipairs(issues) do
			local f = obj.fields or {}
			local label =
				string.format("%s  [%s]  %s", obj.key or "?", (f.status and f.status.name) or "", f.summary or "")
			table.insert(items, { key = obj.key, label = label })
		end

		vim.ui.select(items, {
			prompt = "Open issue:",
			format_item = function(it)
				return it.label
			end,
		}, function(choice)
			if choice then
				issue.show_issue(choice.key)
			end
		end)

		return
	end

	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	pickers
		.new({}, {
			prompt_title = "My Jira Issues (any status)",
			layout_strategy = "cursor",
			layout_config = { width = 0.8, height = 0.6 },
			finder = finders.new_table({
				results = issues,
				entry_maker = function(obj)
					local f = obj.fields or {}
					local disp = string.format(
						"%-10s %-10s %s",
						obj.key or "?",
						(f.status and f.status.name) or "",
						f.summary or ""
					)
					return {
						value = obj.key,
						display = disp,
						ordinal = disp,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local entry = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					if entry then
						issue.show_issue(entry.value)
					end
				end)
				return true
			end,
		})
		:find()
end

return M
