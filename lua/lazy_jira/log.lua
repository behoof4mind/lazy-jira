-- lua/lazy_jira/log.lua

local M = {}

local config = {
	debug = false,
}

local function get_log_file_path()
	return vim.fn.stdpath("cache") .. "/lazy-jira.log"
end

function M.setup(opts)
	config = opts or {}
	if config.debug then
		-- Clear the log file on setup if debug is enabled
		local path = get_log_file_path()
		local f = io.open(path, "w")
		if f then
			f:write("Lazy-Jira Debug Log\n")
			f:write("====================\n\n")
			f:close()
		end
	end
end

function M.debug(message)
	if not config.debug then
		return
	end

	local path = get_log_file_path()
	local f = io.open(path, "a")
	if f then
		local timestamp = os.date("%Y-%m-%d %H:%M:%S")
		if type(message) == "table" then
			message = vim.inspect(message)
		end
		f:write(string.format("[%s] %s\n", timestamp, message))
		f:close()
	end
end

return M

