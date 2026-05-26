# Neovim Config

LazyVim-based Neovim configuration using lazy.nvim for plugin management.

## Directory Structure

```
init.lua                  # Entry point (requires config.lazy)
lua/config/
  lazy.lua                # Bootstraps lazy.nvim, defines plugin spec imports
  options.lua             # Vim options, highlight groups, cursor config
  keymaps.lua             # Global keymaps and LazyVim keymap overrides
  autocmds.lua            # Autocommands
lua/langs/                # Language tooling (LSP, completion, formatting, linting, snippets)
lua/search/               # Search and navigation (fzf, grug-far, harpoon, arrow)
lua/ui/                   # Visual/UI (colorscheme, snacks, oil, bufferline)
lua/misc/                 # Everything else (flash, surround, comment, multicursor, etc.)
snippets/                 # Custom VSCode-format JSON snippets (loaded by LuaSnip)
lazyvim.json              # LazyVim extras manifest (do not hand-edit; use :LazyExtras)
```

Plugin specs are NOT in the standard LazyVim `lua/plugins/` directory. They use four custom import groups defined in `lua/config/lazy.lua`: `langs`, `search`, `ui`, `misc`. Each `.lua` file in these directories returns a lazy.nvim plugin spec table.

## Core Design Decisions

- **Colorscheme**: Lume (`danfry1/lume`) with mint-green italic comments (`#75d7b3`).
- **File explorer**: Oil.nvim replaces neo-tree (neo-tree explicitly disabled in `misc/disabled.lua`).
- **Fuzzy finder**: fzf-lua via LazyVim extra (not Telescope).
- **Completion**: blink.cmp. Accept with `<C-f>`. `<CR>` and `<Tab>` are explicitly unbound from completion.
- **Autoformat**: OFF by default (`vim.g.autoformat = false` in options.lua).
- **Macro recording**: Disabled (`q` mapped to noop in keymaps.lua).
- **Word motion**: nvim-spider overrides `w`/`b`/`e` with subword-aware (camelCase) movement.
- **Cursor**: Block cursor in all modes. Yellow blinking in insert/replace/command, white in normal.
- **Snacks**: Dashboard disabled, animations disabled.
- **Tabs as spaces**: 4-space indent by default, with vim-sleuth for per-file auto-detection.

## Key Overrides from LazyVim Defaults

Do not re-add these LazyVim defaults; they are intentionally overridden or removed:

| Key | Remapped to | LazyVim default replaced |
|-|-|-|
| `<Tab>` / `<S-Tab>` | Cycle buffers (BufferLine) | Indent/snippet navigation |
| `<leader>o`, `<leader>e` | Open Oil | File explorer |
| `<leader>/` | Grep cwd | Grep project root |
| `<leader><space>` | Find files cwd | Find files project root |
| `` <leader>` `` | Literal (fixed-string) grep | Switch to other buffer |
| `<leader>bp` / `<leader>bP` | BufferLine move prev/next | Pin buffer / delete non-pinned |
| `S` (normal) | Disabled | Substitute line |
| `q` (normal, visual) | Disabled | Record macro |
| `p` / `P` (visual) | Swapped | Default paste |
| `<leader>uz` / `<leader>uZ` | Deleted | Fold toggles |

## LazyVim Extras

Enabled in `lazyvim.json` (manage with `:LazyExtras`):

- **Coding**: mini-comment, mini-surround
- **Editor**: fzf, inc-rename
- **Languages**: angular, clangd, json, markdown, php, rust, tailwind, typescript, yaml
- **Util**: dot, mini-hipatterns

## Making Changes

### Add a plugin

Create a `.lua` file in the appropriate directory returning a lazy.nvim spec:

```lua
return {
  "author/plugin-name",
  opts = {},
}
```

Choose directory by category: `langs/` for language tooling, `search/` for search/navigation, `ui/` for visual/UI, `misc/` for everything else.

### Override a LazyVim plugin

Return a spec with the same plugin short name. The `opts` table deep-merges with LazyVim defaults:

```lua
return {
  "existing/plugin",
  opts = { your_option = "value" },
}
```

### Disable a plugin

Add to `lua/misc/disabled.lua`:

```lua
{ "author/plugin-name", enabled = false },
```

### Add a keymap

Add to `lua/config/keymaps.lua` using `vim.keymap.set`. Delete LazyVim defaults with `vim.keymap.del`. Do NOT use `LazyVim.safe_keymap_set` (that is internal to LazyVim).

### Add a formatter or linter

Edit `lua/langs/conform.lua` (formatters) or `lua/langs/nvim-lint.lua` (linters).

### Add custom snippets

Add a JSON file to `snippets/` in VSCode snippet format. LuaSnip auto-loads from that directory. Use `[snippet]` prefix in trigger names for discoverability via completion menu.

### Enable a LazyVim extra

Run `:LazyExtras` in Neovim, select the extra, and it updates `lazyvim.json` automatically. Do not hand-edit `lazyvim.json`.

## External Dependencies

- **Lazygit**: Theme managed externally in `~/Library/Application Support/lazygit/config.yml` (not in this repo). Snacks lazygit `configure = false` defers to that file.
- **Python host**: Hardcoded to `/usr/bin/python3` (update in `options.lua` if path differs).
- **Perl provider**: Disabled.
- **stylua**: Config in `stylua.toml` (2-space indent, 120 column width).

## Formatting

Lua files in this config use 2-space indentation per `stylua.toml`. Run `stylua .` from the config root to format.

## Documentation

Read these before making changes:

@docs/specs/architecture.md
@docs/specs/plugins.md
@docs/specs/keymaps.md
@docs/specs/customization-guide.md
