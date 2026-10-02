## L7: DOWNGRADED to LOW-note (mechanism confirmed, magnitude unquantified, proposed fix is buggy)
Original: Oil filetype column re-runs `vim.filetype.match` + 2 `require`s per entry per render; cleanup loop is D×B realpath calls.
Verdict: DOWNGRADED to LOW (note). Sub-claim "two requires" DISMISSED. Proposed fix "memoize by extension" FLAGGED AS A BUG.

### Evidence
Per-entry-per-render confirmed — `oil.nvim/lua/oil/view.lua:790-791`:
```lua
  for i, column in ipairs(column_defs) do
    local chunk = columns.render_col(adapter, column, entry, bufnr)
```
`oil/columns.lua:73` `local chunk = column.render(entry, conf, bufnr)` — no cache layer.

Order inside `vim.filetype.match` (runtime `lua/vim/filetype.lua:2901-2934`): full-path `filename[]` → tail `filename[]` → **`match_pattern_sorted(... pattern_sorted_pos ...)`** → `extension[]`. The pattern walk does precede the extension lookup, and `local parent_matches = {}` (`:2920`) is a fresh memo per call. `match_pattern_sorted` (`:2807`) iterates **every** entry of `pattern_sorted_pos`; the `parent_matches` guard (`:2810-2816`) only skips the inner `match_pattern`, not the loop.

Comparator — oil's icon provider prefers mini.icons (`oil.nvim/lua/oil/util.lua:831-836`: `local _, mini_icons = pcall(require, "mini.icons")` … `return mini_icons.get(type == "directory" and "directory" or "file", name)`), and mini.icons is installed as oil's dependency (`lua/ui/oil.lua:8`). `mini.icons/lua/mini/icons.lua:474-486` caches every `get()` result by `category-name`; `:2173-2174`:
```lua
    -- Basename extensions. Prefer this before `vim.filetype.match()` for speed
    -- (as the latter is slow-ish; like 0.1 ms in Neovim<0.11)
```

### Reasoning
The builtin `icon` column already pays this cost — but mini.icons tries an extension table first and caches by name, so it is amortized to once per distinct filename per session. The user's `filetype` column has neither guard, so it is the only uncached `vim.filetype.match` per entry per redraw. That is a real delta, but no user-visible slowness appears anywhere in runtime-facts.md, and mini.icons' own upstream number (~0.1 ms, and it says 0.11 is faster) puts a 200-entry directory at tens of ms — unmeasured here. `require()` of a loaded module is a `package.loaded` table lookup (Lua stdlib), so the "two requires per call" part is noise; hoisting the 7-key `overrides` literal is real but trivial.

### Fix Assessment
Partly wrong. **"Memoize by extension" is a bug**: `vim.filetype.match` resolves `Makefile`, `Dockerfile`, `.bashrc`, `CMakeLists.txt`, `.git/info/attributes` by full-name/pattern (`filetype.lua:2905-2922`) before extension is ever consulted — an extension key collapses all extensionless files to one entry and mis-labels them. Correct fix: cache keyed on the entry's **basename**, exactly as mini.icons does. Hoisting `FIELD_NAME`/`FIELD_TYPE` and `overrides` to file scope is correct and free. Cleanup loop: leave it — `oil.lua:168` already short-circuits on `name ~= "" and not vim.bo[bufnr].modified` before `canonical_path`, and `OilActionsPost` with a `delete` action is a rare user-initiated event.

Counter-argument: one could argue a per-render cost in an interactive file explorer deserves LOW-proper, not a note. It still stands as a note because the same call already happens in the builtin icon column and no measurement exists — flagging an unmeasured 2× on an operation the user has never reported as slow is speculation about magnitude.

---

## L8: CONFIRMED (with a provenance caveat — not re-run this session)
Original: 5 files fail `stylua --check`; stylua is Mason-only, not on the user's PATH.
Verdict: CONFIRMED.

### Evidence
**I have no Bash tool in this session** — the command could not be re-run. Source for the file list and the PATH fact is `context/runtime-facts.md:9`: "stylua 2.5.2 (Mason: `~/.local/share/nvim/mason/bin/stylua`, NOT on user's PATH). `stylua --check .` reports 5 unformatted files: lua/misc/treesitter-context.lua, lua/search/arrow.lua, lua/config/keymaps.lua, lua/config/autocmds.lua, lua/ui/oil.lua."

