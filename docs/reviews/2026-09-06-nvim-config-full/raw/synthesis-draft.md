# Phase 4 synthesis — deduplicated findings (draft, pre-challenger)

Raw inputs: correctness (9), architecture (13), security (2), quality (18), baseline (22), data-contract (10), spec-compliance (24) = 98 raw findings → 40 deduplicated below. "Agents" lists every agent that independently raised it. "Main-session" states what the orchestrator verified itself (headless nvim run or source read) before this draft.

Severity scale: Critical = correctness bug / data loss that blocks merge. High = significant defect, fix before merge. Medium = real issue, no immediate harm. Low = minor.

## Critical
None.

## High

### H1: Custom cursor highlight groups are empty at runtime — the documented yellow insert cursor does not exist
Location: lua/config/options.lua:21-25 (definitions), :28-39 (guicursor), lua/ui/colorscheme.lua:6-11
Agents: architecture, baseline
Main-session: headless run after VeryLazy — `nvim_get_hl(0,{name="NormalCursor"})` and the other four `*Cursor` groups return `{}`; `Comment`/`@comment` are mint italic; `Cursor`/`lCursor` defined by lume. Chain: options.lua runs first → LazyVim setup applies default colorscheme tokyonight (config/init.lua:13-15,250-256; tokyonight theme.lua:12 `hi clear` skipped because colors_name nil) → lume `config` at priority 1000 → lume `load()` runs `hi clear` because colors_name is now set (lume/lua/lume/init.lua:17-19) → user groups wiped.
Fix: move the five cursor groups and the two comment groups into lume `opts.custom_highlights` (lume theme.lua:71-81 applies them after its own groups), set `{ "LazyVim/LazyVim", opts = { colorscheme = "lume" } }`, make lume `lazy = true`. See also M12 (guicursor `o:` vs `c`).
Pending: deep-dive-colorscheme (fix validity).

### H2: `sv` shares the `s` prefix with Flash — every jump waits 300 ms, and `s`+`v` opens a split
Location: lua/config/keymaps.lua:17; LazyVim editor.lua:38 (`s` in n/x/o)
Agents: correctness, baseline
Main-session: headless maparg — both `s` (Flash) and `sv` (`:vsplit<Return>`) live in normal mode; `timeoutlen = 300`.
Fix: rebind the split (LazyVim already has `<leader>wv` / `<leader>|`), or disable Flash `s`.

### H3: `custom_commentstring` override disables treesitter-aware comments (TSX/JSX, HTML `<style>`, markdown fences, Angular templates)
Location: lua/misc/mini-comment.lua:7-9
Agents: correctness, architecture, data-contract, spec-compliance
Main-session: LazyVim extra sets ts_context_commentstring lookup (extras/coding/mini-comment.lua:7-9); mini.comment's own default also walks treesitter (mini/comment.lua:359-366); the override returns non-nil so both are unreachable. Root cause of the override: nvim-ts-context-commentstring hardcodes `c = '/* %s */'` (config.lua:66) while Neovim's ftplugin sets `// %s` (runtime/ftplugin/c.lua:2, cpp.vim:17).
Fix: delete the override; add `{ "JoosepAlviste/nvim-ts-context-commentstring", opts = { languages = { c = "// %s" } } }`; drop the c/cpp commentstring autocmd (redundant on 0.11.4).
Pending: deep-dive-mini-comment (fix validity, formatoptions semantics).

### H4: LuaSnip loads eagerly (~7.8 ms of a 46 ms startup) and nothing reads it
Location: lua/langs/luasnip.lua:1-11
Agents: quality, architecture, baseline, data-contract, spec-compliance
Main-session: blink `snippets.preset = "default"` (LazyVim extras/coding/blink.lua:39-41); blink's registry scans `stdpath('config')/snippets` and rtp `friendly.snippets` (registry.lua:16-17,31-33); LazyVim's blink extra already depends on `rafamadriz/friendly-snippets` (extras/coding/blink.lua:25). Startup self-time 7.8 ms across 62 requires. Hardcoded `~/.config/nvim/snippets`.
Fix: delete lua/langs/luasnip.lua. Nothing else needed — friendly-snippets stays via the blink extra. (If LuaSnip features are wanted later: enable the `coding.luasnip` extra instead.)
Correction: an earlier runtime-facts line said luasnip.lua was the only friendly-snippets source; that was wrong (see runtime-facts.md correction).

