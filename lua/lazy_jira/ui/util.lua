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

local function inline_to_nodes(text)
  local nodes = {}
  local len = #text
  local i = 1
  local plain_start = 1

  local function push_plain(up_to)
    if not plain_start then
      return
    end
    if up_to < plain_start then
      return
    end
    local s = text:sub(plain_start, up_to)
    if s ~= "" then
      table.insert(nodes, { type = "text", text = s })
    end
    plain_start = nil
  end

  while i <= len do
    if text:sub(i, i) == "[" then
      local close_label = text:find("%]", i + 1, true)
      local open_paren = close_label and text:sub(close_label + 1, close_label + 1) == "("
          and (close_label + 1)
        or nil
      if close_label and open_paren then
        local close_paren = text:find("%)", open_paren + 1, true)
        if close_paren then
          push_plain(i - 1)
          local label = text:sub(i + 1, close_label - 1)
          local url = text:sub(open_paren + 1, close_paren - 1)

          local inner = inline_to_nodes(label)
          for _, n in ipairs(inner) do
            n.marks = n.marks or {}
            table.insert(n.marks, {
              type = "link",
              attrs = { href = url },
            })
            table.insert(nodes, n)
          end

          i = close_paren + 1
          plain_start = i
          goto continue
        end
      end
    end

    if text:sub(i, i + 1) == "**" then
      local close = text:find("%*%*", i + 2, true)
      if close then
        push_plain(i - 1)
        local inner_text = text:sub(i + 2, close - 1)
        local inner_nodes = inline_to_nodes(inner_text)
        for _, n in ipairs(inner_nodes) do
          n.marks = n.marks or {}
          table.insert(n.marks, { type = "strong" })
          table.insert(nodes, n)
        end
        i = close + 2
        plain_start = i
        goto continue
      end
    end

    if text:sub(i, i) == "*" then
      local close = text:find("%*", i + 1, true)
      if close then
        push_plain(i - 1)
        local inner_text = text:sub(i + 1, close - 1)
        local inner_nodes = inline_to_nodes(inner_text)
        for _, n in ipairs(inner_nodes) do
          n.marks = n.marks or {}
          table.insert(n.marks, { type = "em" })
          table.insert(nodes, n)
        end
        i = close + 1
        plain_start = i
        goto continue
      end
    end

    if text:sub(i, i) == "`" then
      local close = text:find("`", i + 1, true)
      if close then
        push_plain(i - 1)
        local code_text = text:sub(i + 1, close - 1)
        if code_text ~= "" then
          table.insert(nodes, {
            type = "text",
            text = code_text,
            marks = { { type = "code" } },
          })
        end
        i = close + 1
        plain_start = i
        goto continue
      end
    end

    if not plain_start then
      plain_start = i
    end
    i = i + 1

    ::continue::
  end

  if plain_start then
    push_plain(len)
  end

  if #nodes == 0 then
    return { { type = "text", text = "" } }
  end

  return nodes
end

local function markdown_to_blocks(md)
  if type(md) == "table" then
    md = M.adf_to_markdown(md)
  elseif type(md) ~= "string" then
    md = tostring(md or "")
  end

  local lines = vim.split(md or "", "\n", { plain = true })
  local blocks = {}

  local in_code = false
  local code_lang = nil
  local code_lines = {}
  local current_para = {}

  local function flush_para()
    if #current_para == 0 then
      return
    end
    local text = table.concat(current_para, " ")
    table.insert(blocks, {
      type = "paragraph",
      content = inline_to_nodes(text),
    })
    current_para = {}
  end

  local function flush_code()
    if #code_lines == 0 then
      return
    end

    local text = table.concat(code_lines, "\n")
    local cb = {
      type = "codeBlock",
      content = {
        { type = "text", text = text },
      },
    }
    if code_lang and code_lang ~= "" then
      cb.attrs = { language = code_lang }
    end

    table.insert(blocks, cb)
    code_lines = {}
  end

  for _, line in ipairs(lines) do
    local fence_lang = line:match("^```%s*(%S*)%s*$")
    if fence_lang then
      if not in_code then
        flush_para()
        in_code = true
        code_lang = fence_lang
        code_lines = {}
      else
        flush_code()
        in_code = false
        code_lang = nil
      end
    else
      if in_code then
        table.insert(code_lines, line)
      else
        if line:match("^%s*$") then
          flush_para()
        else
          table.insert(current_para, line)
        end
      end
    end
  end

  if in_code then
    flush_code()
  end
  flush_para()

  if #blocks == 0 then
    table.insert(blocks, {
      type = "paragraph",
      content = { { type = "text", text = "" } },
    })
  end

  return blocks
