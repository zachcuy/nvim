---
title: Customization Guide
created: 2026-05-26
updated: 2026-05-26
status: active
topics:
  - customization
  - howto
---

# Customization Guide

How to add, modify, and remove things in this config.

## Adding a New Plugin

1. Pick the right directory based on category:

| Directory | When to use |
|-|-|
| `lua/langs/` | Language servers, formatters, linters, snippets, syntax |
| `lua/search/` | Finding files, grep, bookmarks, navigation |
| `lua/ui/` | Appearance, file explorer, statusline, bufferline |
| `lua/misc/` | Anything that doesn't fit the above |

2. Create a new `.lua` file named after the plugin (e.g., `lua/misc/todo-comments.lua`).

3. Return a lazy.nvim plugin spec table:

```lua
return {
  "folke/todo-comments.nvim",
  event = "VeryLazy",
  opts = {
    -- your options here
  },
}
```

Multiple plugins can share a file if tightly related — return a table of specs:

```lua
return {
  { "plugin-a", opts = {} },
  { "plugin-b", opts = {} },
}
```

4. The plugin loads automatically on next Neovim start. No manual registration needed — lazy.nvim discovers all `.lua` files in the imported directories.

## Overriding a LazyVim Default Plugin

Create a file that returns a spec targeting the same plugin name. The `opts` table deep-merges with LazyVim's defaults.

Example: to change snacks.nvim dashboard settings, the existing `lua/ui/snacks.lua` does this:

```lua
return {
  "folke/snacks.nvim",
  opts = {
    dashboard = { enabled = false },  -- disables just the dashboard
  },
}
```

You don't need to repeat LazyVim's full snacks config. Only the keys you specify are merged in.

If you need full control (not a merge), use `config` instead of `opts`:

```lua
return {
  "some/plugin",
  config = function()
    require("plugin").setup({
      -- your COMPLETE config; LazyVim's opts are ignored
    })
  end,
}
```

## Disabling a Plugin

Add to `lua/misc/disabled.lua`:

```lua
return {
  { "author/plugin-name", enabled = false },
  -- add more here
}
```

Or disable in the plugin's own file if it has one — same syntax.

## Adding or Changing Keymaps

### Global keymaps

Edit `lua/config/keymaps.lua`. Use `vim.keymap.set`:

```lua
vim.keymap.set("n", "<leader>xx", function()
  -- your action
end, { noremap = true, silent = true, desc = "My action" })
```

Always include `desc` — it shows up in which-key.

### Deleting a LazyVim keymap

```lua
vim.keymap.del("n", "<leader>whatever")
```

This must be in `keymaps.lua` (loaded after LazyVim's keymaps).

### Plugin-specific keymaps

Define in the plugin spec's `keys` table. This also lazy-loads the plugin when the key is pressed:

```lua
return {
  "author/plugin",
  keys = {
    { "<leader>xx", "<cmd>PluginCommand<cr>", desc = "Do thing" },
  },
}
```

## Adding a Formatter

Edit `lua/langs/conform.lua`. Add to the `formatters_by_ft` table:

```lua
formatters_by_ft = {
  python = { "black" },    -- add this line
  -- existing entries...
},
```

The formatter binary must be installed on your system (or installable via Mason). Autoformat is off by default; toggle with `<leader>uf`.

## Adding a Linter

Edit `lua/langs/nvim-lint.lua`. Add to `linters_by_ft`:

```lua
linters_by_ft = {
  python = { "ruff" },
  markdown = {},  -- existing: cleared
},
```

## Adding Custom Snippets

1. Create a JSON file in `snippets/` using VSCode snippet format:

```json
{
  "Snippet Name": {
    "prefix": "[snippet] trigger",
    "body": [
      "line 1",
      "line 2 with ${1:placeholder}",
      "$0"
    ],
    "description": "What it does"
  }
}
```

2. Name the file after the language (e.g., `python.json`, `go.json`). LuaSnip matches the filename to the filetype.

3. Use the `[snippet]` prefix convention so custom snippets are easy to spot in the completion menu.

## Enabling a LazyVim Extra

Run `:LazyExtras` in Neovim. Navigate to the extra you want, press `x` to toggle it. This updates `lazyvim.json` automatically.

Do not hand-edit `lazyvim.json`. The `:LazyExtras` UI manages the file and validates compatibility.

After enabling a language extra (e.g., `lazyvim.plugins.extras.lang.python`), restart Neovim. Mason will auto-install the required LSP server, formatter, and linter on first load.

## Adding an Autocommand

Edit `lua/config/autocmds.lua`:

```lua
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "python" },
  callback = function()
    vim.opt_local.tabstop = 4
  end,
})
```

To remove a LazyVim default autocmd, delete it by group name:

```lua
vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
```

LazyVim prefixes all its autocmd groups with `lazyvim_`.

## Changing the Colorscheme

Edit `lua/ui/colorscheme.lua`. Replace the plugin and `colorscheme` command:

```lua
return {
  {
    "author/new-theme",
    lazy = false,
    priority = 1000,
    config = function()
      require("new-theme").setup()
      vim.cmd("colorscheme new-theme")
      -- optional highlight overrides here
    end,
  },
}
```

`lazy = false` and `priority = 1000` ensure the colorscheme loads before everything else.

## Changing Vim Options

Edit `lua/config/options.lua`. This file runs before plugins load, so it's the right place for:

- `vim.opt.*` settings (tabstop, wrap, number, etc.)
- `vim.g.*` global variables (provider settings, plugin globals)
- Highlight group definitions (`vim.api.nvim_set_hl`)
- Cursor configuration (`vim.opt.guicursor`)

## Updating Plugins

Run `:Lazy` in Neovim to open the lazy.nvim UI, then press `U` to update all plugins. The lockfile (`lazy-lock.json`) is updated automatically.

To restore a previous state, use `:Lazy restore` which reads the lockfile.

## Branch-Specific Configs

This repo has branches for different machines: `main`, `macbook`, `macbook-reset`, `ubuntu-desktop`. The current branch is `macbook-reset`. Machine-specific differences (paths, OS-specific keymaps) live in the branch; shared improvements should be merged back to `main`.
