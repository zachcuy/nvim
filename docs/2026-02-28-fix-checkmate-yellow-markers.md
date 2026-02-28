# Fix Checkmate.nvim Yellow Markers

**Date:** 2026-02-28
**Scope:** Disabled checkmate.nvim's linter and removed diagnostic warning color from unchecked markers to prevent yellow git-diff-like signs/markers.
**Files Modified:**
- `lua/misc/checkmate.lua`

## Overview
The user reported that `checkmate.nvim` was rendering a light-yellow sandy colored marker exactly the same as git diff changes on incomplete todo lines. This was tracked down to `checkmate.nvim`'s default styling and linter behavior, which uses Neovim's `DiagnosticWarn` highlight group.

## Implementation Details
1. **Linter Disable**: `checkmate.nvim` runs a custom markdown linter that validates list indentation. When a list item is improperly indented according to strict CommonMark rules (e.g., 2 spaces instead of 3), it triggers a `vim.diagnostic.set` with a `WARN` severity. In LazyVim, this renders a yellow sign in the signcolumn, completely identical to a Git modified (`~` or `|`) sign. Setting `linter = { enabled = false }` disables this.
2. **Style Override**: Checkmate explicitly colors the unchecked `□` marker with the `colors.diagnostic_warn` color. This causes the marker itself to match the Git diff color. To fix this, we overrode the `CheckmateUncheckedMarker` highlight group to use `fg = "NONE"`.

```lua
-- lua/misc/checkmate.lua
opts = {
  linter = {
    enabled = false,
  },
  style = {
    CheckmateUncheckedMarker = { fg = "NONE", bold = false },
  },
}
```

## Changes Summary
| File | Change Type | Description |
|------|-------------|-------------|
| lua/misc/checkmate.lua | Modified | Disabled checkmate linter and overrode CheckmateUncheckedMarker highlight group |
