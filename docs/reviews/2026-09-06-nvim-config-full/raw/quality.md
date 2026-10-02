## HIGH: LuaSnip loaded eagerly at startup with zero consumers (~17% of startup time)
Location: /Users/zcu/.config/nvim/lua/langs/luasnip.lua:1-11
Evidence:
```lua
  config = function()
    require("luasnip.loaders.from_vscode").lazy_load()
    -- Load your custom snippets
    require("luasnip.loaders.from_vscode").lazy_load({ paths = { "~/.config/nvim/snippets" } })
  end,
```
Problem: The spec has no `event`/`ft`/`keys`/`cmd`, and `defaults.lazy = false` (lua/config/lazy.lua:33), so LuaSnip loads at startup — 7.8 ms of a 46 ms startup (runtime-facts.md:7,30). Nothing consumes it: blink.cmp `snippets.preset = "default"` (runtime-facts.md:30) uses `vim.snippet`, and blink's own registry already scans `stdpath('config') .. '/snippets'` and every rtp path matching `friendly.snippets` (blink.cmp/lua/blink/cmp/sources/snippets/default/registry.lua:17,31-34), so the two `lazy_load()` calls are a duplicate directory scan feeding a registry no completion source reads. The hardcoded `~/.config/nvim/snippets` also bypasses `vim.fn.stdpath("config")`.
Fix: Replace the whole file with a bare `return { "rafamadriz/friendly-snippets" }` spec (eager under `defaults.lazy = false`, so it stays in rtp for blink's scan). That removes the 7.8 ms, the duplicate scan, and the hardcoded path in one change. If LuaSnip is wanted, set blink `snippets.preset = "luasnip"` so the cost buys something.
Category: performance
Confidence: HIGH
Counter-argument: "friendly-snippets disappears if LuaSnip goes." It only disappears if the dependency is dropped too — the fix keeps it as a top-level spec, and registry.lua:31-34 confirms blink finds it by rtp path match, not by LuaSnip.

## MEDIUM: Oil filetype column re-runs full filetype pattern scan for every directory entry
Location: /Users/zcu/.config/nvim/lua/ui/oil.lua:16-42
Evidence:
```lua
          local name = entry[require("oil.constants").FIELD_NAME] or ""
          local type = entry[require("oil.constants").FIELD_TYPE]
          local ft = vim.filetype.match({ filename = name })
          local overrides = { cpp = "c++", md = "markdown", ... }
```
Problem: `render` is called once per entry per format (oil.nvim/lua/oil/view.lua:791 inside the `column_defs` loop in `format_entry_cols`). `vim.filetype.match` with only `filename` walks the entire positive pattern table before it ever reaches the extension lookup (filetype.lua:2918-2934 in v0.11.4), and its `parent_matches` memo table is allocated fresh per call (filetype.lua:2920) so nothing is reused across entries. Each entry also pays two `require("oil.constants")` calls and a 7-key table allocation for `overrides`.
Fix: Hoist `local constants = require("oil.constants")` and `local overrides = {...}` to file scope, and memoize the result in a module-level `local ft_cache = {}` keyed by the file extension (`name:match("%.([^.]+)$")`) — extension is what the override table keys on anyway.
Category: performance
Confidence: HIGH
Counter-argument: "Directories are small and Lua is fast." True for 20 files, but the cost is linear in entries × pattern-table size on every re-render (every write, refresh, and sort), and the fix is three lines of hoisting.

## MEDIUM: Autocmds executed as positional array entries inside a plugin `opts` table
Location: /Users/zcu/.config/nvim/lua/misc/mini-comment.lua:11-23
Evidence:
```lua
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "c", "cpp", "h", "hpp" },
        callback = function()
          vim.bo.commentstring = "// %s"
        end,
      }),
```
Problem: These two `nvim_create_autocmd` calls run when lazy.nvim requires the spec file during startup spec collection — not when mini.comment loads — and their integer return values become `opts[1]` and `opts[2]`, which are then passed into `mini.comment`'s `setup()`. It works by accident; a reader will reasonably assume the autocmds are gated on the plugin loading, and the stray integers in `opts` are a latent trap if mini.comment ever validates its options.
Fix: Move both autocmds to lua/config/autocmds.lua and leave `opts` containing only `options.custom_commentstring`.
Category: maintainability
Confidence: HIGH
Counter-argument: "It works — runtime-facts.md:23 confirms `formatoptions = jtqnl`." It works today, but the mechanism is invisible and the placement misrepresents the lifecycle; the fix is a pure relocation with identical behavior.

## MEDIUM: Thirteen option lines re-declare LazyVim defaults with identical values
Location: /Users/zcu/.config/nvim/lua/config/options.lua:6,9,55,64,70,73,76,77,87,90,99,105,123,126,129
Evidence:
```lua
vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.nu = true
vim.opt.expandtab = true
```
Problem: LazyVim already sets each of these to the same value (LazyVim/lua/lazyvim/config/options.lua:57-115: relativenumber:88, number:85, expandtab:62, smartindent:99, completeopt:58, wrap:115, linebreak:82, undofile:109, ignorecase:78, termguicolors:107, signcolumn:97, spelllang:101, splitright:104, splitbelow:102). Restating them buries the ~6 lines that are genuine overrides (tabstop 4, shiftwidth 0, scrolloff 3, updatetime 50, cursorline false, sessionoptions without "folds") in noise, and each duplicate silently drifts when LazyVim changes a default. `vim.opt.nu` (:55) is also an alias for `vim.opt.number` already set at :9.
Fix: Delete the identical-value lines and the `nu` alias; keep only the intentional overrides, with a one-line comment on each stating what LazyVim value it replaces.
Category: maintainability
Confidence: HIGH
Counter-argument: "Explicit is better — I want to see my settings." Explicitness that duplicates the framework is indistinguishable from an intentional override, which is precisely what makes the real overrides hard to find.

## MEDIUM: grug-far.lua re-declares LazyVim's spec verbatim, appending a duplicate keymap
Location: /Users/zcu/.config/nvim/lua/search/grug-far.lua:1-22
Evidence:
```lua
  opts = { headerMaxWidth = 80 },
  cmd = "GrugFar",
  keys = {
    { "<leader>sr", function() ... end, mode = { "n", "v" }, desc = "Search and Replace" },
```
Problem: This is byte-identical to LazyVim/lua/lazyvim/plugins/editor.lua:4-25 except `mode = { "n", "v" }` vs `{ "n", "x" }` and `cmd` dropping `"GrugFarWithin"`. lazy.nvim merges `cmd` and `keys` as lists (lazy.nvim/lua/lazy/core/plugin.lua:425,442,447-464), so nothing is replaced — the config appends a second `<leader>sr` entry and re-adds a `cmd` LazyVim already has. The only net effect of 22 lines is switching visual mode to include select mode.
Fix: Reduce the file to `return { "MagicDuck/grug-far.nvim", keys = { { "<leader>sr", mode = { "n", "v" } } } }`, or delete it and accept LazyVim's `x` mode.
Category: maintainability
Confidence: HIGH
Counter-argument: "Copying the upstream spec makes it easy to tweak later." It also makes it impossible to see what was tweaked, and it silently stops tracking upstream fixes to the prefill logic.

## MEDIUM: Prettier formatter lists lack `stop_after_first`, so both formatters run in Node projects
Location: /Users/zcu/.config/nvim/lua/langs/conform.lua:6,9-11,13,16-21
Evidence:
```lua
        javascript = { "prettierd", "prettier" },
        typescript = { "prettierd", "prettier" },
        json = { "prettierd", "prettier" }, -- Added JSON
```
Problem: conform runs every *available* formatter in the list unless `stop_after_first = true` (conform.nvim/README.md:711 "Only run the first available formatter in the list. Defaults to false."; the documented form is README.md:138 `javascript = { "prettierd", "prettier", stop_after_first = true }`). `prettier` is not on PATH (runtime-facts.md:35 `prettier=0`), but conform resolves it via `util.from_node_modules("prettier")` (conform.nvim/lua/conform/formatters/prettier.lua:55), so in any repo with `node_modules/.bin/prettier` both formatters run in sequence on every save — double the format latency. Eleven filetypes repeat the same two-element list by hand.
Fix: Enable `lazyvim.plugins.extras.formatting.prettier` via `:LazyExtras`, which wires 16 filetypes with the correct condition and installs prettier via Mason; or add `stop_after_first = true` to each list.
Category: performance
Confidence: HIGH
Counter-argument: "prettierd always wins because it's listed first." Ordering only decides sequence, not exclusivity — README.md:711 is explicit that the default is to run all available formatters.

## MEDIUM: Three spec files are 100% dead code
Location: /Users/zcu/.config/nvim/lua/search/harpoon2.lua:1-44; /Users/zcu/.config/nvim/lua/ui/scrollbar.lua:1-125; /Users/zcu/.config/nvim/lua/misc/disabled.lua:2-5,12-20
Evidence:
```lua
return {
  {
    -- "ThePrimeagen/harpoon",
```
Problem: 169 lines across two files produce nothing, and lazy.nvim swallows them without warning: `Spec:normalize` takes the `Util.is_list(spec)` branch (lazy.nvim/lua/lazy/core/plugin.lua:96-100) and `is_list({})` returns true with zero iterations (lazy.nvim/lua/lazy/core/util.lua:155-161), so the empty tables recurse over nothing. This is why checkhealth is clean while five docs (runtime-facts.md:52) still describe harpoon as active — the config gives no signal that it was removed.
Fix: Delete harpoon2.lua and scrollbar.lua (git history preserves the commented config; the scrollbar block references a Catppuccin palette that is no longer the active theme anyway) and strip the commented entries from disabled.lua, leaving only the neo-tree entry.
Category: maintainability
Confidence: HIGH
Counter-argument: "It's kept as reference for re-enabling." Git already is that reference, and the scrollbar block cannot be re-enabled as written — `require("catppuccin.palettes")` would fail under lume.

## LOW: Comments that contradict the value they annotate
Location: /Users/zcu/.config/nvim/lua/config/options.lua:5,11,63,95,101; /Users/zcu/.config/nvim/lua/config/keymaps.lua:80
Evidence:
```lua
-- Disable relative line numbers
vim.opt.relativenumber = true
-- Use actual tabs (not spaces)
vim.opt.expandtab = true
```
Problem: options.lua:5 says "Disable relative line numbers" over `= true`; :63 "Use actual tabs" over `expandtab = true`; :95 "Highlight the current line" over `= false`; :101 "Keep 8 lines visible" over `= 3`; :11 blames nvim-cmp when blink.cmp is the engine; keymaps.lua:80 cites nvim-surround when mini.surround is installed. A future reader cannot tell which of the two is the mistake.
Fix: Correct each comment to describe the actual value, or delete the comment where the option name is self-explanatory.
Category: maintainability
Confidence: HIGH
Counter-argument: "Comments are cosmetic." These specifically invert the meaning, which is worse than no comment — a reader "fixing" line 6 to match its comment breaks the intended setting.

## LOW: No-op settings and settings for disabled subsystems
Location: /Users/zcu/.config/nvim/lua/config/options.lua:18,45-52,135; /Users/zcu/.config/nvim/lua/misc/checkmate.lua:7; /Users/zcu/.config/nvim/lua/misc/treesitter-context.lua:3; /Users/zcu/.config/nvim/lua/ui/bufferline.lua:5; /Users/zcu/.config/nvim/lua/misc/flash.lua:3-6
Evidence:
```lua
vim.opt.guicursor = ""          -- overwritten 10 lines later at :28
vim.g.netrw_browse_split = 0    -- netrw disabled at :42-43
vim.diagnostic.enable(true)     -- already the default
    log = {},                   -- deep-merges to nothing
```
Problem: Each line is either immediately overwritten (options.lua:18 by :28, confirmed runtime-facts.md:25), configures a plugin already disabled (netrw settings at :45-52 after `loaded_netrw = 1` at :42), or restates a default: `vim.diagnostic.enable(true)` with no filter (nvim runtime/lua/vim/diagnostic.lua:2465-2492 — enabled is already the state); checkmate `log = {}` merges into `{level="warn", use_file=true}` via `vim.tbl_deep_extend("force", config, opts)` (checkmate.nvim/lua/checkmate/config/init.lua:571) and changes nothing; `enabled = true` is lazy.nvim's default; bufferline `event = "VeryLazy"` and flash's `event`/`vscode`/`opts = {}` duplicate LazyVim (ui.lua:5-9, editor.lua:30-35).
Fix: Delete all of them. Keep only flash's `keys = { { "S", false } }` and bufferline's `keys`/`opts`/`highlights`.
Category: maintainability
Confidence: HIGH
Counter-argument: "Harmless." Individually yes; collectively they teach the reader that lines in this config may or may not do anything, which makes every line cost a verification.

## LOW: Autocmd pattern lists file extensions where filetypes are required
Location: /Users/zcu/.config/nvim/lua/misc/mini-comment.lua:12
Evidence:
```lua
        pattern = { "c", "cpp", "h", "hpp" },
```
Problem: `FileType` autocmd patterns match filetype names. `h` and `hpp` are extensions, never filetypes — Neovim maps `.hpp` to filetype `cpp` (runtime/lua/vim/filetype.lua:347 `hpp = 'cpp'`) and `.h` through `detect.header` (:561), which yields `c` or `cpp`. Both entries are dead; the header files are already covered by `c`/`cpp`.
Fix: Reduce to `pattern = { "c", "cpp" }`.
Category: maintainability
Confidence: HIGH
Counter-argument: "Extra patterns are free insurance." They are misinformation — they imply header files need separate handling when they do not, and the next person adding `objc` will copy the broken pattern.

## LOW: Hardcoded hex colors, several from a colorscheme no longer in use
Location: /Users/zcu/.config/nvim/lua/config/options.lua:21-25; /Users/zcu/.config/nvim/lua/ui/colorscheme.lua:9-10; /Users/zcu/.config/nvim/lua/ui/bufferline.lua:22; /Users/zcu/.config/nvim/lua/misc/checkmate.lua:96-97,101-102,109
Evidence:
```lua
vim.api.nvim_set_hl(0, "NormalCursor", { fg = "#1e1e2e", bg = "#ffffff" })
vim.api.nvim_set_hl(0, "InsertCursor", { fg = "#1e1e2e", bg = "#ffd400" })
```
Problem: `#1e1e2e` (Catppuccin Mocha base) appears 5 times and `#ffd400` 4 times in options.lua while the active theme is lume; `#75d7b3` twice in colorscheme.lua; `#cc6666` and `#f9e2af` twice each in checkmate.lua. Changing the palette means grepping six files, and none of these track the theme's own colors — lume exposes `lua/lume/palette.lua` and a `palette_overrides` option (lume/lua/lume/init.lua:6).
Fix: Define the repeated values as locals at the top of each file (`local BASE = "#1e1e2e"`), or source them from `require("lume.palette")` so they follow the theme.
Category: maintainability
Confidence: MEDIUM
Counter-argument: "Personal config, one user, colors rarely change." They already changed once — the Catppuccin values are residue from the previous theme, which is the incident this finding predicts.

## LOW: Oil `config` mixes three concerns and re-requires a module bound to a local
Location: /Users/zcu/.config/nvim/lua/ui/oil.lua:11-177,106,122
Evidence:
```lua
      local oil = require("oil")
              local dir = require("oil").get_current_dir()
```
Problem: One 167-line `config` function registers a custom column, calls `setup()` with a 12-key table containing five inline callbacks, and registers a buffer-cleanup autocmd with a helper. Lines 106 and 122 call `require("oil")` although `oil` is already bound at :12 and used that way at :83.
Fix: Split into `local function register_filetype_column()`, `local function setup_delete_cleanup()`, and the `setup()` call; replace the two `require("oil")` calls with `oil`.
Category: maintainability
Confidence: HIGH
Counter-argument: "It's a config file, not a library." At 179 lines it is the largest file in the config and the one most likely to be edited under time pressure; the split is mechanical.

## LOW: Buffer-cleanup autocmd re-canonicalizes every buffer for every deleted file
Location: /Users/zcu/.config/nvim/lua/ui/oil.lua:160-171
Evidence:
```lua
                for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
                  local name = vim.api.nvim_buf_get_name(bufnr)
                  if name ~= "" and not vim.bo[bufnr].modified and canonical_path(name) == target then
```
Problem: For D deleted files and B buffers this is D×B iterations, each calling `canonical_path` (oil.lua:140-150) which issues a `vim.uv.fs_realpath` syscall on the buffer's parent directory. Deleting a 50-file directory with 30 buffers open is 1500 realpath syscalls, all recomputing the same handful of directories.
Fix: Build the canonical name list once before the `args.data.actions` loop, or memoize `fs_realpath` results by directory in a table local to the callback.
Category: performance
Confidence: MEDIUM
Counter-argument: "Bulk delete from Oil is rare and buffer counts are small." Strong — this is why the finding is LOW. It still stands because hoisting the buffer scan out of the action loop is a two-line change with no behavior risk.

## LOW: User plugins load eagerly at startup with no trigger declared
Location: /Users/zcu/.config/nvim/lua/search/arrow.lua:1-11; /Users/zcu/.config/nvim/lua/misc/multicursor.lua:1-73; /Users/zcu/.config/nvim/lua/misc/treesitter-context.lua:1-9
Evidence:
```lua
  "otavioschwanck/arrow.nvim",
  opts = { show_icons = true, leader_key = ';', buffer_leader_key = 'm' },
```
Problem: With `defaults.lazy = false` (lua/config/lazy.lua:33), any user spec without `event`/`ft`/`keys`/`cmd` loads during startup. arrow, multicursor, and treesitter-context all qualify. arrow's only entry points are `;` and `m`; multicursor's `config` does nothing but register keymaps under `<leader>z` and `<C-q>`; treesitter-context only matters once a real file is open.
Fix: `keys = { ";", "m" }` on arrow, `keys = { "<leader>z", "<c-q>", "<c-leftmouse>" }` on multicursor, `event = "LazyFile"` on treesitter-context.
Category: performance
Confidence: MEDIUM
Counter-argument: "Startup is already 46 ms." Correct, and I have no per-plugin timings for these three (runtime-facts.md gives numbers only for LuaSnip and tokyonight), which is why this is LOW. Note oil is deliberately excluded — it needs eager loading to handle `nvim <dir>` and the netrw hijack.

## LOW: tokyonight is loaded and applied at startup, then immediately replaced by lume
Location: /Users/zcu/.config/nvim/lua/ui/colorscheme.lua:1-13
Evidence:
```lua
    "danfry1/lume",
    lazy = false,
    priority = 1000,
```
Problem: LazyVim's default `colorscheme` option is `function() require("tokyonight").load() end` (LazyVim/lua/lazyvim/config/init.lua:13-15) and it is applied during LazyVim setup at priority 10000 (:250-256), before lume's priority-1000 config runs — so tokyonight fully loads and paints (~1.1 ms, runtime-facts.md:29) for nothing.
Fix: Add `{ "LazyVim/LazyVim", opts = { colorscheme = "lume" } }` and set lume to `lazy = true`; lazy.nvim resolves the on-demand load by scanning `plugin.dir .. "/colors/lume.lua"` (lazy.nvim/lua/lazy/core/loader.lua:515-524), and lume ships that file. The two `nvim_set_hl` calls must move to a `ColorScheme` autocmd — lume's `setup` exposes only `palette_overrides`, no highlight hook (lume/lua/lume/init.lua:6,12).
Category: performance
Confidence: MEDIUM
Counter-argument: "1.1 ms is not worth the restructuring risk, and the config function would need rewriting." Fair — hence LOW. It stands because loading a colorscheme you never see is also a maintainability signal: nothing in this config says tokyonight is still active.

## LOW: fzf-lua spec mutates a library-internal defaults table in place
Location: /Users/zcu/.config/nvim/lua/search/fzf.lua:34-39,56
Evidence:
```lua
    local files = require("fzf-lua.config").defaults.actions.files
    files["ctrl-o"] = files["alt-i"] -- toggle .gitignore
    files["alt-i"], files["alt-h"], files["alt-q"], files["alt-f"] = nil, nil, nil, nil
```
Problem: The `opts` function reaches into `fzf-lua.config`'s `defaults` table and rewrites it, rather than expressing the change through the returned `opts`. The mutation is global and order-dependent — anything that reads `defaults.actions.files` before this runs sees the Alt keys, anything after sees Ctrl. Line 56 similarly concatenates onto `defaults.grep.rg_opts`, which breaks if the `opts` function is ever invoked twice.
Fix: Set `opts.actions.files` explicitly instead of mutating `defaults`, and capture the original `rg_opts` in a file-local so the concatenation at :56 is idempotent.
Category: maintainability
Confidence: MEDIUM
Counter-argument: "This is the idiom fzf-lua users reach for, and the comments at :30-33 explain why." Strong on the idiom, which is why this is LOW — but the non-idempotent `rg_opts` concatenation at :56 is a real hazard independent of style.

## LOW: Keymap definition style is inconsistent across the file
Location: /Users/zcu/.config/nvim/lua/config/keymaps.lua:17,46-47,50,58,64,72,106
Evidence:
```lua
keymap.set("n", "<Leader>o", ":Oil<Return>", opts)
  [[:lua require('grug-far').open({ prefills = { paths = vim.fn.expand("%"), flags = '-F -i' } })<CR>]],
```
Problem: Three styles coexist for the same job: `":Cmd<Return>"`, `"<Cmd>...<CR>"` (used in ui/bufferline.lua:7-9), and Lua functions. `:...<Return>` leaves the command in the `:` history and does not reset a pending count; the `<leader>r` mapping at :72 embeds Lua inside a `:lua` string with nested quote levels, which no linter or LSP will check. Nine of thirteen mappings also omit `desc`, so which-key shows them unlabeled.
Fix: Use `"<cmd>Oil<cr>"` for command mappings, convert the `<leader>r` string to a function body, and add `desc` to the mappings that lack it.
Category: maintainability
Confidence: HIGH
Counter-argument: "The mappings work as written." They do; the cost is that the file teaches three conventions, and the `:lua` string at :72 is unmaintainable relative to the equivalent function.

## LOW: Five files fail the repo's own formatter
Location: /Users/zcu/.config/nvim/lua/misc/treesitter-context.lua; /Users/zcu/.config/nvim/lua/search/arrow.lua; /Users/zcu/.config/nvim/lua/config/keymaps.lua; /Users/zcu/.config/nvim/lua/config/autocmds.lua; /Users/zcu/.config/nvim/lua/ui/oil.lua
Evidence:
```lua
    leader_key = ';',                    -- arrow.lua:8, single quotes
    max_lines = 3,       -- treesitter-context.lua:5, aligned comments
```
Problem: `stylua --check .` reports these five as unformatted (runtime-facts.md:9) against the repo's own stylua.toml. The divergences are single-quoted strings, comment alignment padding, and missing trailing commas — exactly the churn that pollutes future diffs when someone finally runs the formatter.
Fix: Run `~/.local/share/nvim/mason/bin/stylua .` from the config root as a standalone commit, so the formatting change never mixes with a behavioral one.
Category: maintainability
Confidence: HIGH
Counter-argument: "Formatting is not worth a commit." It is precisely worth its own commit — deferring it guarantees the reformat lands inside an unrelated change where it hides the real diff.

## LOW: Tracked files and directories that nothing in the config reads
Location: /Users/zcu/.config/nvim/.neoconf.json:1-15; /Users/zcu/.config/nvim/KEYMAPS.md; /Users/zcu/.config/nvim/README.md; /Users/zcu/.config/nvim/docs/2026-02-26-*.md through docs/2026-03-01-*.md
Evidence:
```json
  "neoconf": { "plugins": { "lua_ls": { "enabled": true } } }
```
Problem: `.neoconf.json` configures neoconf.nvim, which is not installed (runtime-facts.md:56) — the file is inert. Root `KEYMAPS.md` and `docs/specs/keymaps.md` both document keymaps and diverge by 362 lines (runtime-facts.md:55), so every keymap change needs two edits and one will be missed. `README.md` is unmodified LazyVim starter boilerplate. Five dated docs sit at `docs/` root outside `docs/investigations/` without frontmatter. Empty `ref/` and `.tests/` directories exist at root.
Fix: Delete `.neoconf.json`, `KEYMAPS.md` (keep `docs/specs/keymaps.md` as the single source), and the empty directories; rewrite `README.md` to describe this config; move the five dated docs into `docs/investigations/` with frontmatter.
Category: maintainability
Confidence: HIGH
Counter-argument: "Docs drift is the docs reviewer's problem." The duplicated keymap file is a maintenance-cost finding, not an accuracy one — two files that must be edited together is the structural defect, independent of whether either is currently correct.
