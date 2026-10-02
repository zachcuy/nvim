# Challenger A verdicts — H2, H4, H5

## H2: DOWNGRADED to MEDIUM
Original: `sv` shares the `s` prefix with Flash — every jump waits 300 ms and `s`+`v` opens a split.
Verdict: DOWNGRADED to MEDIUM

### Evidence
`lua/config/keymaps.lua:17` — `keymap.set("n", "sv", ":vsplit<Return>", opts)`.
LazyVim `lua/lazyvim/plugins/editor.lua:38` — `{ "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" }`.
`lua/misc/flash.lua:8-10` — `keys = { {"S", false}, }` — only `S` is disabled; lazy.nvim appends `keys`, so `s` survives.
runtime-facts.md:15 — "`s` = Flash jump (LazyVim default) AND `sv` = \":vsplit<Return>\" both mapped in normal mode; `timeoutlen` = 300."

### Reasoning
The collision is real and reachable — both mappings are live in normal mode. But the stated impact is overstated on both halves. The latency is bounded at 300 ms and is only observable if the user *pauses* after `s`; typing the next pattern character resolves the mapping immediately. The functional break is narrow: only jumps whose **first** pattern character is `v` are lost, only in normal mode (`sv` is not mapped in `x`/`o`, so operator-pending and visual Flash are unaffected), and the failure outcome is a vertical split — reversible with `<C-w>c`, no data loss.

