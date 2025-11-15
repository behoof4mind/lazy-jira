-- lua/lazy_jira/api.lua
local http = require("lazy_jira.http")
local util = require("lazy_jira.ui.util")

local M = {}

local function decode_or_nil(res)
	if not res or not res.status then
		return nil, "No response"
	end

	if res.status < 200 or res.status >= 300 then
		local msg = ("HTTP %d"):format(res.status)
		local body = res.body or ""
		return nil, msg .. (body ~= "" and (": " .. body) or "")
	end

	if not res.body or res.body == "" then
		return nil, "Empty body"
	end

	local ok, data = pcall(vim.fn.json_decode, res.body)
	if not ok then
		return nil, "JSON decode error"
	end

	return data, nil
end

function M.get_issue(key)
	local res = http.get("/rest/api/3/issue/" .. key, {
		query = {
			fields = table.concat({
				"summary",
				"status",
				"assignee",
				"issuetype",
				"project",
				"priority",
				"labels",
				"created",
				"updated",
				"description",
				"comment",
				"issuelinks",
			}, ","),
		},
	})

	return decode_or_nil(res)
end

function M.search_my_issues()
	local query = {
		jql = "assignee = currentUser() AND statusCategory != Done ORDER BY updated DESC",
		maxResults = 20,
		fields = "summary,status,assignee,key",
	}

	local res = http.get("/rest/api/3/search/jql", {
		query = query,
	})

	return decode_or_nil(res)
end

function M.get_transitions(issue_key)
	if not issue_key or issue_key == "" then
		return nil, "issue_key is required"
	end

	local path = "/rest/api/3/issue/" .. issue_key .. "/transitions"
	local res = http.get(path, {
		query = {
			expand = "transitions.fields",
		},
	})

	local data, err = decode_or_nil(res)
	if not data then
		return nil, err
	end

	return data.transitions or {}, nil
end

function M.transition_issue(issue_key, transition_id)
	if not issue_key or issue_key == "" then
		return nil, "issue_key is required"
	end
	if not transition_id or transition_id == "" then
		return nil, "transition_id is required"
	end

	local path = "/rest/api/3/issue/" .. issue_key .. "/transitions"
	local body = {
		transition = {
			id = tostring(transition_id),
		},
	}

	local res = http.post(path, { body = body })

	if not res or res.status < 200 or res.status >= 300 then
		local msg = res and ("HTTP " .. res.status) or "No response"
		return nil, msg .. (res and (": " .. (res.body or "")) or "")
	end

	return true, nil
end

local function wrap_adf_body(adf_doc)
	return { body = adf_doc }
end

function M.add_comment(issue_key, markdown)
	if not issue_key or issue_key == "" then
		return nil, "issue_key is required"
	end

	local adf = util.markdown_to_adf(markdown or "")
	local body = wrap_adf_body(adf)

	local res = http.post("/rest/api/3/issue/" .. issue_key .. "/comment", {
		body = body,
	})

	return decode_or_nil(res)
end

function M.update_comment(issue_key, comment_id, markdown)
	if not issue_key or issue_key == "" then
		return nil, "issue_key is required"
	end
	if not comment_id or comment_id == "" then
		return nil, "comment_id is required"
	end

	local adf = util.markdown_to_adf(markdown or "")
	local body = wrap_adf_body(adf)

	local res = http.put("/rest/api/3/issue/" .. issue_key .. "/comment/" .. comment_id, {
		body = body,
	})

	return decode_or_nil(res)
end

function M.delete_comment(issue_key, comment_id)
	if not issue_key or issue_key == "" then
		return nil, "issue_key is required"
	end
	if not comment_id or comment_id == "" then
		return nil, "comment_id is required"
	end

	local res = http.delete("/rest/api/3/issue/" .. issue_key .. "/comment/" .. comment_id)
	if not res or res.status < 200 or res.status >= 300 then
		local msg = res and ("HTTP " .. res.status) or "No response"
		return nil, msg .. (res and (": " .. (res.body or "")) or "")
	end
	return true, nil
end

function M.update_description(issue_key, adf_doc)
	if not issue_key or issue_key == "" then
		return nil, "issue_key is required"
	end

	if type(adf_doc) ~= "table" then
		adf_doc = util.markdown_to_adf("")
	end

	local body = {
		fields = {
			description = adf_doc,
		},
	}

	local res = http.put("/rest/api/3/issue/" .. issue_key, {
		body = body,
	})

	if not res or res.status < 200 or res.status >= 300 then
		local msg = res and ("HTTP " .. res.status) or "No response"
		return nil, msg .. (res and (": " .. (res.body or "")) or "")
	end

	return true, nil
end

function M.get_board_configuration(board_id)
	local res = http.get("/rest/agile/1.0/board/" .. board_id .. "/configuration")
	return decode_or_nil(res)
end

function M.get_board_swimlanes(board_id)
	local res = http.get("/rest/agile/1.0/board/" .. board_id .. "/swimlane", {
		query = { maxResults = 50 },
	})
	return decode_or_nil(res)
end

function M.get_board_issues_for_statuses(board_id, status_ids, max_results, extra_jql)
	local query = {
		maxResults = max_results or 50,
	}

	local jql_parts = {}

	if status_ids and #status_ids > 0 then
		table.insert(jql_parts, "status in (" .. table.concat(status_ids, ",") .. ")")
	end

	if extra_jql and extra_jql ~= "" then
		table.insert(jql_parts, "(" .. extra_jql .. ")")
	end

	if #jql_parts > 0 then
		query.jql = table.concat(jql_parts, " AND ")
	end

	local res = http.get("/rest/agile/1.0/board/" .. board_id .. "/issue", {
		query = query,
	})

	return decode_or_nil(res)
end

function M.get_assignable_users(issue_key)
	if not issue_key or issue_key == "" then
		return nil, "issue_key is required"
	end

	local res = http.get("/rest/api/3/user/assignable/search", {
		query = {
			issueKey = issue_key,
			maxResults = 1000,
		},
	})

	return decode_or_nil(res)
end

function M.set_assignee(issue_key, account_id)
	if not issue_key or issue_key == "" then
		return nil, "issue_key is required"
	end
	if not account_id or account_id == "" then
		return nil, "account_id is required"
	end

	local path = "/rest/api/3/issue/" .. issue_key .. "/assignee"
	local body = { accountId = account_id }

	local res = http.put(path, { body = body })
	if not res or res.status < 200 or res.status >= 300 then
		local msg = res and ("HTTP " .. res.status) or "No response"
		return nil, msg .. (res and (": " .. (res.body or "")) or "")
	end

	return true, nil
end

return M