end

function M.markdown_to_adf(md)
  return {
    type = "doc",
    version = 1,
    content = markdown_to_blocks(md or ""),
  }
end

local function inline_from_nodes(nodes)
  local parts = {}

  for _, node in ipairs(nodes or {}) do
    if node.type == "text" then
      local text = node.text or ""
      local marks = node.marks or {}

      local strong = false
      local em = false
      local code = false
      local link = nil

      for _, m in ipairs(marks) do
        if m.type == "strong" then
          strong = true
        elseif m.type == "em" then
          em = true
        elseif m.type == "code" then
          code = true
        elseif m.type == "link" then
          link = m.attrs and m.attrs.href or nil
        end
      end

      if code then
        text = "`" .. text .. "`"
      end
      if strong then
        text = "**" .. text .. "**"
      end
      if em then
        text = "*" .. text .. "*"
      end
      if link then
        text = "[" .. text .. "](" .. link .. ")"
      end

      table.insert(parts, text)

    elseif node.type == "hardBreak" then
      table.insert(parts, "  \n")

    elseif node.type == "inlineCard" then
      local attrs = node.attrs or {}
      local href = attrs.url or attrs.href or ""
      local label = attrs.title or attrs.text or href
      if href ~= "" then
        if label == "" then
          label = href
        end
        table.insert(parts, "[" .. label .. "](" .. href .. ")")
      end

    elseif node.type == "emoji" then
      local attrs = node.attrs or {}
      local txt = attrs.text or attrs.shortName or ""
      if txt ~= "" then
        table.insert(parts, txt)
      end

    elseif node.type == "mention" then
      local attrs = node.attrs or {}
      local txt = attrs.text or (attrs.id and ("@" .. attrs.id)) or ""
      if txt ~= "" then
        table.insert(parts, txt)
      end

    else
      if type(node.text) == "string" and node.text ~= "" then
        table.insert(parts, node.text)
      elseif node.attrs and type(node.attrs.text) == "string" then
        table.insert(parts, node.attrs.text)
      end
    end
  end

  return table.concat(parts, "")
end

local function blocks_to_markdown(doc)
  if not doc or type(doc) ~= "table" then
    return ""
  end

  local out = {}

  local function handle_node(node)
    if node.type == "paragraph" then
      table.insert(out, inline_from_nodes(node.content or {}))
      table.insert(out, "")

    elseif node.type == "codeBlock" then
      local lang = node.attrs and node.attrs.language or ""
      local fence = "```" .. (lang or "")
      table.insert(out, fence)

      local text_parts = {}
      for _, c in ipairs(node.content or {}) do
        if c.type == "text" and c.text then
          table.insert(text_parts, c.text)
        elseif c.type == "hardBreak" then
          table.insert(text_parts, "\n")
        end
      end
      local text = table.concat(text_parts, "")
      for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
        table.insert(out, line)
      end

      table.insert(out, "```")
      table.insert(out, "")

    elseif node.type == "doc" then
      for _, child in ipairs(node.content or {}) do
        handle_node(child)
      end
    end
  end

  if doc.type == "doc" then
    for _, child in ipairs(doc.content or {}) do
      handle_node(child)
    end
  else
    handle_node(doc)
  end

  while #out > 0 and out[#out]:match("^%s*$") do
    table.remove(out)
  end

  return table.concat(out, "\n")
end

function M.adf_to_markdown(adf)
  return blocks_to_markdown(adf)
end

return M
