---
title: Challenger F verdicts (L1, L2, L5, L6)
created: 2026-09-06
updated: 2026-09-06
status: final
topics:
  - code-review
  - nvim-config
---

## L1: CONFIRMED
Original: Dead files (harpoon2.lua, scrollbar.lua) and a neo-tree disable that disables nothing.
Verdict: CONFIRMED (LOW)

### Evidence
`lazy.nvim/lua/lazy/core/util.lua:155-165` — `is_list` iterates `pairs(t)`; for `{}` the loop body never runs, so it returns `true`.
`lazy.nvim/lua/lazy/core/plugin.lua:96-99`:
```lua
  elseif #spec > 1 or Util.is_list(spec) then
    for _, s in ipairs(spec) do
      self:normalize(s)
```
So `{}` (scrollbar.lua:1) and `{ {} }` (harpoon2.lua:1-2,43-44) take the list branch and iterate zero times — the `self:error("Invalid plugin spec")` at :113 is never reached.
Neo-tree reachability: `LazyVim/lua/lazyvim/plugins/xtras.lua:54-59` imports a default extra only `if extra.enabled`. `config/init.lua:437-440` puts `editor.neo-tree` in the `explorer` group behind `editor.snacks_explorer`; `:444-447` reorders only when `install_version < 8`, and `/Users/zcu/.config/nvim/lazyvim.json:19` is `"install_version": 8`. `config/init.lua:367-368,392` — `vim.g.lazyvim_explorer` is unset (grep for `lazyvim_explorer` across all of `LazyVim/lua/` and the user config returned no match), so `use = valid[1]` = `"snacks"`, and `:397` sets `extra.enabled = false` for neo-tree.
`lazy/core/meta.lua:258-262` — `M:disable` sets `kind = "disabled"`, `self:del(plugin.name)`, so `update_state` (plugin.lua:233-253) never sees it; neo-tree is absent from lazy-lock.json.

### Reasoning
Both empty-spec files are silently accepted — no error, no cost beyond one `loadfile` each. The draft's neo-tree conclusion is right but its stated reason ("not in lazyvim.json") is incomplete: LazyVim v16 can auto-enable neo-tree through the `explorer` default group without any lazyvim.json entry. It does not here only because `install_version` is 8, which makes snacks_explorer the group default — and by the same logic (xtras.lua:54-59, init.lua:397) `editor.snacks_explorer` IS auto-imported even though it appears nowhere in lazyvim.json, which the parent should know. The disable entry moves the plugin to `spec.disabled` (meta.lua:261) and it never reaches `update_state`, so nothing is cloned.

### Fix Assessment
Deleting harpoon2.lua and scrollbar.lua is runtime-safe: `Spec:import` errors only when a module directory yields zero modspecs (plugin.lua:209-211), and `search/` and `ui/` both retain other files. Fix is INCOMPLETE as written: five doc locations still describe harpoon as active (runtime-facts:52) and CLAUDE.md/docs/specs/plugins.md/architecture.md describe both the neo-tree disable and scrollbar.lua. Deleting the files without those edits deepens existing doc drift. For disabled.lua, prefer annotating over deleting: if `vim.g.lazyvim_explorer = "neo-tree"` is ever set, or `install_version` regresses below 8, the entry becomes load-bearing again.

Counter-argument: one could call the neo-tree entry harmless insurance rather than a finding. It still stands as a finding because CLAUDE.md presents it as the reason neo-tree is absent, which is false — snacks_explorer being the v8 default is the reason. A stale explanation in a config's own documentation is the defect, not the two-line spec.

## L2: CONFIRMED
Original: Commented-out code blocks across 8 files should be deleted.
Verdict: CONFIRMED (LOW), fix corrected

### Evidence
Verified commented-out CODE at every cited range: keymaps.lua:16 (`-- keymap.set("n", "ss", ...)`), :77-78, :98-103; options.lua:117 (`-- vim.opt.colorcolumn = "120"`); conform.lua:15; oil.lua:54; bufferline.lua:13; multicursor.lua:11-16, :47-48 and :51; checkmate.lua:77-78; disabled.lua:3-4, :12-20.
Two cited ranges are not purely code:
`checkmate.lua:76-78` —
```lua
      -- Built-in states (cannot change markdown or type)
      -- unchecked = { marker = "□" },
      -- checked = { marker = "✔" },
```
`options.lua:116-117` — the header says "Highlight column 80" while the code says `"120"`.

