-- lua/lazy_jira/config.lua

local M = {}
local log = require("lazy_jira.log")

local function read_json_file(path)
	if not path or path == "" then
		return {}
	end
	path = vim.fn.expand(path)
	if vim.fn.filereadable(path) == 0 then
		return {}
	end

	local ok, data = pcall(function()
		local lines = vim.fn.readfile(path)
		local text = table.concat(lines, "\n")
		return vim.fn.json_decode(text)
	end)

	if not ok or type(data) ~= "table" then
		return {}
	end

	return data
end

local function merge(a, b)
	a = a or {}
	b = b or {}
	return vim.tbl_deep_extend("force", a, b)
end

local function resolve_auth(user_opts, file_cfg)
	local env = vim.fn.getenv

	local base_url = user_opts.base_url or file_cfg.base_url or env("LAZY_JIRA_BASE_URL")

	local email = user_opts.email
		or user_opts.username
		or file_cfg.email
		or file_cfg.username
		or env("LAZY_JIRA_EMAIL")
		or env("LAZY_JIRA_USERNAME")

	local api_token = user_opts.api_token
		or user_opts.token
		or file_cfg.api_token
		or file_cfg.token
		or env("LAZY_JIRA_API_TOKEN")
		or env("LAZY_JIRA_TOKEN")

	return {
		base_url = base_url,
		email = email,
		api_token = api_token,
	}
end

local function resolve_project(user_opts, file_cfg)
	local project = merge(file_cfg.project, user_opts.project)

	if type(project) ~= "table" then
		project = {}
	end

	if not project.key then
		project.key = user_opts.project_key or file_cfg.project_key
	end

	return project
end

local function resolve_board(user_opts, file_cfg)
	local board = merge(file_cfg.board, user_opts.board)

	if type(board) ~= "table" then
		board = {}
	end

	if not board.id then
		board.id = user_opts.board_id or file_cfg.board_id
	end

	return board
end

local function resolve_fields(user_opts, file_cfg)
	local fields = merge(file_cfg.fields, user_opts.fields)

	if type(fields) ~= "table" then
		fields = {}
	end

	fields.epic_link = fields.epic_link or file_cfg.epic_link or user_opts.epic_link
	fields.epic_name = fields.epic_name or file_cfg.epic_name or user_opts.epic_name
	fields.story_points = fields.story_points or file_cfg.story_points or user_opts.story_points

	return fields
end

local function resolve_issue_types(user_opts, file_cfg)
	local types = merge(file_cfg.issue_types, user_opts.issue_types)

	if type(types) ~= "table" then
		types = {}
	end

	return types
end

function M.load(user_opts)
	user_opts = user_opts or {}

	log.debug("config.lua: M.load called with user_opts:")
	log.debug(user_opts)

	-- Where to load JSON config from
	local config_file = user_opts.config_file or "~/.config/lazy-jira.json"
	local file_cfg = read_json_file(config_file)

	log.debug("config.lua: file_cfg:")
	log.debug(file_cfg)

	local auth = resolve_auth(user_opts, file_cfg)
	local project = resolve_project(user_opts, file_cfg)
	local board = resolve_board(user_opts, file_cfg)
	local fields = resolve_fields(user_opts, file_cfg)
	local issue_types = resolve_issue_types(user_opts, file_cfg)

	-- layout & board line formatting
	local layout = user_opts.layout or file_cfg.layout or "vsplit"

	local board_line_fields = user_opts.board_line_fields
		or file_cfg.board_line_fields
		or {
			"key",
			"type",
			"assignee_initials",
			"status",
			"summary",
		}

	local exclude_issue_types = user_opts.exclude_issue_types or { "Epic" }

	-- ✅ NEW: pass through these plugin options
	local exclude_columns = user_opts.exclude_columns or file_cfg.exclude_columns or {}

	local max_issues_per_column = user_opts.max_issues_per_column or file_cfg.max_issues_per_column or 100

	local boards = user_opts.boards or file_cfg.boards or {}
	log.debug("config.lua: resolved boards:")
	log.debug(boards)
	log.debug("config.lua: #resolved boards: " .. #boards)

	local pandoc_cmd = user_opts.pandoc_cmd or file_cfg.pandoc_cmd or "pandoc"

	local debug = user_opts.debug or file_cfg.debug or false

	-- auth validation
	if not auth.base_url or auth.base_url == "" then
		error("[lazy_jira] base_url is required")
	end
	if not auth.email or auth.email == "" then
		error("[lazy_jira] email/username is required")
	end
	if not auth.api_token or auth.api_token == "" then
		error("[lazy_jira] api token is required")
	end

	local cfg = {
		-- auth
		base_url = auth.base_url,
		email = auth.email,
		api_token = auth.api_token,

		-- jira metadata
		project = project,
		board = board,
		fields = fields,
		issue_types = issue_types,

		-- UI/layout
		layout = layout,
		board_line_fields = board_line_fields,
		exclude_issue_types = exclude_issue_types,
		exclude_columns = exclude_columns,
		max_issues_per_column = max_issues_per_column,

		-- boards list (for Kanban + completion)
		boards = boards,

		-- pandoc integration
		pandoc_cmd = pandoc_cmd,

		-- bookkeeping
		config_file = config_file,
		debug = debug,
	}

	log.debug("config.lua: final cfg.boards:")
	log.debug(cfg.boards)
	log.debug("config.lua: #final cfg.boards: " .. #cfg.boards)

	return cfg
end

return M
