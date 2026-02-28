# Fix Checkmate.nvim GitSigns Conflict

**Date:** 2026-02-28
**Scope:** Configured checkmate.nvim to use standard markdown checkbox syntax instead of unicode markers to prevent GitSigns from thinking the file is modified.
**Files Modified:**
- `lua/misc/checkmate.lua`

## Overview
The user reported that `checkmate.nvim` was rendering a Git change sign/marker on incomplete todo lines. After investigating, the issue wasn't the plugin's styling but rather that Checkmate physically modifies the buffer contents upon loading.

Checkmate converts standard Markdown `[ ]` and `[x]` into Unicode markers `□` and `✔` in the buffer while you edit, and converts them back when you save. This causes `gitsigns.nvim` to accurately detect that the buffer has changed compared to the git index, resulting in real Git diff signs appearing in the signcolumn for every unchecked todo list item.

## Implementation Details
1. **Disabled Unicode Markers**: To prevent Checkmate from actively modifying the buffer on load, we configured it to use standard Markdown syntax (`[ ]` and `[x]`) as its in-buffer markers. This means the buffer perfectly matches the file on disk, so GitSigns doesn't see any diff.

```lua
-- lua/misc/checkmate.lua
opts = {
  todo_states = {
    unchecked = { marker = "[ ]", order = 1 },
    checked = { marker = "[x]", order = 2 },
  },
}
```

## Changes Summary
| File | Change Type | Description |
|------|-------------|-------------|
| lua/misc/checkmate.lua | Modified | Configured `todo_states` to use standard Markdown text instead of Unicode characters |