### Reasoning
Every range is dead commented code with no runtime effect; git history preserves it. But blanket deletion orphans header comments that describe only the deleted lines: keymaps.lua:76, options.lua:116, multicursor.lua:10, :46, :50. checkmate.lua:76-78 is documentation — it records the built-in state markers and the constraint that they cannot be re-mapped, which is not otherwise visible in this file.

### Fix Assessment
Correct with three amendments: (1) delete each header comment with its block (keymaps.lua:76-78, options.lua:116-117, multicursor.lua:10-16, :46-48, :50-51); (2) keep keymaps.lua:15 — it heads the live `sv` mapping on :17, so deleting :16 alone is right; (3) keep checkmate.lua:76-78, or rewrite as prose ("built-in states: unchecked □, checked ✔ — markdown/type fixed"). disabled.lua:3-4 and :12-20 overlap L1; if L1's delete-the-file fix is taken, L1 supersedes and these lines need no separate action.

Counter-argument: the commented blocks are a personal scratchpad and deleting them costs the user muscle memory for toggling options back on. It still stands because every block is recoverable from git, and the options.lua:116-117 mismatch shows stale comments actively misinform.

## L5: DOWNGRADED to INFORMATIONAL (unquantified)
Original: arrow, multicursor, treesitter-context load eagerly at startup; add `keys`/`event`.
Verdict: DOWNGRADED to INFORMATIONAL

### Evidence
`lua/config/lazy.lua:33` sets `defaults.lazy = false`; none of lua/search/arrow.lua:1-11, lua/misc/multicursor.lua:1-73, lua/misc/treesitter-context.lua:1-9 declares `event`/`ft`/`keys`/`cmd`, so `plugin.lua:235-242` resolves `plugin.lazy = false` for all three — eager loading is a fact.
No timing evidence exists: runtime-facts:7 records only "Headless startup to NVIM STARTED: 46 ms" with no per-plugin self-times for these three (contrast the explicit "~7.8 ms" for LuaSnip and "~1.1 ms" for tokyonight at runtime-facts:29-30).
`multicursor.nvim/lua/multicursor-nvim/core.lua:61-73`:
```lua
    if vim.fn.mapcheck(TERM_CODES.CTRL_I) == ""
        and vim.fn.mapcheck(TERM_CODES.CTRL_O) == ""
    then
        vim.keymap.set("n", TERM_CODES.CTRL_I, core.jumpForward)
```
`arrow.nvim/lua/arrow/init.lua:93-95` sets the `;` map inside `setup`; `:208-213` registers a `User LazyLoad` autocmd that re-runs `buffer_persist.load_buffer_bookmarks()`; `lazy/core/loader.lua:361-368` runs `M.config(plugin)` and only then schedules `User LazyLoad`.
`LazyVim/lua/lazyvim/plugins/extras/ui/treesitter-context.lua:4` — `event = "LazyFile"`; the event is registered at `LazyVim/lua/lazyvim/util/plugin.lua:87`.

### Reasoning
"Eager" is verified; "perf problem" is not. Total startup is 46 ms with no attribution, so the finding cannot quantify what lazy-loading would save — it must be reported as a hygiene/consistency item, not a measured cost. The arrow fix is mechanically sound: lazy's placeholder deletes itself and re-feeds the key (`handler/keys.lua:125-140`), `setup` installs the real `;`/`m` maps synchronously first, and arrow's own LazyLoad hook restores per-buffer bookmark rendering after config. The multicursor fix is the risky one.

### Fix Assessment
treesitter-context `event = "LazyFile"`: correct, matches LazyVim's own extra verbatim.
arrow `keys = { ";", "m" }`: correct. One residual regression to document — `init.lua:200-206` renders per-buffer bookmarks on `BufReadPost`, and the LazyLoad hook calls `buffer_persist.load_buffer_bookmarks()` with no argument; that function takes a single `bufnr` and resolves its path with `vim.fn.expand("%:p")` (buffer_persist.lua:61-75), so it restores marks for the current buffer only. Buffers opened before the first `;`/`m` press and not current at load time keep their marks hidden until re-read.
multicursor `keys = {...}`: DO NOT ship as written. Three defects: (a) core.lua:61-73 installs `<C-i>`/`<C-o>` and insert-mode `<left>`/`<right>` only if unmapped *at setup time* — deferring setup moves that check to an arbitrary mid-session moment where a LazyFile-loaded plugin may have claimed them, silently changing which mappings exist; (b) `<c-leftmouse>` as a lazy key re-feeds the keycode via `nvim_feedkeys` without click coordinates — unverifiable here, flag as risk; (c) `<leader>z` is a bare prefix, unlike the LazyVim `keys` entries seen in this session (bufferline, runtime-facts:42), which are full sequences. Use `event = "VeryLazy"` instead — the same pattern LazyVim uses for bufferline (runtime-facts:42) — which moves it off startup with no placeholder semantics.

