-- lua/lazy_jira/ui.lua

local issue = require("lazy_jira.ui.issue")
local board = require("lazy_jira.ui.board")
local search = require("lazy_jira.ui.search")

local M = {}

M.show_issue = issue.show_issue
M.save_inline_comment = issue.save_inline_comment
M.delete_comment_action = issue.delete_comment_action
M.new_comment_inline_at_bottom = issue.new_comment_inline_at_bottom
M.change_status = issue.change_status

M.show_kanban = board.show_kanban

M.search_by_title = search.search_by_title
M.show_my_issues_all_status = search.show_my_issues_all_status

return M