Divergences characterized by inspection against `stylua.toml` (`indent_type = "Spaces"`, `indent_width = 2`, `column_width = 120`; `quote_style` unset → stylua default `AutoPreferDouble`):
- `lua/search/arrow.lua:8-9` — `leader_key = ';'`, `buffer_leader_key = 'm'` (single quotes → doubles); `:10` `}` with no trailing comma after the `opts` table.
- `lua/config/autocmds.lua:16-17` — `end` then `})`, no trailing comma after the `callback` function (contrast `:33-34`, which has it).
- `lua/ui/oil.lua:40` `sh = "bash"` and `:46` `end` — both missing trailing commas.
- `lua/misc/treesitter-context.lua:5-7` — trailing comments column-aligned with padding spaces; stylua normalizes to a single space.
- `lua/config/keymaps.lua:55-60,61-66` — two hand-split `keymap.set` calls whose single-line forms fit the 120-column limit, so stylua collapses them. (Exact cause not confirmable without running the binary.)

CLAUDE.md, Formatting section: "Run `stylua .` from the config root to format." — assumes PATH availability.

### Reasoning
The formatter is configured, the config documents a PATH-based workflow, and the binary only exists in Mason's bin dir. Inside nvim the gap is invisible (`runtime-facts.md:35` `stylua=1` after Mason's PATH prepend), so conform/`<leader>cf` works; only the documented shell command fails.

### Fix Assessment
Correct. Run `/Users/zcu/.local/share/nvim/mason/bin/stylua .` as one standalone formatting commit, and either add Mason's bin to PATH or change the CLAUDE.md line to the absolute path. No bug risk.

Counter-argument: five cosmetic files is arguably not worth a finding. It stands because the repo declares a formatter config and a formatting instruction that does not execute — the inconsistency is in the documentation, not the whitespace.

---

## L9: CONFIRMED with one sub-claim corrected
Original: tracked cruft — `.neoconf.json`, root `KEYMAPS.md`, boilerplate `README.md`, five undated-frontmatter docs, empty `ref/` and `.tests/`.
Verdict: CONFIRMED; the "tracked" framing for `ref/` and `.tests/` is DISMISSED.

### Evidence
`.neoconf.json:1-15` configures `neodev` and `neoconf` sections. `lazy-lock.json` grep for `neoconf|neodev|lazydev` returns exactly one line — `:20 "lazydev.nvim"`. Neither neoconf.nvim nor neodev.nvim is installed. `lazydev.nvim` grepped for `neoconf`: **no matches** — it does not read the file. In LazyVim, `neoconf` appears only at `extras/lsp/neoconf.lua:6` and `extras/lsp/none-ls.lua:34`; `lazyvim.json:2-18` enables neither extra. No consumer exists.

`README.md` is 4 lines, verbatim LazyVim starter text ("A starter template for [LazyVim]...").

The five docs exist (`docs/2026-02-26-fix-markdown-backticks.md`, `2026-02-28-fix-checkmate-yellow-markers.md`, `2026-02-28-fix-checkmate-gitsigns-conflict.md`, `2026-02-28-disable-gitsigns-for-markdown.md`, `2026-03-01-oil-custom-columns.md`); each opens with `**Date:** …` at line 3 instead of YAML frontmatter. A repo-wide `*.md` grep for their filenames returns hits only inside `docs/reviews/2026-09-06-nvim-config-full/` — nothing else references them.

`.gitignore:2` is `.tests`. `ref/` is not ignored, but git does not track empty directories at all.

### Reasoning
Every documented consumer of `.neoconf.json` is absent, so it is inert configuration that a future session would read as authoritative. The five dated docs are orphans outside `docs/investigations/` and violate the frontmatter rule the repo's own docs standard sets. The two empty directories cannot be "tracked cruft" — git has no empty-directory concept — so that sub-claim is a category error, though the working-tree clutter is real.