Counter-argument: 46 ms is already fast, so this could be dismissed outright. It survives as informational because the config is internally inconsistent — bufferline.lua:5 already sets `event = "VeryLazy"` — and because the multicursor fix as drafted would introduce a real mapping-order bug that a reader might apply unexamined.

## L6: DOWNGRADED to THOUGHT
Original: Duplicated hex literals; `#1e1e2e`/`#ffd400` are Catppuccin residue; use locals or the lume palette.
Verdict: DOWNGRADED to THOUGHT (non-finding), claim partly false

### Evidence
`catppuccin/lua/catppuccin/palettes/mocha.lua:9` `yellow = "#f9e2af"`, `:25` `base = "#1e1e2e"` — both user values confirmed Catppuccin Mocha.
A grep for `ffd400|FCF596|75d7b3|96de7a|cc6666` across `catppuccin/lua/catppuccin/palettes/` returned **no matches** — `#ffd400` is not a Catppuccin color, contradicting half the claim.
`lume/lua/lume/palette.lua:9` `base = "#12101e"` — lume's background is not `#1e1e2e`.
`lume/lua/lume/theme.lua:28` `local p = vim.deepcopy(require("lume.palette"))` — the palette module is internal plumbing; `lume/README.md:145-167` documents `palette_overrides` and `custom_highlights(colors, variant)` as the public surface, not `require("lume.palette")`.
Ordering: `LazyVim/lua/lazyvim/config/init.lua:329-332` — `-- load options here, before lazy init while sourcing plugin modules` / `M.load("options")` inside `M.init()`; `M.load` sources `lazyvim.config.options` then the user's `config.options` (`:286-306`). So options.lua runs before any plugin, lume included.

### Reasoning
The duplication is 3-5 literals per file in a single-user config with no shared consumer — extracting locals adds indirection without removing a defect. The "Catppuccin residue" framing is half wrong (`#ffd400` is the user's own yellow) and the surviving half is cosmetic: `#1e1e2e` is only ever a cursor *foreground* under a `#ffffff`/`#ffd400` block, where its 12-16 per channel difference from lume's `#12101e` is imperceptible.

### Fix Assessment
Partly inapplicable as written. options.lua runs before plugins load, so `require("lume.palette")` is unavailable there — options.lua:21-25 cannot use a lume palette at all. Only colorscheme.lua:9-10 is movable, and the correct target is the documented `custom_highlights` callback (README:149), not the internal palette module. If anything is done, restrict it to folding colorscheme.lua:9-10 into `require("lume").setup({ custom_highlights = ... })`. SEPARATE LEAD (higher value than L6 itself, needs one runtime check): options.lua:21-25 may be dead. Chain read this session — options.lua runs during `LazyVim.config.init()` (init.lua:329-332) and defines the user groups `NormalCursor`/`InsertCursor`/`VisualCursor`/`ReplaceCursor`/`CommandCursor`; later colorscheme.lua:8 runs `vim.cmd("colorscheme lume")`; `lume/colors/lume.lua:1` is `require("lume").load()`; `lume/lua/lume/init.lua:17-19` is `if vim.g.colors_name then vim.cmd("hi clear") end`, and `vim.g.colors_name` is already set because tokyonight loaded first (runtime-facts:29). Neovim 0.11.4 `runtime/doc/syntax.txt:4880-4881`: `:hi[ghlight] clear  Reset all highlighting to the defaults.  Removes all highlighting for groups added by the user.` A grep of `/Users/zcu/.config/nvim/lua` for `ColorScheme|NormalCursor` found the definitions at options.lua:21-22 and no autocmd re-applying them. Not asserted as a bug — I cannot run nvim. Exact check for the main session: start nvim and run `:hi NormalCursor`; `xxx cleared` means the cursor colors CLAUDE.md documents are not in effect and the fix is to move lines 21-25 into a `ColorScheme` autocmd or into colorscheme.lua's `config` after `vim.cmd("colorscheme lume")`.

Counter-argument: `#1e1e2e` genuinely is a leftover from a colorscheme this config no longer uses, so "residue" is defensible. It still downgrades because a finding must name a consequence, and here the consequence is an imperceptible cursor-glyph tint — while the fix as drafted cites a module the affected file cannot even load.