### H5: Documentation drift feeds wrong facts to every session via CLAUDE.md `@`-includes
Location: CLAUDE.md, docs/specs/{architecture,plugins,keymaps,customization-guide}.md, KEYMAPS.md
Agents: spec-compliance (24 rows), quality, architecture, baseline
Main-session verified: harpoon documented active in 5 places but lua/search/harpoon2.lua is fully commented out; checkmate's `keys` table replaces defaults wholesale (checkmate config/init.lua:537-539) so documented `<leader>ta`, `<leader>t]`, `<leader>t[` do not exist; `@priority`/`@started` keep default keys `<leader>Tp`/`<leader>Ts` (defaults.lua:157,169), docs say lowercase; `<leader>uz`/`uZ` are Snacks zen/zoom (LazyVim keymaps.lua:202-203), docs say "fold toggles"; oil `gy`, checkmate `<leader>tx`/`th`, custom states `- [c]`/`- [/]`, fzf ctrl-actions/no_ignore/hidden, C/C++ `*` insert map, oil buffer-cleanup autocmd all undocumented; `.neoconf.json` documented as live (neoconf.nvim not installed); CLAUDE.md omits debugging.md and the two dap extras imported in lazy.lua; `<Tab>` row names a non-existent LazyVim default (real loss is `<C-i>`); cursor claim "yellow in command" false; branch list omits macbook-backup; line refs stale (lazy.lua:36-54 should be 30-57; 18-26 should be 18-29); spec `updated: 2026-05-26` predates every drift commit (941603d, 3922f2b, ed5fb23, 276cc2b, 5de9fee, cd512b0).
Fix: update the four spec docs and CLAUDE.md; delete or reduce KEYMAPS.md to a pointer; add debugging.md to the `@` list; bump `updated:`.

### H6: `vim.keymap.del` in keymaps.lua is an all-or-nothing failure point
Location: lua/config/keymaps.lua:53-54, 108-109
Agents: architecture, baseline
Main-session: `vim.keymap.del` on a missing map throws `E31: No such mapping` (verified headless); LazyVim wraps `require("config.keymaps")` in one `LazyVim.try` (config/init.lua:286-291), so a throw skips every later line (buffer moves, `<leader>r`, `S`/`q` disables, `<leader>j`, yank paths, `<leader>cp`). Works today only because bufferline loads before user keymaps at VeryLazy (verified: `<leader>bp` = MovePrev).
Fix: express the bufferline override in lua/ui/bufferline.lua `keys` (`{ "<leader>bp", "<Cmd>BufferLineMovePrev<CR>" }`, `{ "<leader>bn", ... }`, `{ "<leader>bP", false }`); lazy.nvim dedupes keys by id with later spec winning (handler/init.lua:90-98) and `false` removes (handler/keys.lua:82-86). Wrap the `<leader>uz`/`uZ` deletes in `pcall`.
Pending: deep-dive-keymaps (fix validity, merge order).

### H7: Literal grep (`<leader>\``) drops the `-e` terminator — any query starting with `-` fails
Location: lua/search/fzf.lua:16
Agents: correctness, data-contract
Main-session: fzf-lua default grep `rg_opts` ends with `--max-columns=4096 -e` (defaults.lua:974-975); query appended positionally (make_entry.lua:414-419). User string has no `-e`/`--` and drops `--max-columns`.
Fix: append ` --max-columns=4096 -e` to the string.
Pending: deep-dive-fzf (ctrl-g toggle interplay).

## Medium

### M1: `<leader>r` "Search and Replace Current File" widens to the whole cwd for unnamed buffers; paths with spaces split
Location: lua/config/keymaps.lua:72; also lua/ui/oil.lua:83 (`gs` unguarded `get_current_dir()`)
Agents: security (2), data-contract
Main-session: grug-far only appends path args when non-empty (getArgs.lua:86-93); `splitPaths` splits on unescaped spaces (utils.lua:388-413); only empty-string replacements are confirmed (replace.lua:144).
Fix: guard on `vim.bo.buftype == ""` and non-empty `expand("%")`, escape spaces, use a Lua function instead of a `:lua` string.