### Fix Assessment
Correct as amended: delete `.neoconf.json`; keep `docs/specs/keymaps.md` as the single source and reduce root `KEYMAPS.md` to a pointer (re-derived, not taken from `spec-compliance.md:54`: `KEYMAPS.md:28` reads "Grug-far search & replace in current file (fixed-string, case-insensitive)" while `docs/specs/keymaps.md:69` reads only "grug-far: search/replace in current file" — deleting KEYMAPS.md outright destroys the `-F -i` semantics, so carry that clause across first); rewrite `README.md`; move the five docs to `docs/investigations/` with frontmatter. `git rm` is not applicable to `ref/`/`.tests/` — a plain `rmdir` is the whole operation. `git ls-files` was not run (no Bash) — tracked status for the first three is taken from `runtime-facts.md:55-58`.

Counter-argument: `.neoconf.json` is harmless if the user later installs neoconf. It stands because nothing in `lazyvim.json` moves toward that, and a config file with zero readers is exactly the kind of artifact that misleads the next reader.

---

## L10: DOWNGRADED to LOW-note; the history sub-claim is DISMISSED as unverified
Original: three RHS idioms, two leader spellings, re-spelled `opts`, `:lua` string; `:…<CR>` pollutes history and loses pending count.
Verdict: DOWNGRADED to LOW (style note). "Pollutes `:` history" — DISMISSED (unverified). "noice popup flash" — DISMISSED (guard found).

### Evidence
Real difference, `runtime/doc/map.txt:346-351`:
```
- Because <Cmd> avoids mode-changes (unlike ":") it does not trigger
  |CmdlineEnter| and |CmdlineLeave| events. This helps performance.
- For the same reason, |keycodes| like <C-R><C-W> are interpreted as plain,
  unmapped keys.
- The command is not echo'ed, no need for <silent>.
```
Count translation, `runtime/doc/cmdline.txt:823-829`: "When giving a count before entering \":\", this is translated into: `:.,.+(count - 1)`".

Guard found for the noice claim — noice's only cmdline autocmds are `noice.nvim/lua/noice/util/hacks.lua:83-101`, and both bodies are gated on `if event.match == "/" or event.match == "?"`. A `:`-mapping triggers the autocmd but the callback does nothing.

Guard found for the count claim — oil registers `Oil` with `count = true` (`oil.nvim/lua/oil/init.lua:1185`), and `args.count` is consumed only inside `if not float and (args.smods.vertical or ... )` (`:1159-1161`). A bare `:Oil` ignores it. Same for `:BufferLineMoveNext/Prev` and `:bufdo bd`.

`<Leader>` vs `<leader>`: `runtime-facts.md:12` records `maparg("<leader>bp")` returning the mapping written as `<Leader>bp` in `keymaps.lua:63` — empirically the same key. Cosmetic only.

### Reasoning
The mode-switch difference is real and documented, but every downstream consequence the finding asserted is blocked by a guard: noice ignores `:`, and none of the mapped commands read a count. I could not verify the history claim from `cmdline.txt` and will not confirm it — Vim only records a cmdline when a key was typed during it, which is precisely not the case for a fully-mapped rhs, so the claim is more likely false than true. What survives is genuine style inconsistency plus one real maintainability defect: `keymaps.lua:72` embeds Lua inside a `[[:lua …<CR>]]` string, invisible to lua_ls and stylua.

### Fix Assessment
Directionally correct but over-scoped. Normalizing all `:cmd<Return>` to `<cmd>cmd<cr>` is a large mechanical diff for zero observed behavior change — do it only if the user wants consistency for its own sake. The one change that pays for itself: convert `keymaps.lua:69-74` to a Lua function (`function() require("grug-far").open({ prefills = { paths = vim.fn.expand("%"), flags = "-F -i" } }) end`), which restores type-checking and formatting. Note the conversion is not a pure no-op — `<cmd>` mappings do not fire `CmdlineEnter`, so any user autocmd on that event would stop running.

Counter-argument: one could keep this at LOW-proper on the grounds that the count/history behavior might bite a future mapping. It stands as a note because for the seven mappings that actually exist, the guards above make the delta zero, and severity should describe this code, not hypothetical future code.

---

## L11: DOWNGRADED to LOW-note (terminal claim overstated); `<C-y>` sub-claim CONFIRMED
Original: `<C-.>`/`<C-,>` need a CSI u terminal; `<C-y>` also accepts and is undocumented.
Verdict: DOWNGRADED to LOW (note) for the terminal half; CONFIRMED for the `<C-y>` half.

