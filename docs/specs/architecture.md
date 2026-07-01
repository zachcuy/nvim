---
title: Config Architecture
created: 2026-05-26
updated: 2026-05-26
status: active
topics:
  - architecture
  - lazyvim
  - lazy-nvim
---

# Config Architecture

## Overview

This is a LazyVim-based Neovim config. LazyVim provides a curated base layer of plugins, options, keymaps, and autocommands. This config customizes that base layer through overrides, additions, and selective disabling.

The plugin manager is lazy.nvim (the engine), and LazyVim (the framework) is loaded as the first plugin spec. Everything else layers on top.

## Boot Sequence

1. Neovim loads `init.lua`, which calls `require("config.lazy")`.
2. `lua/config/lazy.lua` bootstraps lazy.nvim (clones it from GitHub if missing), then calls `require("lazy").setup(...)`.
3. The `spec` table imports LazyVim core plugins first, then the four custom plugin groups.
4. LazyVim automatically loads `lua/config/options.lua`, `lua/config/keymaps.lua`, and `lua/config/autocmds.lua` at the appropriate lifecycle points (options first, keymaps and autocmds on the `VeryLazy` event).

### Spec Import Order

Defined in `lua/config/lazy.lua:18-26`:

```lua
spec = {
  { "LazyVim/LazyVim", import = "lazyvim.plugins" },
  { import = "lazyvim.plugins.extras.dap.core" },
  { import = "lazyvim.plugins.extras.dap.nlua" },
  { import = "langs" },
  { import = "search" },
  { import = "ui" },
  { import = "misc" },
},
```

Later imports can override earlier ones. A spec in `misc/` that targets the same plugin as a LazyVim default will have its `opts` deep-merged. To fully replace behavior, use `config = function()` instead of `opts`.

## Directory Layout

### `lua/config/` — Core Configuration

| File | Purpose | Load timing |
|-|-|-|
| `lazy.lua` | Bootstrap lazy.nvim, define spec imports, performance settings | Immediate (from init.lua) |
| `options.lua` | Vim options, highlight groups, cursor config, provider settings | Before plugins |
| `keymaps.lua` | Global keymaps, LazyVim keymap deletions/overrides | VeryLazy event |
| `autocmds.lua` | Custom autocommands (markdown/text settings) | VeryLazy event |

### `lua/langs/` — Language Tooling

| File | Plugin | Purpose |
|-|-|-|
| `lsp.lua` | nvim-lspconfig | LSP server overrides (disables Angular LS) |
| `blink.lua` | blink.cmp | Completion keymap config |
| `conform.lua` | conform.nvim | Formatter assignments per filetype |
| `nvim-lint.lua` | nvim-lint | Linter overrides (clears markdown linters) |
| `luasnip.lua` | LuaSnip | Snippet engine with custom snippet directory |
| `markdown.lua` | render-markdown.nvim | Markdown rendering (code blocks disabled) |
| `dap.lua` | nvim-dap / mason.nvim | Installs the PHP debug adapter; see `debugging.md` |

### `lua/search/` — Search and Navigation

| File | Plugin | Purpose |
|-|-|-|
| `fzf.lua` | fzf-lua | Fuzzy finder keymaps (grep, find files, literal grep) |
| `grug-far.lua` | grug-far.nvim | Project-wide search and replace |
| `harpoon2.lua` | harpoon (v2 branch) | File bookmarking with `<leader>1-5` quick access |
| `arrow.lua` | arrow.nvim | Global file bookmarks (`;`) and per-buffer marks (`m`) |

### `lua/ui/` — Visual and UI

| File | Plugin | Purpose |
|-|-|-|
| `colorscheme.lua` | lume | Colorscheme with custom comment highlights |
| `snacks.lua` | snacks.nvim | Lazygit config, dashboard disabled, picker sort |
| `oil.lua` | oil.nvim | File explorer with custom columns (filetype, mtime) |
| `bufferline.lua` | bufferline.nvim | Buffer tabs with Tab/S-Tab cycling |
| `scrollbar.lua` | (empty) | Scrollbar plugin fully commented out (was nvim-scrollbar with Catppuccin) |

### `lua/misc/` — Everything Else

| File | Plugin | Purpose |
|-|-|-|
| `flash.lua` | flash.nvim | Jump/motion plugin (S key disabled) |
| `mini-surround.lua` | mini.surround | Surround text objects (no padding for opening brackets) |
| `mini-comment.lua` | mini.comment | Comment toggling (C/C++ uses `//`, disables auto-continue) |
| `multicursor.lua` | multicursor.nvim | Multi-cursor editing (`<leader>z` prefix) |
| `nvim-spider.lua` | nvim-spider | Subword-aware `w`/`b`/`e` motions |
| `gitsigns.lua` | gitsigns.nvim | Git signs in gutter (disabled for markdown files) |
| `checkmate.lua` | checkmate.nvim | Markdown todo/checkbox management (`<leader>t` prefix) |
| `treesitter-context.lua` | nvim-treesitter-context | Sticky function/class context (max 3 lines) |
| `disabled.lua` | — | Explicitly disabled plugins (neo-tree) |
| `vim-sleuth.lua` | vim-sleuth | Auto-detect indent settings per file |

### Other Files

| File | Purpose |
|-|-|
| `lazyvim.json` | LazyVim extras manifest — managed by `:LazyExtras`, do not hand-edit |
| `lazy-lock.json` | Plugin version lockfile — managed by lazy.nvim |
| `.neoconf.json` | Neodev/neoconf settings for Lua LSP |
| `stylua.toml` | StyLua formatter config (2-space indent, 120 col) |
| `snippets/*.json` | Custom VSCode-format snippets loaded by LuaSnip |

## How LazyVim Plugin Overriding Works

When two specs target the same plugin (identified by the short `"author/name"` string), lazy.nvim merges them:

- `opts` tables are **deep-merged** (nested keys combine, later values win for same key).
- `keys` tables are **appended** (you can add new keymaps without losing LazyVim's).
- `config` functions are **replaced** (if you define `config`, you take full control; LazyVim's `config` is discarded for that plugin).
- `enabled = false` disables the plugin entirely regardless of what LazyVim defines.

This means you can override a single option without rewriting the entire config. Example from `lua/ui/snacks.lua`: it only sets `lazygit`, `dashboard`, and `picker` options, and LazyVim's other snacks options remain intact.

## Performance Configuration

Set in `lua/config/lazy.lua:36-54`:

- `defaults.lazy = false` — Custom plugins load eagerly (LazyVim's own plugins are still lazy-loaded by LazyVim).
- `checker.enabled = false` — No automatic update checks.
- `version = false` — Always use latest git commit, not tagged releases.
- Disabled runtime plugins: gzip, tarPlugin, tohtml, tutor, zipPlugin.
