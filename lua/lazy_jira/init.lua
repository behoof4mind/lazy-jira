-- lua/lazy_jira/init.lua
local http = require("lazy_jira.http")
local config_loader = require("lazy_jira.config")
local log = require("lazy_jira.log")
require("lazy_jira.global_config")

local M = {}

-- Filled after setup()
M.config = {}

function M.setup(user_config)
	user_config = user_config or {}

	-- Load merged config:
	--   user opts  >  lazy-jira.json  >  env variables
	-- This is where we add project, board, fields, issue_types...
	local cfg = config_loader.load(user_config)

	log.setup({ debug = cfg.debug })

	-- Create a redacted copy of cfg for logging
	local log_cfg = vim.tbl_deep_extend("force", {}, cfg)
	if log_cfg.api_token then
		log_cfg.api_token = "********"
	end

	log.debug("lazy_jira.init: Loaded config (cfg):")
	log.debug(log_cfg)
	log.debug("lazy_jira.init: cfg.fields:")
	log.debug(log_cfg.fields)

	M.config = cfg
	_G._LAZY_JIRA_CONFIG = cfg

	log.debug("lazy_jira.init: M.config after setup:")
	log.debug(log_cfg)
	log.debug("lazy_jira.init: M.config.boards after setup:")
	log.debug(log_cfg.boards)

	http.setup({
		base_url = cfg.base_url,
		email = cfg.email,
		api_token = cfg.api_token,
	})
end

return M