### M2: conform lists lack `stop_after_first`; C/C++/Java formatters not installed
Location: lua/langs/conform.lua:5-22
Agents: quality, architecture, baseline, correctness, data-contract, spec-compliance
Main-session: conform README:138,711; `prettier`/`clang-format` absent from PATH and Mason bin; conform resolves prettier from node_modules (formatters/prettier.lua) so both run in JS projects; every format warns "Formatter 'prettier' unavailable"; LazyVim `lsp_format = "fallback"` (formatting.lua:71) rescues C/C++ via clangd but Java has no LSP → "No formatters available".
Fix: `stop_after_first = true`; either enable `formatting.prettier` extra or drop the `prettier` fallbacks and `java`; add `clang-format` to Mason `ensure_installed` (pattern already in dap.lua).

### M3: tokyonight loads at startup, then lume replaces it; colorscheme chosen by side effect
Location: lua/ui/colorscheme.lua:1-13
Agents: quality, architecture
Main-session: `tokyonight loaded = true` in headless run; LazyVim default `colorscheme` function (config/init.lua:13-15); ~1.1 ms. Fix folded into H1.

### M4: `n`/`N` override is normal-mode only and drops `zv`
Location: lua/config/keymaps.lua:38-39 vs LazyVim keymaps.lua:68-73 (n/x/o, `'Nn'[v:searchforward].'zv'`)
Agents: baseline
Fix: `map({"n","x","o"}, "n", "'Nn'[v:searchforward].'zvzz'", { expr = true })` and the mirror for `N`.

### M5: `{"S", false}` disables Flash `S` in normal mode only
Location: lua/misc/flash.lua:9; LazyVim editor.lua:39 (`S` in n/o/x); lazy.nvim keys.lua:78 (default mode "n")
Agents: data-contract (filed HIGH; downgraded here — x/o `S` runs flash treesitter, not destructive)
Fix: `{ "S", mode = { "n", "o", "x" }, false }`.

### M6: `<C-k>` signature-help key is inert
Location: lua/langs/blink.lua:7
Agents: baseline
Main-session: blink `signature.enabled` default false (config/signature.lua:33); LazyVim leaves it commented (extras/coding/blink.lua:74-75). No other key provides signature help (LazyVim overrides `<C-s>`).
Fix: `signature = { enabled = true }` in blink opts, or delete the key and its doc rows.

### M7: `<leader>cp` means LspStop everywhere except markdown, where it is Markdown Preview
Location: lua/config/keymaps.lua:106; LazyVim extras/lang/markdown.lua:84 (`ft = "markdown"`)
Agents: baseline
Fix: move LspStop to a free key.

### M8: Oil `"<Nop>"` for `<C-h>` shadows window navigation inside oil buffers
Location: lua/ui/oil.lua:73-74
Agents: baseline
Main-session: oil `set_keymaps` skips only when rhs is falsy (keymap_util.lua:67-73); `"<Nop>"` creates a buffer-local map that beats LazyVim's global `<C-h>` → left window.
Fix: `["<C-h>"] = false, ["<C-t>"] = false`.

### M9: Oil delete-buffer cleanup never fires for directory deletes
Location: lua/ui/oil.lua:160-171
Agents: correctness
Main-session: oil emits one `delete` action per entry with `entry_type` and `url = parent .. name` (mutator/init.lua:174-178); equality test cannot match children.
Fix: for `entry_type == "directory"`, also match buffers whose canonical name starts with `target .. "/"`.
Pending: deep-dive-oil (trash action type, parse_url contract).

### M10: Oil `gs` calls two deprecated grug-far functions
Location: lua/ui/oil.lua:94,96
Agents: data-contract
Main-session: `vim.deprecate` at grug-far.lua:502 (`open_instance`) and :516 (`update_instance_prefills`).
Fix: `require("grug-far").get_instance("explorer"):open()` / `:update_prefills(prefills, false)`.

