# lazy-jira

A fast, minimal, Neovim-native Jira client designed for real-world daily usage.  
It gives you **Kanban boards**, **issue viewer**, **status transitions**,  
**comment editing with Markdown → ADF**, **description editing**,  
**assignee picker**, **issue jump-back history**,  
and a beautiful floating UI — all inside Neovim.

---

## ✨ Features

### 🗂 Kanban Board View

- Displays issues grouped by Jira columns
- Issue line formatting is configurable
- Press `<CR>` on any issue to open it
- Press `?` to show board keybindings
- Fast and always available from anywhere in Neovim

### 🧾 Issue View

- Full left-side or split-window issue viewer
- Shows:
  - Metadata
  - Description
  - Linked issues
  - Comments
- Clean readable formatting converted from Jira ADF → Markdown-like view
- Press `?` to open a floating help popup
- Top‑right `[? help]` virtual hint
- Jump back to previously opened issue

### 📝 Markdown Editing (ADF conversion)

Supports:

- **bold**
- _italic_
- `inline code`
- ```
  fenced
  code blocks
  ```
- [Links](https://example.com)

Conversion works both ways:

- Jira ADF → Markdown when loading
- Markdown → Jira ADF when saving

### 💬 Comments

- Add new comment
- Edit comment (Markdown popup)
- Delete comment
- Proper multi‑line code block support

### 🗒 Description Editor

- Edit the issue description in a centered floating window
- Fully supports Markdown → ADF conversion

### 🔄 Status Transitions

- Telescope picker first
- Fallback to `vim.ui.select()` if Telescope is missing

### 👤 Change Assignee

- Telescope-powered user picker
- Works even if the issue has no assignee
- Shows all assignable users for that issue

### ↩️ Issue Navigation

- Automatically tracks opened issue history
- Quickly return to the previous issue

### 🌿 Git Workflow Helpers

Creates branches like:

```
PT-104/upgrade-percona-80
```

---

## 🔧 Installation

### Using **lazy.nvim**

```lua
{
  "behoof4mind/lazy-jira",
  dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope.nvim" },
  config = function()
    require("lazy_jira").setup({
      layout = "vsplit",

      board_line_fields = {
        "key",
        "type",
        "assignee_initials",
        "status",
        "summary",
      },

      -- Optional custom config JSON:
      -- config_file = "~/.config/lazy-jira.json",
    })
  end,
}
```

---

## 🔑 Keybindings Overview

### From **Kanban board**

| Key    | Action                  |
| ------ | ----------------------- |
| `q`    | Close board             |
| `<CR>` | Open issue under cursor |
| `r`    | Reload board            |
| `?`    | Show help popup         |

---

### From **Issue buffer**

| Key  | Action                    |
| ---- | ------------------------- |
| `go` | Open in browser           |
| `gk` | Back to kanban board      |
| `gr` | Reload issue              |
| `gb` | Go back to previous issue |
| `cd` | Edit description          |
| `cs` | Change status             |
| `ca` | Add comment               |
| `ce` | Edit comment under cursor |
| `cr` | Delete comment            |
| `cA` | Change assignee           |
| `cb` | Create git branch         |
| `?`  | Show help popup           |

---

## ⚙️ Requirements

- Neovim **0.9+**
- Jira Cloud or Jira Server REST API
- Personal Access Token or Basic Auth
- `plenary.nvim`
- _(optional but recommended)_ `telescope.nvim`

---

## 🔐 Authentication Setup

The plugin loads credentials from JSON.

Default path:

```
~/.config/nvim/lazy-jira.json
```

Example file:

```json
{
  "base_url": "https://your-domain.atlassian.net",
  "username": "you@example.com",
  "token": "YOUR_JIRA_API_TOKEN"
}
```

Or override the file location:

```lua
require("lazy_jira").setup({
  config_file = "~/.config/lazy-jira.json",
})
```

Or use environment variables:

```bash
export LAZY_JIRA_BASE_URL="https://your-domain.atlassian.net"
export LAZY_JIRA_USERNAME="you@example.com"
export LAZY_JIRA_TOKEN="your_api_token"
```

---

## 🧩 ADF ↔ Markdown Notes

Supported:

- Bold
- Italic
- Inline code
- Fenced code blocks
- Links
- Paragraphs
- Lists

Not supported yet:

- Tables
- Images
- Complex nested formatting

---

## 📄 License

**MIT License**  
© 2025 Denis Lavrushko

---

## 💬 Feedback

PRs, ideas, and improvements are welcome!  
This plugin is actively developed for real-world daily workflow.
