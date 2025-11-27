local lazy_jira = require("lazy_jira")

local M = {}

function M.format_description(desc)
	if not desc then
		return { "<no description>" }
	end

	if type(desc) == "string" then
		return vim.split(desc, "\n", { plain = true })
	end

	if type(desc) ~= "table" then
		return { "<unsupported description format>" }
	end

	local out = {}

	local function handle_code_block(node)
		local parts = {}

		for _, c in ipairs(node.content or {}) do
			if c.type == "text" and c.text then
				table.insert(parts, c.text)
			elseif c.type == "hardBreak" then
				table.insert(parts, "\n")
			end
		end

		local text = table.concat(parts, "")
		if text == "" then
			return
		end

		for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
			table.insert(out, "    " .. line)
		end
	end

	local function handle_paragraph(node)
		local line = {}
		for _, c in ipairs(node.content or {}) do
			if c.type == "text" and c.text then
				table.insert(line, c.text)
			end
		end
		if #line > 0 then
			table.insert(out, table.concat(line))
		end
	end

	local function walk(node)
		if type(node) ~= "table" then
			return
		end

		if node.type == "paragraph" then
			handle_paragraph(node)
		elseif node.type == "codeBlock" then
			handle_code_block(node)
		end

		if node.content then
			for _, c in ipairs(node.content) do
				walk(c)
			end
		end
	end

	walk(desc)

	if #out == 0 then
		return { "<empty>" }
	end

	return out
end

function M.format_datetime(dt)
	if not dt or dt == "" then
		return "-"
	end

	local cleaned = dt:gsub("%.%d+", "")
	local ts = vim.fn.strptime("%Y-%m-%dT%H:%M:%S%z", cleaned)
	if ts <= 0 then
		return dt
	end

	return vim.fn.strftime("%Y-%m-%d %H:%M", ts)
end

function M.build_board_issue_line(ctx)
	local cfg = lazy_jira.config or {}

	local fields = cfg.board_line_fields
		or {
			"key",
			"type",
			"assignee_initials",
			"status",
			"summary",
			"due",
		}

	local fns = {
		key = function(c)
			return string.format("%-10s", c.key or "")
		end,

		type = function(c)
			if not c.type_name or c.type_name == "" then
				return nil
			end
			local short = c.type_name:sub(1, 4)
			return string.format("(%-4s)", short)
		end,

		status = function(c)
			if not c.status or c.status == "" then
				return nil
			end
			local short = c.status:sub(1, 6)
			return string.format("[%-6s]", short)
		end,

		summary = function(c)
			return c.summary or ""
		end,

		due = function(c)
			if not c.due or c.due == "" then
				return nil
			end
			return string.format("(due: %s)", c.due)
		end,

		assignee = function(c)
			return c.assignee or ""
		end,

		assignee_initials = function(c)
			if c.avatar and c.avatar ~= "" then
				return c.avatar
			end
			return "[--]"
		end,
	}

	local parts = { "●" }

	for _, name in ipairs(fields) do
		local fn = fns[name]
		if fn then
			local v = fn(ctx)
			if v and v ~= "" then
				table.insert(parts, v)
			end
		end
	end

	return "  " .. table.concat(parts, "  ")
end

-- Pandoc integration --------------------------------------------------------

local function run_pandoc(input, from, to)
	local cmd = { "pandoc", "-f", from, "-t", to }
	local output = vim.fn.system(cmd, input or "")
	if vim.v.shell_error ~= 0 then
		error("[lazy_jira] pandoc failed (" .. from .. " -> " .. to .. "): " .. output)
	end
	return output
end

