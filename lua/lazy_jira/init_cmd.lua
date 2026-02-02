local M = {}

local function ask(prompt)
	return vim.fn.input(prompt .. ": ")
end

function M.run()
	local config_path = vim.fn.expand("~/.lazy-jira.json")

	local url = ask("Jira Base URL (e.g. https://your.atlassian.net)")
	local email = ask("Email / Username")
	local token = ask("API Token")

	local board_url = ask("Full URL of a board (optional)")

	local cfg = {
		base_url = url,
		username = email,
		token = token,
	}

	if board_url ~= "" then
		cfg.board_url = board_url
	end

	-- Write file
	local encoded = vim.fn.json_encode(cfg)
	local ok = pcall(vim.fn.writefile, { encoded }, config_path)

	if not ok then
		vim.notify("[lazy_jira] Failed to write to " .. config_path, vim.log.levels.ERROR)
		return
	end

	vim.notify("[lazy_jira] Created config at " .. config_path, vim.log.levels.INFO)

	-- Reload plugin
	require("lazy_jira").setup({ config_file = config_path })

	vim.notify("[lazy_jira] Configuration loaded ✓", vim.log.levels.INFO)
end

return M
