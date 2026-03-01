# Oil.nvim Custom Columns Configuration

**Date:** 2026-03-01
**Scope:** Added a custom filetype column and configured metadata columns in oil.nvim.
**Files Modified:** `lua/ui/oil.lua`

## Overview
Configured the `oil.nvim` file explorer to show additional columns like last modified date (`mtime`) and a customized `filetype` column that explicitly displays the human-readable file type (e.g., `markdown` for `.md`, `c++` for `.cpp`).

## Implementation Details
1. **Registered Custom Column:** Added `require("oil.columns").register("filetype", {...})` inside the `oil.nvim` config function.
2. **Type Resolution:** The custom column uses `vim.filetype.match` internally, falling back to the raw file extension.
3. **Overrides:** An explicit override map is used to map standard output like `cpp` to `c++` or `md` to `markdown` per the user's request.
4. **Configuration Update:** Added the `columns` key in `oil.setup` to enable `icon`, `filetype`, and `mtime` (last modified date) by default.

## Changes Summary
| File | Change Type | Description |
|------|-------------|-------------|
| lua/ui/oil.lua | Modified | Registered a custom `filetype` column and configured the `oil.setup` columns. |

