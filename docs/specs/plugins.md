---
title: Plugin Reference
created: 2026-05-26
updated: 2026-05-26
status: active
topics:
  - plugins
  - lazy-nvim
---

# Plugin Reference

Complete inventory of custom plugin specs in this config. Plugins provided by LazyVim extras (listed in `lazyvim.json`) are not repeated here unless this config overrides their defaults.

## Language Tooling (`lua/langs/`)

### nvim-lspconfig (`lsp.lua`)

Overrides LazyVim's LSP server list. Currently only disables Angular Language Server (`angularls = false`). All other LSP servers come from enabled LazyVim extras (clangd, typescript, rust-analyzer, etc.).

### blink.cmp (`blink.lua`)

Completion engine. Replaces nvim-cmp. Custom keymap preset:

| Key | Action |
|-|-|
| `<C-space>` | Show / show docs / hide docs (toggle) |
| `<C-k>` | Show / hide signature help |
| `<C-e>` | Hide completion menu |
| `<C-f>` | Accept selected completion |
| `<Up>` / `<Down>` | Select prev / next |
| `<C-p>` / `<C-n>` | Select prev / next |
| `<C-.>` / `<C-,>` | Scroll documentation up / down |
| `<CR>` | Fallback (does NOT accept) |
| `<Tab>` / `<S-Tab>` | Fallback (does NOT cycle) |

The explicit fallback on `<CR>`, `<Tab>`, and `<S-Tab>` means those keys behave as normal Neovim keys, not completion triggers.

### conform.nvim (`conform.lua`)

Formatter assignments. Autoformat is OFF by default (`vim.g.autoformat = false`). Toggle with `<leader>uf`.

| Filetype | Formatter(s) |
|-|-|
| astro, html, css, scss | prettierd, prettier (fallback) |
| javascript, typescript, jsx, tsx | prettierd, prettier (fallback) |
| json, yaml | prettierd, prettier (fallback) |
| java | prettier |
| c, cpp | clang_format |
| lua | stylua |
| rust | rustfmt |

Markdown formatting is commented out (disabled).

### nvim-lint (`nvim-lint.lua`)

Linter overrides. Currently only clears markdown linters (empty table), so markdown files have no lint warnings.

### LuaSnip (`luasnip.lua`)

Snippet engine with two sources:

1. **friendly-snippets** — Community snippet collection (loaded via `lazy_load()`).
2. **Custom snippets** — From `~/.config/nvim/snippets/` (VSCode JSON format).

Custom snippet files:

- `cpp.json` — C++ class templates (`[snippet] class`, `[snippet] classfull`).
- `rust.json` — Rust debug print helpers (`[snippet] dbg`, `[snippet] dbgf`, `[snippet] dbgl`, `[snippet] edbg`).

### render-markdown.nvim (`markdown.lua`)

Markdown rendering in the buffer. Code block rendering is disabled (`code.enabled = false`); other render-markdown features (headings, lists, checkboxes) use defaults.

### nvim-dap (`dap.lua` + `dap.core`/`dap.nlua` extras)

Debugger (Debug Adapter Protocol client), enabled through the `dap.core` and `dap.nlua` LazyVim extras (imported in `lua/config/lazy.lua`). `dap.core` installs nvim-dap, nvim-dap-ui, nvim-dap-virtual-text, and mason-nvim-dap, and defines all `<leader>d` keymaps. Language adapters and launch configs come from the language extras (rust, clangd, typescript, php) and activate automatically once nvim-dap is present.

`lua/langs/dap.lua` closes the single gap LazyVim leaves: it installs the PHP debug adapter (`php-debug-adapter`) via Mason, which LazyVim's php extra references but never installs.

Adapters: `codelldb` (Rust, C/C++), `js-debug-adapter` (TS/JS, browser), `php-debug-adapter` (PHP), and the bundled `nlua` adapter (Lua). See `debugging.md` for full usage, installation, and per-language setup.

## Search and Navigation (`lua/search/`)

### fzf-lua (`fzf.lua`)

Fuzzy finder. Overrides three LazyVim default keymaps to use cwd instead of project root:

| Key | Action |
|-|-|
| `<leader>/` | Live grep (cwd) |
| `` <leader>` `` | Live grep with `--fixed-strings` / literal mode (cwd) |
| `<leader><space>` | Find files (cwd) |

### grug-far.nvim (`grug-far.lua`)

Project-wide search and replace with ripgrep backend. Two entry points:

| Key | Scope |
|-|-|
| `<leader>sr` | Search/replace filtered to current file extension |
| `<leader>r` | Search/replace scoped to current file (defined in `keymaps.lua`) |

Also integrated into Oil: pressing `gs` in Oil opens grug-far scoped to the directory Oil is showing.

### harpoon v2 (`harpoon2.lua`)

File bookmarking. Uses the `harpoon2` branch of ThePrimeagen/harpoon.

| Key | Action |
|-|-|
| `<leader>a` | Add current file to harpoon list |
| `<leader>h` | Open harpoon quick menu |
| `<leader>1` through `<leader>5` | Jump to harpoon file 1-5 |

Settings: `save_on_toggle = true`, menu width matches window width.

### arrow.nvim (`arrow.lua`)

Complementary bookmark system with two modes:

| Key | Mode |
|-|-|
| `;` | Global file bookmarks (cross-buffer) |
| `m` | Per-buffer bookmarks |

## UI and Visual (`lua/ui/`)

### lume (`colorscheme.lua`)

Colorscheme: `danfry1/lume`. Loaded eagerly with `priority = 1000`. After setup, comment highlight groups are overridden to mint-green italic (`#75d7b3`) for both `Comment` and `@comment` (Treesitter).

### snacks.nvim (`snacks.lua`)