function M.markdown_to_adf(md)
	md = md or ""

	local ok_json, pdoc_json = pcall(run_pandoc, md, "markdown", "json")
	if not ok_json then
		return {
			type = "doc",
			version = 1,
			content = {
				{
					type = "paragraph",
					content = { { type = "text", text = md } },
				},
			},
		}
	end

	local ok, pdoc = pcall(vim.fn.json_decode, pdoc_json)
	if not ok or type(pdoc) ~= "table" then
		return {
			type = "doc",
			version = 1,
			content = {
				{
					type = "paragraph",
					content = { { type = "text", text = md } },
				},
			},
		}
	end

	local adf = {
		type = "doc",
		version = 1,
		content = {},
	}

	local function convert_block(b)
		if b.t == "Para" then
			local content = {}
			for _, inline in ipairs(b.c or {}) do
				if inline.t == "Code" then
					table.insert(content, {
						type = "text",
						text = inline.c[2],
						marks = { { type = "code" } },
					})
				elseif inline.t == "Str" then
					table.insert(content, { type = "text", text = inline.c })
				elseif inline.t == "Emph" then
					table.insert(content, {
						type = "text",
						text = inline.c[1].c,
						marks = { { type = "em" } },
					})
				elseif inline.t == "Strong" then
					table.insert(content, {
						type = "text",
						text = inline.c[1].c,
						marks = { { type = "strong" } },
					})
				else
					local txt = inline.c or ""
					if type(txt) == "string" and txt ~= "" then
						table.insert(content, { type = "text", text = txt })
					end
				end
			end

			if #content == 0 then
				content = { { type = "text", text = "" } }
			end

			return {
				type = "paragraph",
				content = content,
			}
		end

		if b.t == "CodeBlock" then
			local lang = ""
			local code = ""
			if type(b.c) == "table" then
				if type(b.c[1]) == "table" then
					lang = b.c[1][1] or ""
				end
				code = b.c[2] or ""
			end
			local cb = {
				type = "codeBlock",
				content = {
					{ type = "text", text = code },
				},
			}
			if lang ~= "" then
				cb.attrs = { language = lang }
			end
			return cb
		end

		return nil
	end

	for _, block in ipairs(pdoc.blocks or {}) do
		local converted = convert_block(block)
		if converted then
			table.insert(adf.content, converted)
		end
	end

	if #adf.content == 0 then
		adf.content = {
			{
				type = "paragraph",
				content = { { type = "text", text = "" } },
			},
		}
	end

	return adf
end

function M.adf_to_markdown(adf)
	if not adf or type(adf) ~= "table" then
		return ""
	end

	local function adf_inline_to_pdoc(inl)
		if type(inl) ~= "table" or inl.type ~= "text" then
			-- very small fallback for hardBreak etc.
			if inl.type == "hardBreak" then
				return { t = "LineBreak" }
			end
			return { t = "Str", c = "" }
		end

		local text = inl.text or ""
		local marks = inl.marks or {}

		-- base node
		local node = { t = "Str", c = text }

		-- wrap with marks
		for _, m in ipairs(marks) do
			if m.type == "code" then
				node = { t = "Code", c = { { "" }, text } }
			elseif m.type == "strong" then
				node = { t = "Strong", c = { node } }
			elseif m.type == "em" then
				node = { t = "Emph", c = { node } }
			elseif m.type == "link" and m.attrs and m.attrs.href then
				node = {
					t = "Link",
					c = {
						{ node },
						{ m.attrs.href, "" },
					},
				}
			end
		end

		return node
	end

	local blocks = {}

	local function handle_block(node)
		if type(node) ~= "table" then
			return
		end

		if node.type == "paragraph" then
			local inlines = {}
			for _, inl in ipairs(node.content or {}) do
				table.insert(inlines, adf_inline_to_pdoc(inl))
			end
			table.insert(blocks, { t = "Para", c = inlines })
		elseif node.type == "codeBlock" then
			local lang = node.attrs and node.attrs.language or ""
			local text_parts = {}
			for _, c in ipairs(node.content or {}) do
				if c.type == "text" and c.text then
					table.insert(text_parts, c.text)
				end
			end
			local code = table.concat(text_parts, "")
			table.insert(blocks, { t = "CodeBlock", c = { { lang }, code } })
		elseif node.type == "bulletList" then
			local items = {}

			for _, li in ipairs(node.content or {}) do
				local item_blocks = {}

				for _, child in ipairs(li.content or {}) do
					if child.type == "paragraph" then
						local inlines = {}
						for _, inl in ipairs(child.content or {}) do
							table.insert(inlines, adf_inline_to_pdoc(inl))
						end
						table.insert(item_blocks, { t = "Para", c = inlines })
					end
				end

				if #item_blocks > 0 then
					table.insert(items, item_blocks)
				end
			end

			if #items > 0 then
				table.insert(blocks, { t = "BulletList", c = items })
			end
		end
	end

	if adf.type == "doc" then
		for _, node in ipairs(adf.content or {}) do
			handle_block(node)
		end
	else
		handle_block(adf)
	end

	local pdoc = {
		["pandoc-api-version"] = { 1, 22, 2 },
		meta = {},
		blocks = blocks,
	}

	local json_text = vim.fn.json_encode(pdoc)
	local ok, md = pcall(run_pandoc, json_text, "json", "markdown")
	if not ok then
		-- fallback: at least show plain text
		local lines = M.format_description(adf)
		return table.concat(lines, "\n")
	end
	return md
end

return M
