---
title: Baseline Audit — full-file review of nvim config
created: 2026-09-06
updated: 2026-09-06
status: draft
topics:
  - nvim-config
  - baseline-audit
---

# Baseline Audit

Line numbers are **in-file** line numbers (the second column of `config-bundle.txt`), not bundle offsets.

## Function Inventory

| # | File | Function | Lines | Purpose |
|-|-|-|-|-|
| 1 | lua/config/keymaps.lua | `<leader>yp` callback | 92-94 | setreg `+` = `%:.` |
| 2 | lua/config/keymaps.lua | `<leader>yP` callback | 95-97 | setreg `+` = `%:~` |
| 3 | lua/config/autocmds.lua | FileType md/text `callback` | 12-16 | opt_local spell/conceallevel/wrap |
| 4 | lua/config/autocmds.lua | FileType c/cpp `callback` | 22-33 | installs buffer-local `*` imap |
| 5 | lua/config/autocmds.lua | insert-`*` closure (nested in #4) | 24-32 | auto-close `/*  */` |
| 6 | lua/langs/luasnip.lua | `config` | 6-10 | two `from_vscode.lazy_load` calls |
| 7 | lua/search/fzf.lua | `<leader>/` rhs | 6-8 | `LazyVim.pick("live_grep",{root=false})()` |
| 8 | lua/search/fzf.lua | `` <leader>` `` rhs | 13-18 | fzf `live_grep` with `--fixed-strings` |
| 9 | lua/search/fzf.lua | `<leader><space>` rhs | 23-25 | fzf `files{cwd=getcwd()}` |
| 10 | lua/search/fzf.lua | `opts(_, opts)` | 29-68 | Alt→Ctrl action remap, no_ignore/hidden, winopts |
| 11 | lua/search/grug-far.lua | `<leader>sr` rhs | 8-17 | grug open, `filesFilter = "*."..ext` |
| 12 | lua/ui/colorscheme.lua | `config` | 6-11 | lume setup + `:colorscheme` + Comment hl |
| 13 | lua/ui/oil.lua | `config` | 11-177 | whole oil wiring |
| 14 | lua/ui/oil.lua | filetype col `render(entry)` | 16-43 | dir/link/`vim.filetype.match` + overrides |
| 15 | lua/ui/oil.lua | filetype col `parse(line)` | 44-46 | `^(%S+)%s+(.*)$` |
| 16 | lua/ui/oil.lua | `<C-s>` callback | 66-68 | `vim.cmd("write")` |
| 17 | lua/ui/oil.lua | `gs` callback | 81-98 | grug-far "explorer" instance |
| 18 | lua/ui/oil.lua | `<leader>fo` callback | 105-115 | `jobstart{"open", dir}` |
| 19 | lua/ui/oil.lua | `gy` callback | 121-131 | setreg `+` = oil dir |
| 20 | lua/ui/oil.lua | `local function canonical_path(p)` | 140-150 | realpath parent + basename |
| 21 | lua/ui/oil.lua | OilActionsPost `callback(args)` | 154-175 | wipe buffers for deleted files |
| 22 | lua/misc/checkmate.lua | `get_value` | 110-112 | `os.date("%m/%d/%y")` |
| 23 | lua/misc/checkmate.lua | `on_add(todo)` | 114-116 | set state checked |
| 24 | lua/misc/checkmate.lua | `on_remove(todo)` | 117-119 | set state unchecked |
| 25 | lua/misc/gitsigns.lua | `opts(_, opts)` | 4-15 | wraps `on_attach` |
| 26 | lua/misc/gitsigns.lua | `opts.on_attach(bufnr)` (nested) | 6-14 | returns false for markdown |
| 27 | lua/misc/mini-comment.lua | `custom_commentstring` | 7-9 | returns `vim.bo.commentstring` |
| 28 | lua/misc/mini-comment.lua | FileType c/cpp/h/hpp callback | 13-16 | `vim.bo.commentstring = "// %s"` |
| 29 | lua/misc/mini-comment.lua | BufEnter callback | 19-21 | `vim.opt.formatoptions:remove{c,r,o}` |
| 30 | lua/misc/multicursor.lua | `config` | 4-72 | mc setup, keymaps, highlights |
| 31 | lua/misc/multicursor.lua | `<leader>zn` rhs | 19-21 | `matchAddCursor(1)` |
| 32 | lua/misc/multicursor.lua | `<leader>zs` rhs | 22-24 | `matchSkipCursor(1)` |
| 33 | lua/misc/multicursor.lua | `<leader>zN` rhs | 25-27 | `matchAddCursor(-1)` |
| 34 | lua/misc/multicursor.lua | `<leader>zS` rhs | 28-30 | `matchSkipCursor(-1)` |
| 35 | lua/misc/multicursor.lua | `addKeymapLayer(layerSet)` | 45-61 | layer definition |
| 36 | lua/misc/multicursor.lua | layer `<esc>` rhs (nested in #35) | 54-60 | enable-or-clear cursors |

`mc.restoreCursors`, `mc.handleMouse`, `mc.handleMouseDrag`, `mc.handleMouseRelease`, `mc.toggleCursor` are function *references*, not definitions — excluded. Commented-out functions (harpoon2.lua, scrollbar.lua, multicursor.lua:11-16) excluded.

**Total functions: 36 across 11 files.**

---

## Consistency Findings

## HIGH: Cursor highlight groups are wiped by the colorscheme before they are ever visible
Functions/sites compared: options.lua:21-25 vs colorscheme.lua:6-11
Evidence A: `lua/config/options.lua:21-25` — `vim.api.nvim_set_hl(0, "NormalCursor"/"InsertCursor"/"VisualCursor"/"ReplaceCursor"/"CommandCursor", {...})`, then `:28-39` references those groups from `guicursor`. `options.lua` is loaded by LazyVim **before** plugins.
Evidence B: `lua/ui/colorscheme.lua:8` runs `vim.cmd("colorscheme lume")`. `~/.local/share/nvim/lazy/lume/colors/lume.lua:1` is `require("lume").load()`, and `~/.local/share/nvim/lazy/lume/lua/lume/init.lua:16-19`:
```lua
function M.load()
  if vim.g.colors_name then
    vim.cmd("hi clear")
  end
```
`vim.g.colors_name` IS set at that point — runtime facts confirm tokyonight loads first (LazyVim `config/init.lua:250-256`, priority 10000, before lume's 1000). `:h :highlight-clear` removes user-added groups.
Problem: all five cursor highlight groups are cleared after `guicursor` is set. `guicursor` still names them (runtime facts confirm the *option string* survives), but the groups have no attributes, so insert/replace mode gets the terminal's default cursor color, not `#ffd400`. Contrast with `colorscheme.lua:9-10`, which re-applies `Comment`/`@comment` **after** `:colorscheme` — the author already knows this ordering rule and applied it in one file but not the other.
Related: `colorscheme.lua:9-10` and `multicursor.lua:65-71` survive *startup* only because lume's `priority = 1000` beats multicursor's default 50 — any later `:colorscheme` call clears all three sets. No file in the config registers a `ColorScheme` autocmd.
Fix: move lines 21-25 into `colorscheme.lua`'s `config` after line 8, or register all three sets on a `ColorScheme` autocmd so they survive `:colorscheme` reloads.
Confidence: HIGH
Counter-argument: `hi clear` could conceivably preserve non-default groups. It does not — `:h :highlight-clear` states it removes user-added groups. Runtime facts verified `guicursor`, not `nvim_get_hl(0,{name="InsertCursor"})`, so the main session should confirm with that one call; the ordering argument stands regardless.

## HIGH: `n`/`N` remapped in normal mode only, leaving visual/operator-pending on LazyVim's semantics
Functions/sites compared: keymaps.lua:38-39 vs LazyVim keymaps.lua:68-73
Evidence A: `lua/config/keymaps.lua:38-39` — `keymap.set("n", "n", "nzz", opts)` / `keymap.set("n", "N", "Nzz", opts)`. Mode list is `"n"` only.
Evidence B: `~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/config/keymaps.lua:68-73` maps `n`/`N` in **three** modes (`n`, `x`, `o`) to `'Nn'[v:searchforward]` — direction-consistent search, plus `.'zv'` (open folds) in normal mode.
Problem: after the override, normal-mode `n` always searches forward and `N` always backward; visual and operator-pending `n`/`N` still flip direction based on `v:searchforward`. After a `?` (backward) search, pressing `n` then `vn` moves in opposite directions from the same key. The `zv` fold-open is also silently dropped, so `n` can land the cursor inside a closed fold.
Fix: `keymap.set({"n","x","o"}, "n", "nzz")` (or `nzzzv`) and the same for `N`; or drop the override and use `map("n","n","'Nn'[v:searchforward].'zzzv'")`.
Confidence: HIGH
Counter-argument: the author may only care about normal mode. But the *inconsistency* is invisible and non-obvious — a senior reviewer would still ask why `x`/`o` were left behind, since the override reason (recentering) applies equally.

## MEDIUM: Two autocmds live as positional entries inside a plugin `opts` table
Functions/sites compared: lua/misc/mini-comment.lua:11-23 vs lua/config/autocmds.lua:10-33
Evidence A: `lua/config/autocmds.lua:10-33` — autocmds at top level of the designated file, using `vim.opt_local` (`:13-15`).
Evidence B: `lua/misc/mini-comment.lua:11` and `:18` — `vim.api.nvim_create_autocmd(...)` calls sit as array elements *inside* the `opts` table constructor. Three consequences, all verified:
1. They execute when `lua/misc/mini-comment.lua` is `require`d, i.e. at `lazy.setup()` spec-parse time at startup — **not** on `VeryLazy` (`:4`), and whether or not mini.comment ever loads.
2. `nvim_create_autocmd` returns an integer id, so `opts` becomes `{ options = {...}, [1] = <id>, [2] = <id> }`. `lazy/core/util.lua:440-442` `can_merge` returns true for that table (it is not a list), so both integers survive the merge and are passed to `require("mini.comment").setup()` as junk keys.
3. `:20` uses `vim.opt` (global) where the sibling file uses `vim.opt_local`. Runtime facts confirm the effect: `formatoptions = "jtqnl"` globally — `c`, `r`, `o` are stripped for **every** buffer forever, so no filetype can ever get comment continuation, and the `BufEnter` autocmd re-does the same global mutation on every buffer switch.
Neither autocmd has an `augroup`, so `:source` of the file duplicates them. Same for the two in `autocmds.lua` and the one in `oil.lua:152`.
Fix: move both autocmds to `lua/config/autocmds.lua` per CLAUDE.md, wrap in `nvim_create_augroup(..., {clear=true})`, and use `vim.opt_local.formatoptions` if per-buffer behaviour is intended.
Confidence: HIGH
Counter-argument: it works today, and global `formatoptions` may be exactly what the author wants. Fine — but item 1 (parse-time, not VeryLazy) and item 2 (integer ids in `setup()` opts) are unintended in any reading, and CLAUDE.md explicitly designates `autocmds.lua` as the home.

## MEDIUM: `pattern = { "h", "hpp" }` never matches
Functions/sites compared: mini-comment.lua:12 vs autocmds.lua:21
Evidence A: `lua/config/autocmds.lua:21` — `pattern = { "c", "cpp" }` (correct: FileType patterns are filetypes).
Evidence B: `lua/misc/mini-comment.lua:12` — `pattern = { "c", "cpp", "h", "hpp" }`. Neovim assigns filetype `c` to `.h` and `cpp` to `.hpp`; there is no `h` or `hpp` filetype.
Problem: dead pattern entries. Harmless today only because `c`/`cpp` already cover the files, which is what makes it misleading — a maintainer will copy the idiom.
Fix: drop `"h"`, `"hpp"`.
Confidence: HIGH
Counter-argument: zero runtime cost. It still stands as a correctness/clarity defect in a two-element list.

## MEDIUM: `sv` makes every flash `s` jump wait 300 ms
Functions/sites compared: keymaps.lua:17 vs flash.lua:8-10
Evidence A: `lua/config/keymaps.lua:17` — `keymap.set("n", "sv", ":vsplit<Return>", opts)`.
Evidence B: `lua/misc/flash.lua:8-10` disables only `S` (`{"S", false}`); `s` remains LazyVim's flash jump. Runtime facts confirm both `s` and `sv` are mapped in normal mode with `timeoutlen = 300`.
Problem: `s` is a strict prefix of `sv`, so Neovim waits the full `timeoutlen` after every `s` before starting flash. On the hottest motion key in the config this is a constant 300 ms stall.
Fix: rebind the vertical split to a non-`s` prefix, or accept and document the delay.
Confidence: HIGH
Counter-argument: 300 ms is tolerable, and the same class of collision is inherent to any two-key map. It still stands because `s` is a single-key motion used constantly, and the cost is paid on every use of the *unrelated* key.

## MEDIUM: `<leader>cp` means two different things depending on filetype
Functions/sites compared: keymaps.lua:106 vs LazyVim markdown extra
Evidence A: `lua/config/keymaps.lua:106` — global `<leader>cp` → `:LspStop`, desc "Disable LSP".
Evidence B: `~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/lang/markdown.lua:82-89` — `{ "<leader>cp", ft = "markdown", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown Preview" }`. `lazy.nvim/lua/lazy/core/handler/keys.lua:151-163` shows `keys.ft` creates a **buffer-local** mapping on `FileType`, and buffer-local wins over global.
Problem: in markdown buffers `<leader>cp` toggles the browser preview; everywhere else it stops the LSP. Neither which-key entry mentions the other. `docs/specs/keymaps.md` documents only the `:LspStop` meaning. Also note `options.lua:141` `vim.g.mkdp_auto_close = 0` is *not* dead — markdown-preview is installed (runtime facts) and this is its only consumer.
Fix: move `:LspStop` to a free key (e.g. `<leader>cL`), or add `ft` scoping.
Confidence: HIGH
Counter-argument: the author may never use markdown preview. Then the collision is invisible until they try — which is the worst failure mode for a keymap.

## MEDIUM: Oil disables keys with `"<Nop>"` instead of `false`, shadowing a global window-navigation map
Functions/sites compared: oil.lua:73-74 vs flash.lua:9
Evidence A: `lua/misc/flash.lua:9` — `{"S", false}`. `lazy/core/handler/keys.lua:82-86`: `if keys.rhs == vim.NIL or keys.rhs == false then values[keys.id] = nil` — the mapping is genuinely removed.
Evidence B: `lua/ui/oil.lua:73-74` — `["<C-h>"] = "<Nop>"`, `["<C-t>"] = "<Nop>"`. `oil.nvim/lua/oil/keymap_util.lua:67-73`: `local rhs, opts, mode = resolve(v); if rhs then vim.keymap.set(mode or "", k, rhs, ...)`. `resolve` (`:11-62`) returns the string unchanged for anything not prefixed `actions.` (`:61`), so `"<Nop>"` is truthy and a buffer-local map is **created** in modes `n`/`v`/`o`/`s` (mode `""`).
Problem: `~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/config/keymaps.lua:14` maps `<C-h>` → `<C-w>h` (Go to Left Window). Inside an oil buffer the `<Nop>` shadows it, so the user cannot move to the left window from oil. Passing `false` would make `if rhs then` skip the `vim.keymap.set` entirely and let the global map through — that is oil's documented disable idiom.
Fix: `["<C-h>"] = false, ["<C-t>"] = false`.
Confidence: HIGH
Counter-argument: intentional, if the author wants `<C-h>` inert in oil. But then `<C-j>`/`<C-k>`/`<C-l>` should be too, and they are not — the asymmetry says this was meant as "disable oil's split binding," which `false` does correctly.

## MEDIUM: Missing `desc` on 37 keymap sites, against the config's own rule
Functions/sites compared: keymaps.lua:50/59/65/73/94/97/106 vs the rest
Evidence A: seven keymaps carry `desc` — `keymaps.lua:50, 59, 65, 73, 94, 97, 106`; every `keys = {}` spec entry carries one (`fzf.lua:9,19,26`; `grug-far.lua:19`; `bufferline.lua:7-9`; `oil.lua:69,99,104,120`).
Evidence B: no `desc` at `keymaps.lua:6, 9, 10, 13, 17, 20, 21, 22, 23, 26, 27, 30, 31, 34, 35, 38, 39, 42, 43, 46, 47, 81, 84, 89`; `multicursor.lua:19, 22, 25, 28, 33, 36, 37, 38, 41, 54`; `nvim-spider.lua:9-13, 14-18, 19-23`.
Problem: CLAUDE.md customization-guide.md says "Always include `desc` — it shows up in which-key." `<leader>o`, `<leader>e`, `<leader>j`, and all ten `<leader>z*` multicursor maps are leader-prefixed and therefore appear in which-key as bare, unlabelled entries.
Fix: add `desc` to the leader-prefixed ones at minimum (`keymaps.lua:46, 47, 89`; `multicursor.lua:19-33`).
Confidence: HIGH
Counter-argument: `j`/`k`/`n`/`N`/`p`/`P` genuinely need no description. Agreed — the finding is scoped to the leader-prefixed subset, where which-key visibly degrades.

## MEDIUM: `opts` table defined once then re-spelled inline seven times
Functions/sites compared: keymaps.lua:2 vs keymaps.lua:50,59,65,73,89,94,97,106
Evidence A: `lua/config/keymaps.lua:2` — `local opts = { noremap = true, silent = true }`, used at `:17, 20-23, 26-27, 30-31, 34-35, 38-39, 42-43, 46-47, 89`.
Evidence B: `:50, 59, 65, 73, 94, 97, 106` write `{ noremap = true, silent = true, desc = "..." }` as fresh literals. `:89` is worse — `{ noremap = true, silent = true }` with **no** `desc`, a pure character-for-character duplicate of the `opts` local declared 87 lines above it.
Problem: the two prefixes drift independently. The `desc` variants exist only because `opts` has no `desc`; a one-line helper (`local function o(desc) return vim.tbl_extend("force", opts, {desc=desc}) end`) removes the duplication.
Fix: helper, or `vim.tbl_extend("force", opts, { desc = "..." })` at each site.
Confidence: MEDIUM
Counter-argument: seven literals in a 109-line file is not a maintenance crisis. It still stands because the file *already* declares the shared table and then ignores it — that is a half-applied convention, which is worse than either extreme.

## MEDIUM: `<C-k>` signature-help binding is inert
Functions/sites compared: blink.lua:7 vs blink defaults
Evidence: `~/.local/share/nvim/lazy/blink.cmp/lua/blink/cmp/config/signature.lua:32-33` — `default = { enabled = false, ...}`. `~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/coding/blink.lua:74-75` leaves `-- signature = { enabled = true },` **commented out**. `blink.cmp/lua/blink/cmp/init.lua:306-311`:
```lua
function cmp.show_signature()
  local config = require('blink.cmp.config').signature
  if not config.enabled or cmp.is_signature_visible() then return end
```
returns `nil` when disabled, so blink falls through to `"fallback"`.
Problem: `lua/langs/blink.lua:7`'s `<C-k>` never shows signature help; insert-mode `<C-k>` falls back to the built-in digraph entry (`:h i_CTRL-K`). `docs/specs/plugins.md` and `docs/specs/keymaps.md` both document it as working. Nothing else fills the gap: grepping `LazyVim/lua/lazyvim/plugins/lsp/keymaps.lua` for `c-k` and `signature_help` returns **no matches**, and Neovim 0.11.4's own default (`~/.local/share/bob/v0.11.4/share/nvim/runtime/lua/vim/_defaults.lua:220-222`, `<C-S>` in modes `i`/`s` → `vim.lsp.buf.signature_help()`) is overwritten by `LazyVim/lua/lazyvim/config/keymaps.lua:81` (`map({"i","x","n","s"}, "<C-s>", "<cmd>w<cr><esc>")`). Signature help has no key in this config at all. Note the `<C-k>` line is also a **byte-for-byte copy of blink's `default` preset** (`presets.lua:23`) which `blink.lua:5` already selects, so it is a zero-delta re-declaration on top of being inert.
Fix: add `signature = { enabled = true }` to `lua/langs/blink.lua`'s opts, or delete the `<C-k>` entry and the doc rows.
Confidence: HIGH
Counter-argument: none — the code path is unconditional and no other mapping supplies the feature.

## MEDIUM: conform has no `stop_after_first`, and three filetypes point at uninstalled binaries
Functions/sites compared: conform.lua:5-22 vs conform.nvim docs + Mason state
Evidence A: `lua/langs/conform.lua:6,9,11,13,16-21` list `{ "prettierd", "prettier" }`. conform README:138,711 — without `stop_after_first = true`, **all** available formatters in a list run in sequence.
Evidence B: runtime facts — `prettier` executable = 0, `clang-format` = 0, and neither is in the Mason bin list. `lua/langs/conform.lua:7-8` (`c`/`cpp` → `clang_format`) and `:10` (`java` → `prettier`) therefore have no runnable formatter.
Problem: (a) if `prettier` is ever installed, every JS/TS/CSS/JSON/YAML file gets formatted twice per save; (b) `c`/`cpp`/`java` silently fall through to LSP formatting via `default_format_opts.lsp_format = "fallback"` (`LazyVim/lua/lazyvim/plugins/formatting.lua:67-72`) — clangd for C/C++, nothing for Java. The intent ("clang_format for C++") is not what happens. Impact is dampened, not eliminated, by the LSP fallback.
Fix: add `stop_after_first = true` at the top level of the `opts` table; add `clang-format` to `lua/langs/dap.lua`'s Mason `ensure_installed` (it already extends correctly — `LazyVim/lua/lazyvim/plugins/lsp/init.lua:287` sets `opts_extend = { "ensure_installed" }`), or enable `lazyvim.plugins.extras.formatting.prettier` which installs prettier and wires 16 filetypes.
Confidence: HIGH
Counter-argument: nothing is broken today because prettier is absent. The `java = { "prettier" }` line is the tell — it was written expecting prettier to exist.

## MEDIUM: `guicursor` command-mode entry uses the operator-pending mode letter
Functions/sites compared: options.lua:29 vs options.lua:38
Evidence A: `lua/config/options.lua:29` — `"n-v-c-sm:block-NormalCursor/lCursor"`. `c` (command-line) is already here, non-blinking, `NormalCursor`.
Evidence B: `lua/config/options.lua:37-38` — comment says "Command mode: blinking block cursor", value is `"o:block-CommandCursor/..."`. In `:h 'guicursor'`, `o` is **operator-pending**, not command-line.
Problem: the yellow blinking cursor appears during operator-pending (after `d`, `c`, `y`), never in command mode. `CLAUDE.md:23` and `docs/specs/architecture.md` state "yellow blinking in insert/replace/command" — false. Separately, `VisualCursor` (`:23`) is defined but named by no `guicursor` entry — dead group (visual mode falls into the `v` of line 29 → `NormalCursor`).
Fix: change `"o:"` to `"c-ci-cr:"` and remove `c` from line 29, or rename the group to `OperatorCursor` and fix the docs. Delete `VisualCursor` or add `v` to its own entry.
Confidence: HIGH
Counter-argument: none — this is `:h 'guicursor'` mode letters.

## MEDIUM: LuaSnip spec duplicates work blink already does, for ~7.8 ms of startup
Functions/sites compared: luasnip.lua:6-10 vs blink's snippet registry
Evidence A: `lua/langs/luasnip.lua:7,9` — `require("luasnip.loaders.from_vscode").lazy_load()` and `lazy_load({ paths = { "~/.config/nvim/snippets" } })`.
Evidence B: runtime facts — blink `snippets.preset = "default"` (`LazyVim/lua/lazyvim/plugins/extras/coding/blink.lua:39-41`), so blink's own registry (`blink.cmp/lua/blink/cmp/sources/snippets/default/registry.lua:16-17,31-33`) already scans `stdpath('config')/snippets` and any rtp path matching `friendly.snippets`. blink does **not** consume LuaSnip. LazyVim's `coding.luasnip` extra is not enabled, so nothing else invokes LuaSnip either — no keymap in this config calls `luasnip.jump`/`expand`.
Problem: LuaSnip loads eagerly at startup (`defaults.lazy = false`) and costs ~7.8 ms across 62 requires; its only surviving effect is pulling `friendly-snippets` onto the rtp so *blink* can find it. Additionally `"~/.config/nvim/snippets"` is hardcoded where LazyVim's own extra uses `vim.fn.stdpath("config") .. "/snippets"` (`extras/coding/luasnip.lua:17`) — the literal breaks on any machine with a non-default config dir, and this repo has per-machine branches.
Fix: replace `lua/langs/luasnip.lua` with a bare `{ "rafamadriz/friendly-snippets" }` spec (blink does the rest), or keep LuaSnip and switch to `stdpath("config")`.
Confidence: HIGH
Counter-argument: LuaSnip is harmless insurance if the user later switches to `snippets.preset = "luasnip"`. Then the `stdpath` fix still applies, and the spec should be `lazy = true`.

## MEDIUM: Two different idioms for removing a LazyVim keymap
Functions/sites compared: keymaps.lua:53-54,108-109 vs flash.lua:9
Evidence A: `lua/config/keymaps.lua:53-54` (`<Leader>bp`, `<Leader>bP`) and `:108-109` (`<leader>uz`, `<leader>uZ`) use `vim.keymap.del`, which throws `E31: No such mapping` if the key is absent — and would abort the rest of the file mid-execution.
Evidence B: `lua/misc/flash.lua:9` uses `{"S", false}` inside the plugin's `keys` table, which `lazy/core/handler/keys.lua:82-86` handles by removing the entry from lazy's managed set — no error possible.
Problem: `<Leader>bp`/`<Leader>bP` are created by bufferline's lazy `keys` handler (`LazyVim/lua/lazyvim/plugins/ui.lua:5-9`), and `<leader>uz`/`<leader>uZ` by LazyVim's `config/keymaps.lua:202-203`. Both exist today (runtime facts confirm the deletes succeed), but the `del` form couples `keymaps.lua` to LazyVim's load order and to those keys continuing to exist across LazyVim upgrades. `{ key, false }` in `lua/ui/bufferline.lua`'s `keys` table is the load-order-independent equivalent for the bufferline pair.
Fix: move the two bufferline deletions into `lua/ui/bufferline.lua` as `{ "<leader>bp", false }, { "<leader>bP", false }`; wrap the `<leader>uz`/`uZ` deletes in `pcall`.
Confidence: MEDIUM
Counter-argument: it works, and `vim.keymap.del` is what LazyVim's own docs recommend for `config/keymaps.lua`. It still stands: the config already demonstrates the safer idiom in `flash.lua`, and the `del` calls are unguarded against a LazyVim rename.

---

## Dead Code Findings

## LOW: Dead file: lua/ui/scrollbar.lua
Location: `lua/ui/scrollbar.lua:1-125`
Evidence: line 1 is `return {}`; lines 2-125 are a fully commented-out nvim-scrollbar spec referencing `catppuccin.palettes`, which is not loaded (runtime facts). `lazy/core/plugin.lua:96` + `lazy/core/util.lua:155-165` — `is_list({})` returns `true`, so the empty table is normalized as an empty list and silently ignored. No error, no plugin, no effect.

## LOW: Dead file: lua/search/harpoon2.lua
Location: `lua/search/harpoon2.lua:1-44`
Evidence: returns `{ {} }`. The inner `{}` reaches `Spec:normalize` (`lazy/core/plugin.lua:93-115`) as an empty list and is skipped — no "Invalid plugin spec" error. All 42 content lines are comments. Harpoon is documented as active in `CLAUDE.md:15`, `docs/specs/architecture.md:74`, `docs/specs/plugins.md:106-114`, `docs/specs/keymaps.md:120-126`, and root `KEYMAPS.md:56-64` — five documents describe a plugin that is not installed.

## LOW: No-op: disabling neo-tree
Location: `lua/misc/disabled.lua:7-10`
Evidence: `nvim-neo-tree/neo-tree.nvim` appears in LazyVim only at `plugins/extras/editor/neo-tree.lua:5` and `plugins/extras/ui/edgy.lua:148`; neither extra is listed in `lazyvim.json:2-18`. LazyVim never adds a neo-tree spec, so `enabled = false` disables nothing. `<leader>e`/`<leader>fe` likewise come only from `extras/editor/neo-tree.lua:9,22` and `extras/editor/snacks_explorer.lua:8,21` — neither enabled — so `keymaps.lua:47`'s `<leader>e` → Oil has no competitor. `CLAUDE.md`'s "neo-tree explicitly disabled" is describing a no-op. Also dead in this file: the empty entry at `:2-5` and the commented dashboard/persistence entries at `:12-20`.

## LOW: Commented-out code blocks
Location — one line-range list:
- `lua/config/keymaps.lua:16` (`ss` split), `:77-78` (old `s`/`S` disable), `:98-103` (`<leader>yf`, `<leader>yn`)
- `lua/config/options.lua:117` (`colorcolumn`)
- `lua/langs/conform.lua:15` (markdown formatters)
- `lua/search/harpoon2.lua:3-42`
- `lua/ui/scrollbar.lua:2-125`
- `lua/ui/oil.lua:54` (size column)
- `lua/ui/bufferline.lua:13` (`mode = "tabs"`)
- `lua/misc/disabled.lua:3-4, 12-20`
- `lua/misc/multicursor.lua:11-16` (`<leader>za`/`zd`), `:47-48` (`<left>`/`<right>`), `:51` (`<leader>x`)
- `lua/misc/checkmate.lua:77-78` (built-in state markers)

## LOW: Settings with no effect
Location — one list:
- `lua/config/options.lua:18` — `vim.opt.guicursor = ""` overwritten four lines later at `:28`. Runtime facts confirm the `:28` value wins.
- `lua/config/options.lua:46, 49, 52` — `netrw_browse_split`, `netrw_banner`, `netrw_winsize` set *after* `:42-43` disable netrw entirely.
- `lua/config/options.lua:135` — `vim.diagnostic.enable(true)` is the Neovim default and takes effect before any buffer exists.
- `lua/config/options.lua:12` — `cursorcolumn = false` is the default; the comment "bugged with nvim-cmp (Jun 17, 2024)" refers to nvim-cmp, which this config replaced with blink.cmp.
- `lua/misc/treesitter-context.lua:3` — `enabled = true` is lazy.nvim's default. (Note: LazyVim only ships treesitter-context in `extras/ui/treesitter-context.lua`, not enabled, so this file is a genuine plugin *add*, not an override — `opts` is correct here.)
- `lua/misc/checkmate.lua:7` — `log = {}` merges nothing into checkmate's log defaults.
- `lua/langs/blink.lua:6, 11, 12, 7` — `<C-space>`, `<Up>`, `<Down>`, `<C-k>` are byte-identical to `blink.cmp/lua/blink/cmp/keymap/presets.lua:8, 12, 13, 23`, the `default` preset already selected at `blink.lua:5`. (`<C-e>`, `<C-p>`, `<C-n>`, `<C-f>`, `<C-b>` **do** differ — `cancel` vs `hide`, `fallback_to_mappings` vs `fallback`, scroll vs accept — so those are real deltas.)
- `lua/langs/conform.lua:12` — `lua = { "stylua" }` is byte-identical to `LazyVim/lua/lazyvim/plugins/formatting.lua:74`.
- `lua/config/keymaps.lua:6` — `<C-c>` → `"+y` is zero-delta given `:5` sets `clipboard = "unnamedplus"` (LazyVim also sets it, `config/options.lua:57`); every yank already goes to `+`.
- `lua/misc/flash.lua:3-6` — `event = "VeryLazy"`, `vscode = true`, `opts = {}` all match LazyVim's flash spec.
- `lua/ui/bufferline.lua:5` — `event = "VeryLazy"` matches `LazyVim/lua/lazyvim/plugins/ui.lua:5`.
- `lua/search/grug-far.lua:1-22` — near-duplicate of `LazyVim/lua/lazyvim/plugins/editor.lua:5-25`; only deltas are the added `cmd = "GrugFar"` and `mode = {"n","v"}` vs `{"n","x"}` (equivalent in practice).
- `lua/config/options.lua` — values identical to `LazyVim/lua/lazyvim/config/options.lua`: `number` (`:9`), `relativenumber` (`:6`), `ignorecase` (`:90`), `smartindent` (`:70`), `expandtab` (`:64`), `termguicolors` (`:99`), `undofile` (`:87`), `splitright` (`:126`), `splitbelow` (`:129`), `signcolumn` (`:105`), `spelllang` (`:123`), `completeopt` (`:73`), `wrap` (`:76`), `linebreak` (`:77`). `nu` at `:55` is a second spelling of `number` at `:9`.

## LOW: Comments contradicting the code they annotate
Location: `lua/config/options.lua:5, 11, 63, 95, 101`; `lua/config/keymaps.lua:80`
Evidence: `:5` "Disable relative line numbers" above `relativenumber = true`. `:63` "Use actual tabs (not spaces)" above `expandtab = true` (spaces). `:95` "Highlight the current line" above `cursorline = false`. `:101` "Keep 8 lines visible" above `scrolloff = 3`. `:11` cites nvim-cmp, replaced by blink.cmp. `keymaps.lua:80` cites "nvim-surround"; this config uses `mini.surround` (`lua/misc/mini-surround.lua:3`).

## LOW: Orphaned tracked file and bypassed extras path
Location: `.neoconf.json:1-15`; `lua/config/lazy.lua:22-23`
Evidence: `.neoconf.json` configures `neodev` and `neoconf` plugins; runtime facts confirm neoconf.nvim is not in `lazy-lock.json` and no spec in the repo requests it — nothing reads the file. Separately, `lua/config/lazy.lua:22-23` imports `lazyvim.plugins.extras.dap.core` and `.dap.nlua` directly in the spec, while `lazyvim.json:2-18` is the managed extras manifest — two parallel extras mechanisms, and `:LazyExtras` will not show the dap ones as enabled.

## LOW: Spec-shape and style inconsistency
Location — one list:
- Bare spec (`return { "author/name", ... }`): `blink.lua`, `luasnip.lua`, `fzf.lua`, `grug-far.lua`, `arrow.lua`, `snacks.lua`, `checkmate.lua`, `flash.lua`, `multicursor.lua`, `treesitter-context.lua`.
- Wrapped (`return { { ... } }`): `lsp.lua`, `conform.lua`, `nvim-lint.lua`, `markdown.lua`, `dap.lua`, `colorscheme.lua`, `oil.lua`, `bufferline.lua`, `gitsigns.lua`, `mini-comment.lua`, `mini-surround.lua`, `nvim-spider.lua`, `vim-sleuth.lua`, `disabled.lua`.
- Mixed `<Leader>` (`keymaps.lua:46, 47, 50, 53, 54, 57, 63`) vs `<leader>` (`:71, 89, 92, 95, 106, 108, 109`).
- Mixed keymap RHS style: `:cmd<Return>` (`keymaps.lua:17, 46, 47, 50, 58, 64, 106`) vs `<Cmd>cmd<CR>` (`bufferline.lua:7-9`) vs `<cmd>cmd<CR>` (`checkmate.lua:13` ff., `nvim-spider.lua:11`).
- `arrow.lua:8-9` uses single-quoted strings and `:10` omits the trailing comma; every other file uses double quotes. `stylua --check .` reports 5 unformatted files (runtime facts): `treesitter-context.lua`, `arrow.lua`, `keymaps.lua`, `autocmds.lua`, `oil.lua` — `stylua.toml` exists but nothing enforces it.
- `lua/ui/oil.lua:4-5` — `---@module 'oil'` / `---@type oil.SetupOpts` sit immediately above `dependencies` (`:8`), so they annotate the dependency list, not the setup table (which is a positional argument at `:49`, not an `opts` key). Dead annotation.
- `lua/ui/oil.lua:12` binds `local oil = require("oil")` (used at `:83`), but `:106` and `:122` call `require("oil")` again.
- `lua/langs/blink.lua:16-17` binds `<C-.>` and `<C-,>`; these require CSI-u / kitty keyboard protocol to be distinguishable from `.` and `,` and will silently do nothing in a terminal without it. Documented as working in `docs/specs/keymaps.md`.
- `LazyVim/lua/lazyvim/plugins/extras/coding/blink.lua:104` sets `["<C-y>"] = { "select_and_accept" }`; `lua/langs/blink.lua` does not remove it, so `<C-y>` accepts completions alongside `<C-f>`. Undocumented in `docs/specs/plugins.md`, which lists `<C-f>` as the only accept key.

---

## Verified-correct (checked, no finding)

- `lua/langs/dap.lua:10` — `mason.nvim` sets `opts_extend = { "ensure_installed" }` (`LazyVim/lua/lazyvim/plugins/lsp/init.lua:287`), so `{"php-debug-adapter"}` appends to `{"stylua","shfmt"}` rather than replacing.
- `lua/langs/nvim-lint.lua:6` — `markdown = {}` **does** clear the linter. `lazy/core/util.lua:440-442` `can_merge` is false for the non-empty list `{"markdownlint-cli2"}`, so `util.lua:466` `ret = value` replaces it with `{}`.
- `lua/langs/lsp.lua:6` — `angularls = false` coexists with the enabled angular extra. The extra's real payload survives: treesitter `angular`/`scss` parsers (`extras/lang/angular.lua:14-22`) and the vtsls `@angular/language-server` global plugin (`:51-57`) are independent of the `angularls` entry. Deliberate delta, not a regression — **with one caveat**: `LazyVim/lua/lazyvim/plugins/lsp/init.lua:270` (`vim.tbl_filter(configure, vim.tbl_keys(opts.servers))`) drops `false` servers from `ensure_installed`, so nothing keeps the `angular-language-server` Mason package installed, yet `extras/lang/angular.lua:54` `LazyVim.get_pkg_path("angular-language-server", ...)` still points the vtsls plugin at that package's path. Runtime facts confirm `ngserver` is present today (installed before the override); a Mason clean would silently break vtsls Angular support.
- `lua/misc/gitsigns.lua:4-15` — correctly uses `opts = function(_, opts)` to *wrap* LazyVim's `on_attach` rather than replace it.
- `lua/search/arrow.lua:4` and `lua/ui/oil.lua:8` — `nvim-mini/mini.icons` matches LazyVim's org (`LazyVim/lua/lazyvim/plugins/ui.lua:250`); no duplicate plugin entry.
- `config = function()` in `colorscheme.lua`, `oil.lua`, `multicursor.lua` loses no LazyVim defaults — none of those three plugins has a LazyVim spec (grep of `lazyvim/plugins/` returns nothing for `danfry1/lume`, `stevearc/oil`, `jake-stewart/multicursor`).
- `lua/langs/blink.lua:22-23` `["<Tab>"]`/`["<S-Tab>"] = { "fallback" }` correctly suppresses LazyVim's ai_accept injection (`extras/coding/blink.lua:126` — `if not opts.keymap["<Tab>"] then`) **and does not break snippet placeholder navigation**. Neovim 0.11.4 ships an unconditional default (`~/.local/share/bob/v0.11.4/share/nvim/runtime/lua/vim/_defaults.lua:228-243`) mapping `<Tab>`/`<S-Tab>` in modes `{'i','s'}` to `vim.snippet.jump(±1)` when `vim.snippet.active()`, else the literal key. Since `extras/coding/blink.lua:109-111` sets `opts.snippets.expand = LazyVim.cmp.expand` for `preset = "default"`, the `${1:}`/`${2:}`/`${0:}` placeholders in `snippets/cpp.json` and `snippets/rust.json` are `vim.snippet` tab stops and the fallback reaches that default. `bufferline.lua:7-8` remaps `<Tab>`/`<S-Tab>` in **normal** mode only, so it does not interfere.
- `lua/misc/flash.lua:3-6` — verified byte-identical to `LazyVim/lua/lazyvim/plugins/editor.lua:32-35` (`event = "VeryLazy"`, `vscode = true`, `---@type Flash.Config`, `opts = {}`); listed above as zero-delta, not as a behavioural finding.
- `lua/ui/oil.lua:65-70` `<C-s>` → write: matches LazyVim's global `<C-s>` (`config/keymaps.lua:81`), so this restores consistent behaviour inside oil rather than breaking it.
- Deliberate, dropped from findings: `=`/`-` shadowing the indent operators (`keymaps.lua:9-10`), arrow's `;`/`m` leaders, `updatetime = 50`, `<C-d>`/`<C-u>` fixed count of 20, `sessionoptions` omitting `"folds"`.

---

## Files Read (this session)

Config under audit:
- `docs/reviews/2026-09-06-nvim-config-full/context/runtime-facts.md:1-65`
- `docs/reviews/2026-09-06-nvim-config-full/context/config-bundle.txt:1-1403` (all 35 bundled files)
- `snippets/cpp.json:1-28`, `snippets/rust.json:1-30` (not in the bundle)

Plugin / framework sources under `~/.local/share/nvim/lazy/`:
- `LazyVim/lua/lazyvim/config/keymaps.lua:1-90`
- `LazyVim/lua/lazyvim/plugins/lsp/init.lua:6-10, 269-313` (grep)
- `LazyVim/lua/lazyvim/plugins/lsp/keymaps.lua` (grep `c-k|signature_help` — no matches)
- `LazyVim/lua/lazyvim/plugins/formatting.lua:10-18, 62-79` (grep)
- `LazyVim/lua/lazyvim/plugins/linting.lua:6-14, 43-80` (grep)
- `LazyVim/lua/lazyvim/plugins/editor.lua:31-41` (grep)
- `LazyVim/lua/lazyvim/plugins/extras/coding/blink.lua:22-41, 71-137` (grep)
- `LazyVim/lua/lazyvim/plugins/extras/coding/mini-comment.lua:1-15`
- `LazyVim/lua/lazyvim/plugins/extras/coding/luasnip.lua:5-74` (grep)
- `LazyVim/lua/lazyvim/plugins/extras/lang/angular.lua:1-71`
- `LazyVim/lua/lazyvim/plugins/extras/lang/markdown.lua:70-90` (grep)
- `LazyVim/lua/lazyvim/plugins/extras/editor/snacks_explorer.lua:5-21` (grep)
- `LazyVim/lua/lazyvim/plugins/extras/editor/neo-tree.lua:3-22` (grep)
- `LazyVim/lua/lazyvim/plugins/ui.lua:250-263` (grep)
- `lazy.nvim/lua/lazy/core/handler/keys.lua:1-203`
- `lazy.nvim/lua/lazy/core/plugin.lua:78-131`
- `lazy.nvim/lua/lazy/core/util.lua:155-165, 440-470` (grep)
- `blink.cmp/lua/blink/cmp/keymap/presets.lua:1-60`
- `blink.cmp/lua/blink/cmp/config/signature.lua:7-45`
- `blink.cmp/lua/blink/cmp/init.lua:306-326` (grep)
- `oil.nvim/lua/oil/keymap_util.lua:1-94`
- `lume/lua/lume/init.lua:1-36`
- `lume/colors/lume.lua:1`

Neovim runtime:
- `~/.local/share/bob/v0.11.4/share/nvim/runtime/lua/vim/_defaults.lua:220-249` (grep `snippet`)

Not verified this session: the `docs/specs/*.md` and root `KEYMAPS.md` drift claims (taken from `runtime-facts.md`, which the main session verified); `lazy-lock.json` contents; all `vim.fn.executable` / Mason bin results (runtime facts, unrunnable here); `nvim_get_hl(0, {name="InsertCursor"})` post-startup state (needs a live nvim — the load-order argument in HIGH #1 is source-derived).
