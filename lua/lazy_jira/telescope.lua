-- lua/lazy_jira/telescope.lua
local api = require("lazy_jira.api")
local ui = require("lazy_jira.ui")

local M = {}

function M.my_issues_picker()
	local ok, telescope = pcall(require, "telescope")
	if not ok then
		vim.notify("[lazy_jira] telescope.nvim not found", vim.log.levels.ERROR)
		return
	end

	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	local result, err = api.search_my_issues()
	if not result then
		vim.notify("[lazy_jira] " .. err, vim.log.levels.ERROR)
		return
	end

	local issues = result.issues or {}
	if #issues == 0 then
		vim.notify("[lazy_jira] No issues found", vim.log.levels.INFO)
		return
	end

	local function make_entry(issue)
		local f = issue.fields or {}
		local key = issue.key or issue.id or "?"
		local status = (f.status and f.status.name) or ""
		local summary = f.summary or ""

		local status_short = status
		if status == "In Progress" then
			status_short = "⏳ InProg"
		elseif status == "To Do" then
			status_short = "☐ ToDo"
		elseif status == "Done" then
			status_short = "✔ Done"
		end

		return {
			value = issue,
			display = string.format("%-10s %-12s %s", "[" .. key .. "]", status_short, summary),
			ordinal = table.concat({ key, status, summary }, " "),
		}
	end

	pickers
		.new({}, {
			prompt_title = "Jira: My Issues",
			finder = finders.new_table({
				results = issues,
				entry_maker = make_entry,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr, map)
				local function open_issue()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					if selection and selection.value then
						local issue = selection.value
						ui.show_issue(issue.key or issue.id)
					end
				end

				map("i", "<CR>", open_issue)
				map("n", "<CR>", open_issue)

				local function open_in_browser()
					local selection = action_state.get_selected_entry()
					if not (selection and selection.value) then
						return
					end
					local issue = selection.value
					local base = vim.g.lazy_jira_base_url or ""
					if issue.key and base ~= "" then
						local url = base .. "/browse/" .. issue.key
						actions.close(prompt_bufnr)
						vim.fn.jobstart({ "open", url }, { detach = true })
					end
				end

				map("i", "<C-o>", open_in_browser)
				map("n", "<C-o>", open_in_browser)

				return true
			end,
		})
		:find()
end

return M
