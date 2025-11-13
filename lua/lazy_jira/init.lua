-- lua/lazy_jira/init.lua
local M = {}

M.config = {
	layout = "vsplit",
	boards = {},
}

function M.setup(opts)
	opts = opts or {}
	if not opts.base_url then
		error("[lazy_jira] base_url is required")
	end
	if not (opts.email and (opts.api_token or opts.api_token_env)) then
		error("[lazy_jira] email and api_token/api_token_env are required")
	end

	M.config = vim.tbl_deep_extend("force", M.config, opts)

	vim.g.lazy_jira_base_url = opts.base_url

	require("lazy_jira.http").setup(opts)
end

return M
