-- lua/lazy_jira/http.lua
local M = {}

local config = {
	base_url = nil,
	email = nil,
	api_token = nil,
}

function M.setup(user_config)
	user_config = user_config or {}

	if user_config.base_url ~= nil then
		config.base_url = tostring(user_config.base_url)
	end

	if user_config.email ~= nil then
		config.email = tostring(user_config.email)
	end

	if user_config.api_token ~= nil then
		config.api_token = tostring(user_config.api_token)
	elseif user_config.api_token_env ~= nil and user_config.api_token_env ~= "" then
		local v = vim.fn.getenv(user_config.api_token_env)
		if v ~= nil and v ~= vim.NIL and v ~= "" then
			config.api_token = tostring(v)
		end
	end
end

local function auth_header()
	local base_url = config.base_url and tostring(config.base_url) or ""
	local email = config.email and tostring(config.email) or ""
	local token = config.api_token and tostring(config.api_token) or ""

	if base_url == "" then
		return nil, "[lazy_jira] base_url is not configured. Set it in setup() or LAZY_JIRA_BASE_URL"
	end
	if email == "" then
		return nil, "[lazy_jira] email is not configured. Set it in setup() or LAZY_JIRA_EMAIL / LAZY_JIRA_USERNAME"
	end
	if token == "" then
		return nil, "[lazy_jira] API token is not configured. Set it in setup() or LAZY_JIRA_TOKEN"
	end

	local raw = email .. ":" .. token
	local encoded = vim.fn.system("printf %s " .. vim.fn.shellescape(raw) .. " | base64")
	encoded = tostring(encoded):gsub("%s+", "")
	return "Basic " .. encoded, nil
end

local function request(method, path, opts)
	opts = opts or {}

	local header, auth_err = auth_header()
	if not header then
		return {
			status = 0,
			body = auth_err,
		}
	end

	local curl = require("plenary.curl")

	local url = (config.base_url or "") .. path

	local headers = opts.headers or {}
	headers["Authorization"] = header
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

	if res and (res.status == 401 or res.status == 403) then
		if not res.body or res.body == "" then
			res.body = "[lazy_jira] Authentication failed (HTTP "
				.. tostring(res.status)
				.. "). Check Jira email and API token."
		end
	end

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