### M11: checkmate `cancelled.order = 2` ties with built-in `checked.order = 2`
Location: lua/misc/checkmate.lua:85
Agents: correctness
Main-session: defaults.lua:99-102; parser sorts by order (parser/init.lua:217-219); validate.lua checks markers/markdown, not order.
Fix: `order = 3`.

### M12: guicursor uses `o:` (operator-pending) where the comment and docs say command mode; `VisualCursor` unused
Location: lua/config/options.lua:29,37-38,23
Agents: baseline, spec-compliance
Fix: `"c-ci-cr:block-CommandCursor/..."` and remove `c` from :29, or rename; delete `VisualCursor`. Becomes visible only after H1.

### M13: C/C++ insert-mode `*` auto-close fires after any `/` (globs in strings, includes, open comments)
Location: lua/config/autocmds.lua:24-31
Agents: correctness
Fix: bail when treesitter captures at cursor include `string`/`comment`.
Pending: deep-dive-autocmds-star.

### M14: mini-comment autocmds are positional `opts` entries created at spec-parse time, no augroup, dead `h`/`hpp` patterns, global `vim.opt` mutation
Location: lua/misc/mini-comment.lua:11-23
Agents: correctness, architecture, quality, baseline, data-contract
Main-session: `formatoptions = "jtqnl"` globally in headless run; `.h`/`.hpp` map to `c`/`cpp` filetypes.
Fix: move to lua/config/autocmds.lua under an augroup; `pattern = { "c", "cpp" }` (or drop, see H3); `vim.opt_local`.
Pending: deep-dive-mini-comment (opt vs opt_local semantics).

### M15: `<Tab>` in normal mode removes jumplist-forward (`<C-i>`)
Location: lua/ui/bufferline.lua:7
Agents: correctness, spec-compliance
Type: risk (deliberate trade-off). Fix if wanted: bind a replacement for `<C-i>` or use LazyVim's `<S-h>`/`<S-l>`.

### M16: `clipboard` set from keymaps.lua, discarding LazyVim's SSH-aware default
Location: lua/config/keymaps.lua:5 vs LazyVim options.lua:57
Agents: architecture, baseline
Fix: delete the line (LazyVim already sets it) or move to options.lua with a comment.

### M17: Angular extra enabled while `angularls = false`; `ngserver` installed but dropped from `ensure_installed`
Location: lua/langs/lsp.lua:6 vs lazyvim.json:7; LazyVim lsp/init.lua:270 filters `false` servers out of ensure_installed; angular.lua:54 still points vtsls at the `angular-language-server` package path
Agents: architecture, baseline
Fix: record the intent in a comment; if the treesitter/vtsls parts are wanted, keep both but note that a Mason clean would remove the package vtsls references.

### M18: lua/search/grug-far.lua is a verbatim copy of LazyVim's spec; `headerMaxWidth` is not a grug-far option
Location: lua/search/grug-far.lua:1-22 vs LazyVim editor.lua:5-25
Agents: quality, architecture, data-contract, baseline
Main-session: zero matches for `headerMaxWidth` in grug-far source (LazyVim upstream passes it too).
Fix: delete the file.

### M19: options.lua re-declares 14 LazyVim defaults, five comments contradict their values, and several lines are dead
Location: lua/config/options.lua:5-6,9,11,18,41-52,55,63-64,70,73,76-77,87,90,95-96,99,101-102,105,123,126,129,135; lua/config/keymaps.lua:80 (nvim-surround comment)
Agents: quality, architecture, baseline, spec-compliance
Fix: keep only real deltas (tabstop 4, shiftwidth 0, softtabstop 4, scrolloff 3, updatetime 50, cursorline false, swapfile/backup false, iskeyword/isfname, guicursor, autoread, sessionoptions, snacks_animate, autoformat, mkdp_auto_close, python host/perl) with corrected comments.

### M20: Missing `desc` on leader-prefixed keymaps (`<leader>o`, `<leader>e`, `<leader>j`, ten `<leader>z*`)
Location: lua/config/keymaps.lua:46,47,89; lua/misc/multicursor.lua:19-41
Agents: baseline, quality
Fix: add `desc`.

## Low