Overrides for folke/snacks.nvim (LazyVim's utility layer):

- **Lazygit**: `configure = false` — theme is managed externally in lazygit's own config. Window highlight set to `Normal` (not `NormalFloat`).
- **Dashboard**: Disabled.
- **Picker**: Recent files sorted by `idx` (access time).

Global settings (in `options.lua`): `vim.g.snacks_animate = false` disables all snacks animations.

### oil.nvim (`oil.lua`)

File explorer (replaces neo-tree). Shows custom columns:

1. **icon** — File type icon (via mini.icons).
2. **filetype** — Detected filetype with human-friendly overrides (cpp -> c++, md -> markdown, etc.).
3. **mtime** — Last modified timestamp.

Settings: `delete_to_trash = true`, hidden files shown, natural sort order.

| Key (inside Oil) | Action |
|-|-|
| `<C-s>` | Save buffer (overrides default Oil split) |
| `q` | Close Oil |
| `gs` | Open grug-far scoped to current Oil directory |
| `<leader>fo` | Open current directory in macOS Finder |
| `<C-h>`, `<C-t>` | Disabled (were horizontal split and new tab) |

### bufferline.nvim (`bufferline.lua`)

Buffer tab bar. Minimal appearance: no close icons, no buffer icons, no diagnostics badges, max 12 char names. Selected buffer highlighted in yellow (`#FCF596`).

| Key | Action |
|-|-|
| `<Tab>` | Next buffer |
| `<S-Tab>` | Previous buffer |
| `<leader>bs` | Sort buffers by relative directory |
| `<leader>bn` | Move buffer position right (defined in `keymaps.lua`) |
| `<leader>bp` | Move buffer position left (defined in `keymaps.lua`) |

### scrollbar.lua

Returns an empty table. Contains a fully commented-out nvim-scrollbar config that was previously used with a Catppuccin theme. Kept as reference for potential re-enabling.

## Misc Plugins (`lua/misc/`)

### flash.nvim (`flash.lua`)

Jump/motion plugin. Loaded on `VeryLazy`. The `S` key (treesitter search) is explicitly disabled (`{"S", false}`) to avoid conflicting with the disabled `S` normal-mode mapping and mini.surround workflow.

### mini.surround (`mini-surround.lua`)

Surround text objects. Opening brackets `(`, `[`, `{` are configured with no padding (no space between bracket and content). Default LazyVim mini.surround uses `gsa` (add), `gsd` (delete), `gsr` (replace).

### mini.comment (`mini-comment.lua`)

Comment toggling. Two autocmds are set inside the opts table:

1. **C/C++ files**: Forces `commentstring` to `// %s` (line comments, not block comments).
2. **All files**: Removes `c`, `r`, `o` from `formatoptions` on `BufEnter` to prevent auto-continuing comments on new lines.

### multicursor.nvim (`multicursor.lua`)

Multi-cursor editing (branch `1.0` of jake-stewart/multicursor.nvim).

| Key | Action |
|-|-|
| `<leader>zn` | Add cursor at next match |
| `<leader>zs` | Skip current, move to next match |
| `<leader>zN` | Add cursor at previous match |
| `<leader>zS` | Skip current, move to previous match |
| `<leader>zr` | Restore accidentally cleared cursors |
| `<C-LeftMouse>` | Add cursor at click position |
| `<C-q>` | Toggle cursor enabled/disabled |
| `<Esc>` (multi-cursor layer) | Enable cursors or clear all |

Custom highlight groups link multicursor visuals to existing `Visual`, `SignColumn`, and `Search` groups.

### nvim-spider (`nvim-spider.lua`)

Replaces default `w`, `b`, `e` word motions in normal, operator-pending, and visual modes. Moves by subwords (respects camelCase, snake_case boundaries). `skipInsignificantPunctuation = false` means punctuation is not skipped.

### gitsigns.nvim (`gitsigns.lua`)

Git change indicators in the sign column. Custom `on_attach` wraps LazyVim's default to disable gitsigns entirely for markdown files.

### checkmate.nvim (`checkmate.lua`)

Markdown todo/checkbox management. Loaded only for markdown files (`ft = "markdown"`).

| Key | Action |
|-|-|
| `<leader>tt` | Toggle todo item |
| `<leader>tc` | Check (mark done) |
| `<leader>tu` | Uncheck (mark not done) |
| `<leader>t=` | Cycle to next state |
| `<leader>t-` | Cycle to previous state |
| `<leader>tn` | Create new todo item |
| `<leader>tr` | Remove todo marker |
| `<leader>tR` | Remove all metadata |
| `<leader>ta` | Archive completed items |
| `<leader>tF` | Picker to select a todo |
| `<leader>tp` | Add/update `@priority` tag |
| `<leader>ts` | Add `@started` tag (auto-dates) |
| `<leader>td` | Add `@done` tag (auto-dates, checks item) |
| `<leader>tv` | Update metadata tag value |
| `<leader>t]` / `<leader>t[` | Jump to next/prev metadata tag |

Metadata tags: `@priority` (low/medium/high with color), `@started` (date), `@done` (date, auto-checks).

### treesitter-context (`treesitter-context.lua`)

Shows sticky context (function name, class, etc.) at the top of the window. Max 3 lines, cursor-based mode, trims outer context first.

### disabled.lua

Explicitly disabled plugins:

- `nvim-neo-tree/neo-tree.nvim` — replaced by Oil.

Contains commented-out entries for tokyonight (former colorscheme), dashboard-nvim, and persistence.nvim.

### vim-sleuth (`vim-sleuth.lua`)

Auto-detects indent settings (tabs vs spaces, indent width) from file content and surrounding files. Loads on `BufReadPre` and `BufNewFile`.
