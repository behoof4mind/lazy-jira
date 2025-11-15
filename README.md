# lazy-jira

A fast, minimal, Neovim-native Jira client designed for real-world daily usage.  
It gives you **Kanban boards**, **issue viewer**, **status transitions**,  
**comment editing with Markdown → ADF**, **description editing**,  
**assignee picker**, and a beautiful floating UI — all inside Neovim.

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
  - Comments
- All formatting cleaned and rendered with readable plain text
- Press `?` to open a floating help popup with all hotkeys

### 📝 Markdown Editing (ADF conversion)

Works for:

- **bold** → Jira strong
- _italic_ → Jira emphasis
- `inline code`
- ```
  fenced
  code blocks
  ```
- [Links](https://example.com)

All conversion is bidirectional:

- Jira ADF → Markdown for editing
- Markdown → ADF for saving

### 💬 Comments

- Add new comment
- Edit comment (Markdown popup)
- Delete comment
- Multiline code blocks supported

### 🗒 Description Editor

- Edit the issue description in a full markdown popup
- Supports all formatting features listed above

### 🔄 Status Transitions

- Telescope picker (recommended)
- Fallback to `vim.ui.select()` if Telescope is missing

### 👤 Change Assignee

- Telescope-based user picker
- Works even if issue has no assignee
- Shows all assignable users for the project

### 🌿 Git workflow helpers

- Create feature branch from issue summary:

  ```
  KEY-123/add-cool-feature
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
      -- "vsplit" / "hsplit" / "current"
      layout = "vsplit",

      -- What fields to show on kanban lines
      board_line_fields = {
        "key",
        "type",
        "assignee_initials",
        "status",
        "summary",
      },
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
| `gk` | Open Kanban board         |
| `gr` | Reload issue              |
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

- Neovim 0.9+
- Jira Cloud or Jira Server with REST API
- Personal Access Token or Basic Auth
- `plenary.nvim`
- (Optional but recommended) `telescope.nvim`

---

## 🔐 Authentication Setup

Create `~/.config/lazy-jira.json`:

```json
{
  "base_url": "https://your-domain.atlassian.net",
  "username": "you@example.com",
  "token": "YOUR_JIRA_API_TOKEN"
}
```

Or set environment variables:

```bash
export LAZY_JIRA_BASE_URL="https://your-domain.atlassian.net"
export LAZY_JIRA_USERNAME="you@example.com"
export LAZY_JIRA_TOKEN="your_api_token"
```

---

## 🧩 API Notes

### ADF ↔ Markdown

The plugin converts between Jira ADF and Markdown, supporting:

- Bold
- Italic
- Inline code
- Fenced code blocks
- Links
- Paragraph structure

Tables and images are not supported yet.

---

## 📄 License

**MIT License**  
© 2025 Denis Lavrushko

---

## 💬 Feedback

Feel free to open issues, propose improvements, or send PRs!  
This plugin is actively improved and tailored for real‑world workflow efficiency.