### Evidence
`runtime/doc/tui.txt:157-168`:
```
At startup Nvim will query your terminal to see if it supports the "CSI u"
encoding by writing the sequence >
        CSI ? u CSI c
...
If your terminal does not support "CSI u" then Nvim will instead enable the
"modifyOtherKeys" encoding by writing the sequence >
        CSI > 4 ; 2 m
```
`<C-y>` arrives from **two** independent sources, neither overridden by the user:
- blink's own `default` preset — `blink.cmp/lua/blink/cmp/keymap/presets.lua:10` `['<C-y>'] = { 'select_and_accept', 'fallback' }` (the preset `lua/langs/blink.lua:5` selects).
- LazyVim's blink extra — `extras/coding/blink.lua:104` `["<C-y>"] = { "select_and_accept" }` (deep-merged; the user's table has no `<C-y>` key, so it survives).

Note the same preset file (`:17-18`) binds `<C-b>`/`<C-f>` to scroll-docs; `lua/langs/blink.lua:9,24` repurposes `<C-f>` to accept and neutralizes `<C-b>`. Net: **two** accept keys, `<C-f>` and `<C-y>` (`<CR>` is neutralized at `blink.lua:21`), while the docs list only `<C-f>`.

blink applies keys with `apply.lua:189-210` — plain `nvim_set_keymap` / `nvim_buf_set_keymap`, no representability check, so an unresolvable key silently binds and never fires.

### Reasoning
Neovim does not passively wait for a kitty-protocol terminal — it queries for CSI u and, failing that, *unconditionally writes the modifyOtherKeys enable sequence*. Any terminal honoring either (kitty, WezTerm, Ghostty, iTerm2 ≥3.5, modern xterm, Alacritty) delivers `<C-.>`/`<C-,>` distinctly. The failure set is narrow (macOS Terminal.app and similar), and the user's terminal is not recorded in `runtime-facts.md`, so the impact is conditional and unmeasured — "require a CSI u terminal" is true but the framing implied the common case. The `<C-y>` gap is unconditional and squarely a docs defect: `docs/specs/plugins.md` lists `<C-f>` as *the* accept key while two keys accept.

### Fix Assessment
"Document or drop" is right for `<C-y>` — add it to the blink table in `docs/specs/plugins.md` and `docs/specs/keymaps.md`, or add `["<C-y>"] = { "fallback" }` to `lua/langs/blink.lua` alongside the existing `<C-b>` neutralizer. **Do not "drop" `<C-.>`/`<C-,>`** on terminal grounds without first establishing the user's terminal; if they work today, removing them is a regression.

Counter-argument: if the user is on Terminal.app, the scroll keys are dead and this is a real bug, not a note. It stands as a note because that premise is unverified and the fix direction reverses depending on it — a note that names the dependency is more useful than a confident wrong verdict.

---

## L12: DOWNGRADED to LOW-note
Original: six micro-observations (a)-(f).
Verdict: DOWNGRADED to LOW-note — 4 of 6 sub-claims hold; (b) and (c) DISMISSED.

### Evidence
**(a) CONFIRMED.** `LazyVim/lua/lazyvim/config/options.lua:91` ends `..., "skiprtp", "folds" }`; `lua/config/options.lua:120` ends `..., "globals", "skiprtp" }` — `"folds"` absent. `vim.opt.sessionoptions =` is assignment, not append, and the user file loads after LazyVim's — grounded empirically by `runtime-facts.md:24` (`cursorline=false, scrolloff=3, updatetime=50` post-VeryLazy) vs LazyVim's `true/4/200` at `:44`. Impact is confined to persistence.nvim, which `runtime-facts.md:31` records as installed but not loaded at startup.

**(b) DISMISSED — guard found.** gitsigns only reacts to an explicit `false`: `gitsigns.nvim/lua/gitsigns/attach.lua:378` `if config.on_attach and config.on_attach(cbuf) == false then`. LazyVim's `on_attach` (`plugins/editor.lua:152-187`) is a body of `map(...)` calls ending at `:186` `map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "GitSigns Select Hunk")` — it returns nil, never `false`. Swallowing its return is a no-op. Style-only.

