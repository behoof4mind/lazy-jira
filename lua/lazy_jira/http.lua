-- lua/lazy_jira/http.lua
local M = {}

local config = {
	base_url = nil,
	email = nil,
	api_token = nil,
}

function M.setup(user_config)
	config.base_url = user_config.base_url
	config.email = user_config.email
	config.api_token = user_config.api_token or vim.fn.getenv(user_config.api_token_env or "")
end

local function auth_header()
	if not (config.email and config.api_token and config.api_token ~= "") then
		error("[lazy_jira] Email or API token not configured")
	end

	local raw = config.email .. ":" .. config.api_token
	local encoded = vim.fn.system("printf %s " .. vim.fn.shellescape(raw) .. " | base64")
	encoded = encoded:gsub("%s+", "")
	return "Basic " .. encoded
end

local function request(method, path, opts)
	opts = opts or {}
	local curl = require("plenary.curl")
	local url = config.base_url .. path

	local headers = opts.headers or {}
	headers["Authorization"] = auth_header()
	headers["Accept"] = "application/json"

	local args = {
		method = method,
		url = url,
		headers = headers,
	}

	if opts.body then
		headers["Content-Type"] = "application/json"
		args.body = vim.fn.json_encode(opts.body)
	end

	if opts.query then
		args.query = opts.query
	end

	local res = curl.request(args)
	return res
end

function M.get(path, opts)
	return request("GET", path, opts)
end

function M.post(path, opts)
	return request("POST", path, opts)
end

function M.put(path, opts)
	return request("PUT", path, opts)
end

function M.delete(path, opts)
	return request("DELETE", path, opts)
end

return M