### Fix Assessment
Rebinding the split is correct, and both cited replacements check out. LazyVim maps `<leader>|` to `<C-W>v` directly (`lua/lazyvim/config/keymaps.lua:200`), and `<leader>wv` reaches the same command through which-key: `lua/lazyvim/plugins/editor.lua:91-94` registers `{ "<leader>w", group = "windows", proxy = "<c-w>", ... }`, so `<leader>wv` expands to `<C-w>v`. Deleting `sv` therefore costs nothing. The alternative "disable Flash `s`" should be de-recommended: `lua/config/keymaps.lua:76-78` shows the user previously disabled `s`/`S` and deliberately re-enabled `s` (only line 81's `S` disable survives), so that branch reverses a visible decision.

Counter-argument: "accidentally splitting a window mid-jump is silent and disruptive, so HIGH is right." It still stands at MEDIUM — silence and disruption are real but the blast radius is one reversible window split confined to `v`-initial targets in one mode, with no state loss, which is squarely MEDIUM impact rather than HIGH.

---

## H4: DOWNGRADED to LOW
Original: LuaSnip loads eagerly (~7.8 ms of a 46 ms startup) and nothing reads it.
Verdict: DOWNGRADED to LOW

### Evidence
(a) blink.cmp `lua/blink/cmp/config/snippets.lua:29-31` — `expand = by_preset({ default = function(snippet) vim.snippet.expand(snippet) end, luasnip = function(snippet) require('luasnip').lsp_expand(snippet) end,` — `by_preset` (:9-14) dispatches on `config.snippets.preset`; `active` (:43) and `jump` (:57) likewise route `default` to `vim.snippet`. With `preset = 'default'` no LuaSnip branch is ever entered.
(b) LazyVim `lua/lazyvim/plugins/extras/coding/blink.lua:39-41` sets `snippets = { preset = "default" }` and :25 declares `"rafamadriz/friendly-snippets"` as a dependency. `lua/langs/blink.lua:3-26` overrides only `opts.keymap`, so `preset` is untouched; runtime-facts.md:30 observed `snippets.preset = "default"` at runtime.
(c) `lazyvim.json:2-18` enables neither `coding.luasnip` nor `coding.mini-snippets`. Grepping `luasnip` across all of LazyVim's `lua/lazyvim/` outside those two extras yields only `extras/coding/neogen.lua:20` and `extras/lang/haskell.lua:84,88` — neither extra is enabled. In the config itself only `lua/langs/luasnip.lua` requires it.
(d) No duplication today. Glob shows `snippets/cpp.json` and `snippets/rust.json` with **no** `snippets/package.json`, so blink takes `scan.scan_for_snippets` (`sources/snippets/default/scan.lua:8,57`), producing numeric-indexed paths keyed by `vim.fn.fnamemodify(files[ft], ':t:r')` (:12) → filetypes `cpp`/`rust`. `registry.lua:17` sets `search_paths = { vim.fn.stdpath('config') .. '/snippets' }` and `config/sources.lua:48` has `default = { 'lsp', 'path', 'snippets', 'buffer' }`. The `[snippet] …` prefixes therefore already reach completion via blink alone, exactly once.

### Reasoning
Every factual sub-claim holds — LuaSnip is genuinely unreferenced. Its only work is the two `lazy_load` calls at `lua/langs/luasnip.lua:7,9`; `from_vscode.lua:587-596` shows `lazy_load` deferring via `_load(true, opts)` and then eagerly loading snippets for the current buffer's filetypes (`M._load_lazy_loaded_ft(ft)`), and nothing in the config or in any enabled LazyVim extra consumes the result. But there is **zero functional loss**: snippets work, completion works, no keymap or feature is broken. What remains is 7.8 ms of startup and one dead spec file. 7.8 ms in absolute terms is imperceptible; the "17% of startup" framing inflates a small constant. This is a cleanup finding, not a HIGH.

### Fix Assessment
Deleting `lua/langs/luasnip.lua` is correct and safe — friendly-snippets survives via the blink extra dependency, and custom snippets survive via blink's registry scan (both verified above). **But the fix as written introduces new documentation drift that H5 does not cover.** Six doc lines assert LuaSnip is the snippet engine and would become false: `CLAUDE.md:18` ("loaded by LuaSnip"), `CLAUDE.md:107` ("LuaSnip auto-loads from that directory"), `docs/specs/architecture.md:64` and `:110`, `docs/specs/plugins.md:59`, `docs/specs/customization-guide.md:171`. None of H5's ten sub-claims mention LuaSnip. The fix must carry a doc-edit rider retargeting those lines to blink.cmp's built-in snippets source, or it manufactures the exact defect H5 is about. Also remove the `LuaSnip` entry from `lazy-lock.json` via `:Lazy clean`.

Counter-argument: "17% of a 46 ms startup is a real regression, and dead config that contradicts the docs misleads every session — HIGH." It still stands at LOW: the doc-misleading half is H5's territory (and is being added to it here), leaving H4 with a sub-10 ms cost and no behavioural defect.

---

## H5: CONFIRMED (HIGH)
Original: Documentation drift feeds wrong facts to every session via CLAUDE.md `@`-includes.
Verdict: CONFIRMED — overall HIGH. Ten sub-verdicts below.

### Evidence
**(1) Harpoon — CONFIRMED.** `lua/search/harpoon2.lua:1-44` is a spec table whose every line 3-42 is commented out, returning `{ {} }`. `lazy-lock.json` has no harpoon entry. Documented live at `CLAUDE.md:15` ("fzf, grug-far, harpoon, arrow"), `docs/specs/architecture.md:74`, `plugins.md:106-114`, `keymaps.md:120-126`, `KEYMAPS.md:56-64`. Highest-impact sub-claim: five documents advertise `<leader>a`, `<leader>h`, `<leader>1`–`<leader>5` as bound when they are free.

**(2) Checkmate `keys` wholesale replacement — CONFIRMED, mechanism verified end-to-end.** `checkmate.nvim/lua/checkmate/config/init.lua:537-539` — `if o.keys then config.keys = nil end` — and, critically, `prevent_merge(opts)` **is** invoked for user opts at `:570`, immediately before `config = vim.tbl_deep_extend("force", config, opts)` at `:571`. `lua/misc/checkmate.lua:11-74` supplies `keys`, so all defaults are dropped. `<leader>ta`, `<leader>t]`, `<leader>t[` appear in neither that table nor the (now nil) defaults → unbound. Documented at `plugins.md:233,239` and `keymaps.md:192,198` (grep-located, verbatim: `| \`<leader>ta\` | n | Archive completed |`).

**(3) Metadata merges per-name — CONFIRMED.** `init.lua:546-550` nils only the default entries the user *names*: `for meta_name, _ in pairs(o.metadata) do config.metadata[meta_name] = nil end`. `lua/misc/checkmate.lua:105-122` names only `done`, so default `priority` and `started` survive with `key = "<leader>Tp"` (`defaults.lua:157`) and `key = "<leader>Ts"` (`defaults.lua:169`). Docs say `<leader>tp`/`<leader>ts`.

**(4) `<leader>uz`/`<leader>uZ` — CONFIRMED.** LazyVim `config/keymaps.lua:202-203` — `Snacks.toggle.zoom():map("<leader>wm"):map("<leader>uZ")` / `Snacks.toggle.zen():map("<leader>uz")`. Zoom and zen, not folds. `CLAUDE.md:52` and `keymaps.md:91-92` say "Fold toggles".

**(5) Undocumented behaviour — CONFIRMED.** Grepping `docs/specs` for `gy`, `leader>tx`, `leader>th`, `OilActionsPost`, `no_ignore`, `ctrl-o`, `cancelled`, `on_hold` returns no hits for any of them. All exist: oil `gy` (`lua/ui/oil.lua:119-132`), oil `OilActionsPost` buffer cleanup (`:136-176`), checkmate `<leader>tx`/`<leader>th` and states `- [c]`/`- [/]` (`lua/misc/checkmate.lua:64-93`), fzf Ctrl-remap plus `opts.grep.no_ignore = true`/`hidden = true`/`rg_opts` prepend and `opts.files.no_ignore = true` (`lua/search/fzf.lua:34-66`), C/C++ insert-mode `*` auto-close (`lua/config/autocmds.lua:20-34`).

**(6) `.neoconf.json` — CONFIRMED, low weight.** File exists (glob); `lazy-lock.json` has no `neoconf` match. `architecture.md:108` lists it as `| \`.neoconf.json\` | Neodev/neoconf settings for Lua LSP |` — a description of what the file *is*, not an explicit claim it is consumed. Real but minor.

**(7) CLAUDE.md omissions — SPLIT: debugging.md omission CONFIRMED; extras-list omission DISMISSED.** `CLAUDE.md:128-131` `@`-includes only architecture/plugins/keymaps/customization-guide — `docs/specs/debugging.md` is absent, and CLAUDE.md never mentions dap/debugging anywhere. But `CLAUDE.md:56` scopes its list as "Enabled in `lazyvim.json`", and the dap imports are in `lua/config/lazy.lua:22-23`, not `lazyvim.json:2-18` — so that list is accurate as scoped and is not drift.

**(8) `<Tab>` attribution — CONFIRMED.** Grepping LazyVim `config/keymaps.lua` for `tab>` returns only `<leader><tab>*` (:206-212); no bare normal-mode `<Tab>`. Insert-mode `<Tab>` is unbound by `lua/langs/blink.lua:22`, not by the bufferline map, so `CLAUDE.md:43`'s "Indent/snippet navigation" attributes the loss to the wrong mapping. Caveat for the rewrite: `<Tab>`≡`<C-i>` holds in terminals without an extended-key protocol; the attribution is wrong regardless of terminal.

**(9) Cursor colour — CONFIRMED.** `lua/config/options.lua:29` — `"n-v-c-sm:block-NormalCursor/lCursor"` puts command mode (`c`) on the white `NormalCursor` (`:21`), while `:38` — `"o:block-CommandCursor/lCursor-blinkwait700..."` — applies the yellow `CommandCursor` to operator-pending. `CLAUDE.md:33` claims yellow blinking in command mode: wrong on both counts.

**(10) Branch count — CONFIRMED.** `.git/packed-refs:2-6` lists `macbook`, `macbook-backup`, `macbook-reset`, `main`, `ubuntu-desktop` — five. `customization-guide.md:242` names four, omitting `macbook-backup`.

### Reasoning
Nine of ten sub-claims verify against source; only the extras-list half of (7) fails. The HIGH severity survives the wrong-action test: each major item produces a concrete wrong edit, not merely a stale sentence. A session reading `CLAUDE.md:15` treats harpoon as live and either "repairs" `<leader>a`/`<leader>h` or refuses to reuse those free keys; a session reading `CLAUDE.md:52` restores `<leader>uz` as a fold toggle and silently clobbers Snacks zen; a session reading `plugins.md:233` adds a `<leader>ta` archive binding believing it already exists; a session reading `CLAUDE.md:43` documents or "fixes" completion behaviour that blink already unbinds. Because these four files are `@`-included, the wrong facts are injected into every session unconditionally.

### Fix Assessment
"Update docs" is correct but under-specified for a HIGH. It must be scoped per item, and two additions are required. First, add the LuaSnip doc lines (`CLAUDE.md:18`, `:107`, `architecture.md:64`, `:110`, `plugins.md:59`, `customization-guide.md:171`) as an eleventh item — they are already misleading today (they credit LuaSnip for snippets that blink actually serves) and become outright false if H4's fix lands; neither finding currently owns them. Second, `KEYMAPS.md` is a tracked second keymap document that is never `@`-included and drifts independently; fixing only `docs/specs/` leaves it stale. Correct the `<leader>ta`/`<leader>t]`/`<leader>t[` and `<leader>tp`/`<leader>ts` rows by *deleting or rebinding* — the honest fix for (2)/(3) is either to add the missing lhs entries to `lua/misc/checkmate.lua`'s `keys` table or to document the actual `<leader>Tp`/`<leader>Ts`; silently rewriting the docs to `<leader>T*` leaves the user with an inconsistent lowercase/uppercase prefix split. Drop the extras-list half of (7) from the fix scope.

Counter-argument: "docs drift is cosmetic; nothing executes a markdown file, so this is at most MEDIUM." It still stands at HIGH because `CLAUDE.md`'s `@`-includes make these files executable input to every AI session in this repo, and each named item maps to a specific incorrect code change an agent would make — the drift causes edits, not just confusion.