**(c) DISMISSED — no field is lost.** The wholesale-replace mechanism is real (`checkmate.nvim/lua/checkmate/config/init.lua:546-550` nils `config.metadata[meta_name]` before merge). But `config/defaults.lua:173-187` defines `done` with exactly seven fields — `aliases`, `style`, `get_value`, `key`, `on_add`, `on_remove`, `sort_order` — and `lua/misc/checkmate.lua:107-121` supplies **all seven**. The only deltas are deliberate: `get_value` drops ` %H:%M`, `key` is `<leader>td` vs default `<leader>Td`.

**(d) CONFIRMED, all three.**
- `checkmate.lua:7` `log = {}` — defaults are `log = { level = "warn", use_file = true }` (`defaults.lua:17-20`); `log` is not in `prevent_merge`, so `vim.tbl_deep_extend("force", config, opts)` (`config/init.lua:571`) recurses and an empty source table changes nothing.
- `treesitter-context.lua:3` `enabled = true` — lazy.nvim's default. Grepping all of LazyVim finds `nvim-treesitter-context` only at `extras/ui/treesitter-context.lua:3` and a rename map in `util/plugin.lua:41`; that extra is absent from `lazyvim.json:2-18`, so the user's spec is the sole spec and there is nothing to counteract.
- `options.lua:135` `vim.diagnostic.enable(true)` — runtime `lua/vim/diagnostic.lua:418` `local diagnostic_disabled = {}` (empty = all enabled), and `:2496-2501` sets it back to `{}` for `enable == true`. Identity operation at startup.

**(e) CONFIRMED, plus an unstated side effect.** `keymaps.lua:5` sets `clipboard = "unnamedplus"`, so `keymaps.lua:6` `<C-c>` → `[["+y]]` targets the register `y` already writes; `runtime-facts.md:16,22` confirms both. Not in the finding: line 5 sets `unnamedplus` **unconditionally**, overriding LazyVim's SSH-aware guard (`runtime-facts.md:22`) — over SSH this re-enables OSC 52 clipboard traffic LazyVim deliberately skips. Also `<C-c>` in visual mode normally cancels the selection; that behavior is gone.

**(f) CONFIRMED.** `oil.lua:4-5` `---@module 'oil'` / `---@type oil.SetupOpts` are followed by a blank line, a comment, and then `dependencies = {...}` at `:8`. LuaLS binds `---@type` to the next field, so it types `dependencies`. The spec configures oil through `config = function()` (`:11`) calling `oil.setup({...})` (`:49`), which the annotation never reaches. Annotation-only; zero runtime effect.

### Reasoning
Two of six sub-claims do not survive re-reading. (b) asserts a swallowed return matters without checking that the wrapped function ever returns a value — it does not. (c) asserts dropped default fields without diffing the default entry — the user reproduced it field-for-field. The remaining four are accurate; (a) is the only one with any behavioral consequence, and only when persistence.nvim restores a session.

### Fix Assessment
(a) Delete `options.lua:120` and inherit LazyVim's — smaller diff than appending `"folds"`, and it stops the next LazyVim change from diverging again. (b) Optional tidy: `return orig_on_attach(bufnr)`. (c) **No change.** A "fix" that removed fields believing they would be inherited would break `on_add`/`on_remove`, since `config/init.lua:548` nils the default entry before merging. (d) Delete the three no-op lines. (e) Delete `keymaps.lua:6`; separately decide whether the unconditional `unnamedplus` on `:5` is wanted over SSH. (f) Move the two annotations directly above the `oil.setup({` argument, or delete them.

Counter-argument: (b) could be defended as a latent bug should LazyVim ever return `false`. It stands as dismissed because a finding must describe current behavior; the speculative version belongs in the fix note, which is where I put it.

---

## Provenance
Verified this session: every `file:line` cited in the Evidence blocks above was opened and read in this session.

Not verified this session (**no Bash tool was available**): the `stylua --check` file list, `which stylua`, the 362-line `KEYMAPS.md` diff, and git-tracked status of `.neoconf.json`/`KEYMAPS.md`/`README.md`/the five dated docs — all taken from `context/runtime-facts.md:9,55-58`. Whether `:cmd<CR>` from a silent mapping enters `:` history — not resolvable from `cmdline.txt`; treated as unverified, not confirmed. The user's terminal emulator and its CSI u / modifyOtherKeys support (L11) — not recorded anywhere in the repo.
