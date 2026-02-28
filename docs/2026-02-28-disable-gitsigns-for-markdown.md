# Fix Checkmate.nvim GitSigns Conflict (Revisited)

**Date:** 2026-02-28
**Scope:** Disabled GitSigns specifically for markdown files to avoid conflicts with `checkmate.nvim`'s buffer modification behavior.
**Files Modified:**
- `lua/misc/gitsigns.lua` (Created)

## Overview
The user reported that the previous fix did not work. Upon deeper inspection, the issue wasn't the styling or linting, but rather the core mechanic of `checkmate.nvim`: it physically rewrites the buffer contents from `[ ]` and `[x]` to Unicode characters `□` and `✔` behind the scenes. 

Because the buffer text actually changes from what is committed to git, `gitsigns.nvim` sees the difference and renders git modification signs on every list item line. 

Instead of trying to fight `checkmate.nvim`'s core behavior, the most robust solution is to just tell `gitsigns.nvim` not to attach to markdown buffers.

## Implementation Details
We added an override for `gitsigns.nvim` that hooks into its `on_attach` callback. If the buffer's filetype is `markdown`, we return `false` to abort attaching GitSigns to that buffer, while preserving LazyVim's default `on_attach` keymaps for all other filetypes.

```lua
-- lua/misc/gitsigns.lua
return {
  {
    "lewis6991/gitsigns.nvim",
    opts = function(_, opts)
      local orig_on_attach = opts.on_attach
      opts.on_attach = function(bufnr)
        -- Disable GitSigns for markdown files
        if vim.bo[bufnr].filetype == "markdown" then
          return false
        end
        if orig_on_attach then
          orig_on_attach(bufnr)
        end
      end
    end,
  },
}
```

## Changes Summary
| File | Change Type | Description |
|------|-------------|-------------|
| lua/misc/gitsigns.lua | Created | Intercepted GitSigns `on_attach` to return `false` for Markdown files |
| lua/misc/checkmate.lua | Modified | Reverted previous checkmate configuration attempts |
