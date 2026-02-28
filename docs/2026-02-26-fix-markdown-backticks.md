# Fix Markdown Code Block Visibility

**Date:** 2026-02-26
**Scope:** Disabled code block concealing in LazyVim for markdown files to make backticks visible.
**Files Modified:** `lua/config/autocmds.lua`, `lua/langs/markdown.lua`

## Overview
The user requested that markdown code block backticks (```) and their containing lines be visible as normal text, rather than being hidden. In LazyVim with the `lang.markdown` extra enabled, code block delimiters are concealed by two mechanisms: TreeSitter (`conceallevel`) and the `render-markdown.nvim` plugin.

## Implementation Details
Two changes were made to resolve the issue:

1. **Disabled `render-markdown.nvim`'s code styling:**
   Created `lua/langs/markdown.lua` to override the `MeanderingProgrammer/render-markdown.nvim` plugin. Set `code = { enabled = false }` in its options. This stops the plugin from replacing the ```` language lines with virtual text backgrounds and icons, allowing the raw text to be rendered.

2. **Disabled TreeSitter Conceal:**
   Modified `lua/config/autocmds.lua` to set `vim.opt_local.conceallevel = 0` for `markdown` files. By default, LazyVim sets `conceallevel = 2` or `3`, which tells TreeSitter to hide markdown delimiters such as code backticks, bold/italic markers, etc.

## Changes Summary
| File | Change Type | Description |
|------|-------------|-------------|
| `lua/config/autocmds.lua` | Modified | Added `vim.opt_local.conceallevel = 0` to existing markdown FileType autocmd |
| `lua/langs/markdown.lua` | Created | Disabled the code styling feature of `render-markdown.nvim` |
