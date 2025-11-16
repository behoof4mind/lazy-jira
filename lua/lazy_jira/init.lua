local http = require("lazy_jira.http")

local M = {}

local function default_config_file()
	return vim.fn.stdpath("config") .. "/lazy-jira.json"
end

M.config = {
	layout = "vsplit",
	board_line_fields = {
		"key",
		"type",
		"assignee_initials",
		"status",
		"summary",
	},
	config_file = default_config_file(),
	base_url = nil,
	email = nil,
	api_token = nil,
	api_token_env = "LAZY_JIRA_TOKEN",
}

local function resolve_path(path)
	if not path or path == "" then
		return nil
	end
	if path:sub(1, 1) == "/" then
		return path
	end
	return vim.fn.stdpath("config") .. "/" .. path
end

local function load_json_file(path)
	if not path or path == "" then
		return nil
	end
	if vim.fn.filereadable(path) == 0 then
		return nil
	end
	local ok_read, lines = pcall(vim.fn.readfile, path)
	if not ok_read or not lines then
		return nil
	end
	local content = table.concat(lines, "\n")
	local ok_json, data = pcall(vim.fn.json_decode, content)
	if not ok_json or type(data) ~= "table" then
		return nil
	end
	return data
end

function M.setup(user_config)
	user_config = user_config or {}

	local cfg = vim.tbl_deep_extend("force", M.config, user_config)

	local file_path = resolve_path(cfg.config_file)
	local file_cfg = load_json_file(file_path)

	if file_cfg then
		if not cfg.base_url or cfg.base_url == "" then
			cfg.base_url = file_cfg.base_url or file_cfg.url
		end
		if not cfg.email or cfg.email == "" then
			cfg.email = file_cfg.email or file_cfg.username
		end
		if not cfg.api_token or cfg.api_token == "" then
			cfg.api_token = file_cfg.api_token or file_cfg.token
		end
	end

	if not cfg.base_url or cfg.base_url == "" then
		local env = vim.fn.getenv("LAZY_JIRA_BASE_URL")
		if env and env ~= "" then
			cfg.base_url = env
		end
	end

	if not cfg.email or cfg.email == "" then
		local env = vim.fn.getenv("LAZY_JIRA_USERNAME")
		if env and env ~= "" then
			cfg.email = env
		end
	end

	if not cfg.api_token or cfg.api_token == "" then
		local env = vim.fn.getenv(cfg.api_token_env or "LAZY_JIRA_TOKEN")
		if env and env ~= "" then
			cfg.api_token = env
		end
	end

	M.config = cfg

	if not cfg.base_url or cfg.base_url == "" then
		vim.notify(
			"[lazy_jira] base_url is not configured. Use setup({ base_url = ... }) or config_file or LAZY_JIRA_BASE_URL",
			vim.log.levels.ERROR
		)
	end

	http.setup({
		base_url = cfg.base_url,
		email = cfg.email,
		api_token = cfg.api_token,
		api_token_env = cfg.api_token_env,
	})
end

return M