### L1: Dead files and no-op disable: lua/search/harpoon2.lua (all commented), lua/ui/scrollbar.lua (`return {}` + 124 commented lines referencing catppuccin), lua/misc/disabled.lua (empty entry; neo-tree lives only in the un-enabled `editor.neo-tree` extra)
Agents: quality, architecture, baseline. Fix: delete the two files; delete or annotate disabled.lua.

### L2: Commented-out code blocks (keymaps.lua:16,77-78,98-103; options.lua:117; conform.lua:15; oil.lua:54; bufferline.lua:13; multicursor.lua:11-16,47-51; checkmate.lua:77-78; disabled.lua:3-4,12-20)
Agents: baseline, quality. Fix: delete; git has them.

### L3: fzf.lua mutates fzf-lua's module-level defaults in place and rebuilds `rg_opts` from raw defaults instead of merged opts
Location: lua/search/fzf.lua:34-39,56. Agents: quality, architecture. Fix: `(opts.grep.rg_opts or defaults.grep.rg_opts)`.
Pending: deep-dive-fzf.

### L4: `<leader>ba` uses `:bufdo bd`
Location: lua/config/keymaps.lua:50. Agents: main-session. `Snacks.bufdelete.all()` exists (bufdelete.lua:96).
Pending: deep-dive-keymaps (failure modes with modified buffers).

### L5: Eager loading of arrow, multicursor, treesitter-context (no `keys`/`event`)
Agents: quality. Fix: `keys = { ";", "m" }`, `keys = { "<leader>z", "<c-q>" }`, `event = "LazyFile"`.

### L6: Hex colors duplicated across five files; `#1e1e2e`/`#ffd400` are Catppuccin residue
Agents: quality. Fix: locals or lume palette.

### L7: Oil filetype column re-runs `vim.filetype.match` and two `require`s per entry per render; buffer-cleanup loop is D×B realpath calls
Location: lua/ui/oil.lua:16-42,160-171. Agents: quality. Fix: hoist requires/overrides; cache by extension.

### L8: 5 files fail `stylua --check` (treesitter-context, arrow, keymaps, autocmds, oil); stylua only in Mason bin, not on PATH
Agents: quality, baseline. Fix: run Mason's stylua once as its own commit.

### L9: Tracked cruft: `.neoconf.json` (no consumer), `KEYMAPS.md` (362-line divergence from docs/specs/keymaps.md), boilerplate `README.md`, five dated docs at docs/ root without frontmatter, empty `ref/` and `.tests/`
Agents: quality, spec-compliance. Fix: delete/move.

### L10: Keymap style inconsistency: `:cmd<Return>` vs `<cmd>…<cr>`, `<Leader>` vs `<leader>`, `opts` table declared then re-spelled seven times, `<leader>r` as a `:lua` string
Agents: quality, baseline.

### L11: `<C-.>`/`<C-,>` require CSI-u terminals; `<C-y>` also accepts completions (LazyVim) and is undocumented
Location: lua/langs/blink.lua:16-17; LazyVim extras/coding/blink.lua:104. Agents: baseline.

### L12: Notes: `sessionoptions` omits `"folds"` (LazyVim includes it); gitsigns wrapper swallows `on_attach`'s return; `metadata.done` replaces the default entry wholesale; `log = {}`, `enabled = true`, `vim.diagnostic.enable(true)` are no-ops; `<C-c>` yank is zero-delta with `clipboard=unnamedplus`; oil `---@module`/`---@type` annotations sit on `dependencies`, not `opts`
Agents: baseline, data-contract, quality.

## Dropped / merged
- "Autocmds not always on VeryLazy" (spec LOW) → folded into H5 doc fixes.
- Data-contract HIGH on `S` → M5 (impact is a visible jump-label UI in visual mode, not damage).
- Security "space-split paths" → merged into M1.
- Deliberate trade-offs not filed as defects (all agents agreed): `=`/`-` remaps, arrow `;`/`m`, `updatetime = 50`, fixed `20<C-d>`, `sessionoptions` without folds.

## Pending deep-dives (Phase 3)
deepdive-oil-cleanup (M9), deepdive-fzf (H7, L3), deepdive-autocmds-star (M13), deepdive-colorscheme (H1/M3/M12 fix), deepdive-keymaps (H6 fix, L4, `<leader>j`, visual p/P), deepdive-mini-comment (H3/M14 fix).
