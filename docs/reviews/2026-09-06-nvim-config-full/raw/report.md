---
title: Deep code review — full Neovim config (Phase 7 report)
created: 2026-09-06
updated: 2026-09-06
status: draft
topics:
  - code-review
  - nvim-config
  - lazyvim
---

# Review Summary

| Field | Value |
|-|-|
| Diff | Full-tree review of /Users/zcu/.config/nvim at commit 5a320bc (branch macbook-reset); no diff — every file treated as changed |
| Files reviewed | 31 Lua files (1,283 lines), lazyvim.json, .neoconf.json, snippets/*.json, CLAUDE.md, docs/specs/*.md, KEYMAPS.md |
| Change size | 1,283 Lua lines (not oversized) |
| Review depth | Deep (always) |
| Agents dispatched | 7 specialists + 6 deep-dives + 11 challengers + fact-checker + re-verifiers |
| Raw findings | 98 (correctness 9, architecture 13, security 2, quality 18, baseline 22, data-contract 10, spec-compliance 24) |
| Deduplicated findings | 42 (39 from synthesis after merging L4 into M21 + 3 new from deep-dives: M21, M22, M23) |
| Cross-review | 42 challenged (11 challenger batches): 16 confirmed, 25 downgraded, 1 dismissed (M16); of the downgrades, 6 reduced to notes/thoughts |
| Final severity | High 2 (H1, H5) · Medium 12 (H2, H3, H6, H7, M1, M7, M8, M9, M10, M13, M14, M21, M23) · Low 16 · Notes 6 · Dismissed 1 |
| Fact-check | see Phase 6 section |
| Verdict | APPROVE — no Critical findings. Two High findings are fix-before-next-edit items; the config works today. |

Skipped agents: C++ Performance (Lua codebase). Spec Compliance ran against the project's own docs as the spec.

Environment facts used throughout (verified by headless `nvim` runs on 2026-09-06): Neovim v0.11.4 via `bob`; LazyVim 16.0.0 (commit c10948c5, 2026-06-02); lazy.nvim `defaults.lazy = false`; startup 46 ms; `timeoutlen = 300`; after VeryLazy: `<leader>bp` → `BufferLineMovePrev`, `<leader>bP` nil, `n` → `nzz`, `s` → Flash, `sv` → `:vsplit`, `colors_name = "lume"`, tokyonight loaded, LuaSnip loaded, blink `snippets.preset = "default"`, all five `*Cursor` highlight groups empty, `formatoptions = "jtqnl"`.

---

# Critical — Blocks Merge

None.

---

# High Priority

### H1: Custom cursor highlight groups are empty at runtime — the documented yellow insert cursor does not exist
**Location:** `lua/config/options.lua:21-25` (definitions), `:28-39` (guicursor), `lua/ui/colorscheme.lua:6-11`
**Type:** risk
**Found by:** Architecture, Baseline (independently: Quality challenger F)
**Challenged:** Confirmed HIGH by Challenger H
**Verified:** CONFIRMED — main session ran headless nvim: `nvim_get_hl(0,{name="NormalCursor"})` and the other four groups return `{}` after VeryLazy; `Cursor` is lume's, `lCursor` is Neovim's built-in.

options.lua runs at LazyVim init and defines five groups. LazyVim's default `colorscheme` option then loads tokyonight (LazyVim `config/init.lua:13-15`, applied at `:250-256`), which sets `vim.g.colors_name`. lume's `config` at priority 1000 then runs `colorscheme lume`; lume's `load()` executes `hi clear` because `colors_name` is set (`lume/lua/lume/init.lua:17-19`), and `:hi clear` "removes all highlighting for groups added by the user" (syntax.txt:4880-4881). lume never defines the five groups. `Comment`/`@comment` survive only because colorscheme.lua:9-10 re-sets them after the colorscheme command. Effect: `guicursor` points at empty groups, so the terminal's default cursor colour is used in every mode; CLAUDE.md:33 ("Yellow blinking in insert/replace/command, white in normal") is false at runtime.

**Fix (deep-dive and challenger H both rated SOUND):**
```lua
-- lua/ui/colorscheme.lua
return {
  { "LazyVim/LazyVim", opts = { colorscheme = "lume" } },
  {
    "danfry1/lume",
    lazy = true,
    opts = {
      custom_highlights = {
        Comment = { fg = "#75d7b3", italic = true },
        ["@comment"] = { fg = "#75d7b3", italic = true },
        NormalCursor = { fg = "#1e1e2e", bg = "#ffffff" },
        InsertCursor = { fg = "#1e1e2e", bg = "#ffd400" },
        ReplaceCursor = { fg = "#1e1e2e", bg = "#ffd400" },
        CommandCursor = { fg = "#1e1e2e", bg = "#ffd400" },
      },
    },
  },
}
```
Delete `options.lua:21-25`. Mechanism: lazy.nvim's `ColorSchemePre` hook loads lume and runs `require("lume").setup(opts)` before `colors/lume.lua` is sourced (lazy.nvim `core/loader.lua:30-34`, `:515-528`, `:361-388`); lume merges `custom_highlights` last (`theme.lua:71-82`); `@comment` is a plain table, not a link (`groups/syntax.lua:118`), so the colour applies; the highlights are re-applied on every later `:colorscheme lume`. Optional hardening: `{ "folke/tokyonight.nvim", enabled = false }` and `{ "catppuccin/nvim", enabled = false }` in disabled.lua — LazyVim references tokyonight only in the default colorscheme function this replaces; catppuccin's bufferline hook is guarded by `colors_name`. Land together with M12 (guicursor mode letters) so `CommandCursor` reaches command-line mode.

### H5: Documentation drift feeds wrong facts to every session through CLAUDE.md `@`-includes
**Location:** `CLAUDE.md`, `docs/specs/{architecture,plugins,keymaps,customization-guide}.md`, `KEYMAPS.md`
**Type:** risk
**Found by:** Spec-compliance (24 rows), Quality, Architecture, Baseline
**Challenged:** Confirmed HIGH by Challenger A (9 of 10 sub-claims confirmed; the "extras list omits dap" half of item 7 dismissed because CLAUDE.md:56 scopes the list to lazyvim.json)
**Verified:** CONFIRMED — main session read every cited doc line and the checkmate merge code.

Eleven verified drifts:
1. Harpoon documented as active in CLAUDE.md:15, architecture.md:74, plugins.md:106-114, keymaps.md:120-126, KEYMAPS.md:56-64; `lua/search/harpoon2.lua` is fully commented out (commit 941603d, 2026-06-08) and harpoon is not in lazy-lock.json.
2. Checkmate replaces its default `keys` wholesale when a user `keys` table exists (`checkmate/config/init.lua:537-539`, invoked at `:570`), so documented `<leader>ta`, `<leader>t]`, `<leader>t[` (plugins.md:233,239; keymaps.md:192,198) are unbound.
3. Checkmate `metadata` merges per-name (`init.lua:546-550`); `@priority`/`@started` keep default keys `<leader>Tp`/`<leader>Ts` (`defaults.lua:157,169`); docs say `<leader>tp`/`<leader>ts`.
4. `<leader>uz`/`<leader>uZ` are Snacks zen/zoom (LazyVim `config/keymaps.lua:202-203`); CLAUDE.md:52 and keymaps.md:91-92 say "fold toggles".
5. Undocumented: oil `gy` (oil.lua:119-132, commit 5de9fee), checkmate `<leader>tx`/`<leader>th` and on-disk states `- [c]`/`- [/]` (checkmate.lua:64-93, commit 3922f2b), fzf Ctrl actions + `no_ignore`/`hidden` defaults (fzf.lua:29-68, commits 276cc2b/cd512b0), C/C++ insert-mode `*` map (autocmds.lua:19-34), oil buffer-cleanup autocmd (oil.lua:136-176, commit ed5fb23).
6. `.neoconf.json` documented as live (architecture.md:108); neoconf.nvim is not installed.
7. CLAUDE.md `@`-list (:128-131) omits `docs/specs/debugging.md`; CLAUDE.md never mentions the debugger or the `<leader>d` prefix.
8. CLAUDE.md:43 says `<Tab>` replaced "Indent/snippet navigation"; LazyVim binds no bare normal-mode `<Tab>`; the real loss is `<C-i>` (jumplist forward).
9. CLAUDE.md:33 says yellow cursor in command mode; options.lua:29 puts `c` under the white group and :38 uses `o:` (operator-pending).
10. customization-guide.md:242 lists four branches; five exist (`macbook-backup` missing).
11. Six lines credit LuaSnip as the snippet engine (CLAUDE.md:18,107; architecture.md:64,110; plugins.md:59; customization-guide.md:171); blink.cmp serves snippets itself (see H4).
Also: `KEYMAPS.md` (root) is a never-included duplicate of docs/specs/keymaps.md (362 diff lines); spec `updated: 2026-05-26` predates every drift commit; architecture.md line refs stale (`lazy.lua:36-54` → `30-57`; `18-26` → `18-29`).

**Fix:** update the four spec docs and CLAUDE.md per item; for items 2-3 either add the missing checkmate keys to `lua/misc/checkmate.lua` or document the real `<leader>T*` keys (do not silently rewrite docs to a mixed-case prefix); add `@docs/specs/debugging.md` to CLAUDE.md; reduce KEYMAPS.md to a pointer after carrying its one unique detail (`-F -i` semantics for `<leader>r`) into docs/specs/keymaps.md; bump `updated:`.

---

# Medium Priority

### M13: C/C++ insert-mode `*` auto-close map — typeahead race, no context guard, broken undo/dot-repeat
**Location:** `lua/config/autocmds.lua:19-34`
**Type:** risk
**Found by:** Correctness (guard only); Deep-dive autocmds-star (typeahead, undo split, mapping leak)
**Challenged:** Downgraded to MEDIUM by Challenger J1 (proposed HIGH rejected: the typeahead race needs `*` and the next key in the same input batch; the Doxygen `/**` case cannot mis-fire because after the first expansion the char before the cursor is a space)
**Verified:** CONFIRMED mechanism — main session read vimfn.txt:2204-2208 (feedkeys appends to typeahead without `i`), insert.txt:342-344 and :382 (`<Left>` splits undo; `<C-g>U` fix), map.txt:194-195 (buffer-local maps survive filetype change).

Three defects in one mapping. (1) `nvim_feedkeys(close, "n", false)` and `nvim_feedkeys("*", "n", false)` (:28, :30) omit the `i` flag, so the fed keys land AFTER any keys already in typeahead; when `*` and the next key arrive in one input batch (fast typing during an LSP or treesitter stall), `int *p` becomes `int p*` — the else branch has the same exposure for every `*`. (2) The guard checks only that the previous byte is `/`, so `"src/*.c"`, `// http://x/*`, and `*` typed after `/` inside an open `/* … */` expand to `/*  */`. (3) Bare `<Left>` splits the insert for undo and dot-repeat on every expansion (deterministic); `<C-g>U<Left>` is the documented idiom (mini.pairs uses it, `mini/pairs.lua:421-427`). Also: no augroup; the buffer-local map leaks if `:set ft=` changes.

**Fix:** rewrite as an `expr = true` insert mapping returning `"*  */<C-g>U<Left><C-g>U<Left><C-g>U<Left>"` when the previous char is `/` and the cursor is not inside a `string`/`comment` treesitter capture (`vim.treesitter.get_captures_at_pos(0, row, col-1)`, cf. LazyVim `util/mini.lua:113`), else `"*"`; register under an augroup. `vim.keymap.set` sets `replace_keycodes = true` for expr maps so `<C-g>U<Left>` is translated. The treesitter guard degrades open (returns `{}` with no highlighter), which matches today's behaviour but is not a guarantee.

### H2 (downgraded from HIGH): `sv` shares the `s` prefix with Flash
**Location:** `lua/config/keymaps.lua:17`; LazyVim `plugins/editor.lua:38`
**Type:** suggestion | **Found by:** Correctness, Baseline | **Challenged:** Downgraded to MEDIUM by Challenger A (bounded: 300 ms only if the user pauses; only `v`-initial targets; result is a reversible split) | **Verified:** CONFIRMED — both maps live in normal mode (headless maparg), `timeoutlen = 300`.
Neovim waits `timeoutlen` after `s` to disambiguate; `sv` typed within 300 ms opens a split instead of jumping to a `v`. **Fix:** delete `sv`; LazyVim already provides `<leader>|` (`<C-w>v`) and `<leader>wv`. Do not disable Flash `s` — keymaps.lua:76-78 shows `s` was deliberately re-enabled.

### H3 (downgraded from HIGH): `custom_commentstring` override disables treesitter-aware comments
**Location:** `lua/misc/mini-comment.lua:6-10`
**Type:** suggestion | **Found by:** Correctness, Architecture, Data-contract, Spec-compliance | **Challenged:** Downgraded to MEDIUM by Challenger I (wrong markers appear immediately; `u` reverts) | **Verified:** CONFIRMED — main session read mini/comment.lua:359-366,461-462, LazyVim extra :7-9, ts-context config.lua:66-67, runtime ftplugin/c.lua:2.
The override returns non-nil, so both LazyVim's ts-context lookup and mini.comment's own treesitter walk are unreachable: `gcc` in JSX gives `// %s` (should be `{/* %s */}`), in `<style>` gives `<!-- %s -->`, in a ```lua fence gives `<!-- %s -->`. Root cause of the override: ts-context-commentstring hardcodes `c = '/* %s */'` while Neovim's ftplugin sets `// %s`; the string short-circuits, so LazyVim's `or vim.bo.commentstring` fallback never runs — `languages.c` is the only working route.
**Fix (deep-dive: INCOMPLETE until paired with M14; challenger I: correct):** delete `lua/misc/mini-comment.lua`; add `lua/misc/ts-context-commentstring.lua`: `return { "JoosepAlviste/nvim-ts-context-commentstring", opts = { languages = { c = "// %s" } } }` (deep-merges with the extra's `enable_autocmd = false`, stays lazy, `setup` runs on first require). Must land with M14 or comment-continuation stripping disappears.

### H6: `vim.keymap.del` in keymaps.lua is an all-or-nothing failure point
**Location:** `lua/config/keymaps.lua:53-54, 108-109`
**Type:** risk | **Found by:** Architecture, Baseline | **Challenged:** Downgraded to MEDIUM by Challenger J1 — the failure is notified via `M.error`, not silent; the load order is structural (lazy.nvim registers event handlers in `Loader.setup()` before `Loader.startup()`, so bufferline's VeryLazy hook always fires before LazyVim's keymaps hook); triggering E31 needs an upstream rename | **Verified:** CONFIRMED mechanism — `vim.keymap.del` on a missing map throws `E31` (headless); LazyVim wraps `require("config.keymaps")` in one `LazyVim.try` (`config/init.lua:286-291`) that reports and does not rethrow, so a throw at :53 skips the 9 `vim.keymap.set` calls in :55-109.
The override wins by a guaranteed order, but the delete calls still couple keymaps.lua to two keys LazyVim could rename. LazyVim already ships `[B`/`]B` for MovePrev/MoveNext (`plugins/ui.lua:16-17`), so the user keys are aliases. **Fix (deep-dive keymaps: SOUND):** in `lua/ui/bufferline.lua` `keys`: `{ "<leader>bp", "<Cmd>BufferLineMovePrev<CR>", desc = "Move buffer prev" }`, `{ "<leader>bn", "<Cmd>BufferLineMoveNext<CR>", desc = "Move buffer next" }`, `{ "<leader>bP", false }`; delete keymaps.lua:53-66 (lazy.nvim dedupes keys by id with the later spec winning, `handler/keys.lua:80-87`; `false` removes). For :108-109 use `pcall(vim.keymap.del, ...)` — Snacks.toggle sets those via `opts.map`, not a `keys` table, and which-key hides the entry automatically (`real = true`).

### H7 (downgraded from HIGH): Literal grep (`<leader>\``) drops the `-e` terminator
**Location:** `lua/search/fzf.lua:16`
**Type:** suggestion | **Found by:** Correctness, Data-contract; Deep-dive fzf | **Challenged:** Downgraded to MEDIUM by Challenger J2 (narrow input class; `<leader>/` as workaround) | **Verified:** CONFIRMED — fzf-lua `defaults.lua:974-975` ends `--max-columns=4096 -e`; `make_entry.lua:414-423` appends the query positionally.
A query starting with `-` is parsed by rg as a flag: invalid flags → empty result list; valid flags (`--files`) → unrelated output. `--max-columns=4096` is also dropped. **Fix:** end the string with ` --max-columns=4096 -e`. The `ctrl-g` regex/literal toggle is unaffected.

### M1: `<leader>r` "Search and Replace Current File" widens to the whole cwd for unnamed buffers; paths with spaces split
**Location:** `lua/config/keymaps.lua:72`; `lua/ui/oil.lua:83`
**Type:** risk | **Found by:** Security (2), Data-contract | **Challenged:** Confirmed MEDIUM by Challenger B | **Verified:** CONFIRMED — grug-far `getArgs.lua:86-93`, `utils.lua:388-413`, `replace.lua:144`.
`vim.fn.expand("%")` is `""` in an unnamed buffer; grug-far appends path args only when non-empty, so rg searches the whole cwd under a keymap labelled "Current File"; `-F -i` makes it case-insensitive; only empty-string replacements are confirmed. `splitPaths` splits on unescaped spaces. Oil `gs` passes `get_current_dir()` unguarded (nil for `oil-trash://`). **Fix:** guard on `vim.bo.buftype == ""` and non-empty `expand("%")` (the sibling in `lua/search/grug-far.lua:10` already does), escape with `:gsub(" ", "\\ ")` (grug-far's own idiom, `utils.lua:705`; do NOT use `fnameescape`), write as a Lua function; guard `get_current_dir()` in oil `gs`.

### M7: `<leader>cp` is `:LspStop` everywhere except markdown, where it is Markdown Preview; `:LspStop` scope is session-wide
**Location:** `lua/config/keymaps.lua:106`; LazyVim `extras/lang/markdown.lua:82-89`
**Type:** suggestion | **Found by:** Baseline; Deep-dive keymaps | **Challenged:** Confirmed MEDIUM by Challenger C; the separate M22 ("`:LspStop` does not stop the client") was downgraded to LOW by Challenger J1 with its core claim dismissed, and is folded in here | **Verified:** CONFIRMED — `ft` keys become buffer-local (lazy.nvim `handler/keys.lua:151-163`); `:LspStop` with no args collects `vim.lsp.get_clients()` with no bufnr filter (nvim-lspconfig `plugin/lspconfig.lua:173-178`) and `vim.lsp.enable(name, false)` stops every matching client (nvim 0.11.4 `lsp.lua:625-629`) — the lspconfig comment "current buffer" contradicts its code.
Main-session correction: the keymaps deep-dive claimed the client keeps running; it does not — `lsp.enable(name, false)` calls `client:stop()`. What the desc undersells is scope: all clients in the session stop and their configs stay disabled until `:LspStart`. **Fix:** move to a free key with an accurate desc, or bind `vim.lsp.stop_client(vim.lsp.get_clients({ bufnr = 0 }))` for a buffer-scoped stop; add the markdown-preview row to keymaps.md.

### M8: Oil `"<Nop>"` for `<C-h>` shadows window navigation inside oil buffers
**Location:** `lua/ui/oil.lua:73-74`
**Type:** suggestion | **Found by:** Baseline | **Challenged:** Confirmed MEDIUM by Challenger C | **Verified:** CONFIRMED — oil `keymap_util.lua:67-73` skips only falsy rhs; `"<Nop>"` creates a buffer-local map in modes n/v/o/s that beats LazyVim's global `<C-h>` → `<C-w>h`.
**Fix:** `["<C-h>"] = false, ["<C-t>"] = false` (oil's documented disable idiom, `config.lua:58`); also cleans the `g?` help listing.

### M9: Oil delete-buffer cleanup never fires for directory deletes
**Location:** `lua/ui/oil.lua:160-171`
**Type:** suggestion | **Found by:** Correctness; Deep-dive oil | **Challenged:** Confirmed MEDIUM by Challenger J1 | **Verified:** CONFIRMED — oil emits one `delete` action per entry with `entry_type` and `url = parent .. name` (`mutator/init.lua:172-179`); recursion is filesystem-level; `delete_to_trash` keeps `type = "delete"` (`adapters/files.lua:621-625`).
The equality test cannot match children, so the freeze the autocmd exists to prevent still happens for directory deletes. **Fix:** for `entry_type == "directory"`, also wipe buffers whose canonical name starts with `target .. "/"`. The target side resolves normally (its grandparent still exists); the BUFFER side is the problem — a descendant's parent is gone, so `canonical_path(name)` falls to `vim.fs.normalize` and a symlinked ancestor breaks the compare. Realpath the nearest existing ancestor of the buffer name and rebuild the tail; keep the `"/"` separator guard (oil's own `update_moved_buffers` at `util.lua:285` omits it — precedent for the technique, not for the missing guard).

### M10: Oil `gs` calls two deprecated grug-far functions; the draft fix was wrong
**Location:** `lua/ui/oil.lua:94, 96`
**Type:** suggestion | **Found by:** Data-contract | **Challenged:** Confirmed MEDIUM by Challenger C, fix corrected | **Verified:** CONFIRMED — `vim.deprecate` at grug-far.lua:502, :516; LazyVim silences deprecation warnings (`vim.g.deprecation_warnings = false` → `vim.deprecate = function() end`, `config/init.lua:343-345`), so the break will arrive unannounced.
**Fix (corrected):**
```lua
local inst = grug_far.get_instance("explorer")
inst:open()
inst:update_input_values(prefills, false)
```
(`update_prefills` does not exist; the method is `update_input_values(values, clearOld)`, `instances.lua:397-399`.)

### M14: mini-comment autocmds are positional `opts` entries created at spec-parse time; global `formatoptions` mutation; dead patterns
**Location:** `lua/misc/mini-comment.lua:11-23`
**Type:** suggestion | **Found by:** Correctness, Architecture, Quality, Baseline, Data-contract; Deep-dive mini-comment | **Challenged:** Confirmed MEDIUM by Challenger I | **Verified:** CONFIRMED — `formatoptions = "jtqnl"` globally (headless); `.h`/`.hpp` map to `c`/`cpp`.
(1) lazy.nvim runs spec modules at `setup()`; the autocmds exist regardless of `event`/`enabled`, their ids leak into `MiniComment.setup`. (2) `change_detection` (on by default) re-runs the module on every config save → duplicate autocmds, no augroup. (3) `h`/`hpp` are never filetypes; the c/cpp autocmd is redundant (ftplugin already sets `// %s`). (4) `vim.opt` is `:set`: it writes the current buffer's flags minus `c,r,o` into the GLOBAL default — after any `.ts` buffer (`ftplugin/typescript.vim:17`) the global loses `t` (latent: no `textwidth` set today).
**Fix:** delete the c/cpp autocmd; add to `lua/config/autocmds.lua`:
```lua
local grp = vim.api.nvim_create_augroup("user_no_comment_continue", { clear = true })
vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
  group = grp,
  callback = function() vim.opt_local.formatoptions:remove({ "c", "r", "o" }) end,
  desc = "Disable new line comment continuation",
})
vim.opt_local.formatoptions:remove({ "c", "r", "o" }) -- initial [No Name] buffer (autocmds.lua loads at VeryLazy)
```

### M21 (new): `<leader>ba` uses `:bufdo bd`, which the docs forbid
**Location:** `lua/config/keymaps.lua:50`
**Type:** suggestion | **Found by:** Deep-dive keymaps | **Challenged:** Confirmed MEDIUM by Challenger J1 | **Verified:** CONFIRMED — windows.txt:846-847 "{cmd} must not delete buffers"; :840-841 "When an error is detected on one buffer, further buffers will not be visited"; `Snacks.bufdelete.all()` exists (`bufdelete.lua:96`), handles modified buffers with a non-aborting prompt (`:54-57`), and LazyVim binds no delete-all key (`<leader>bd`/`bo`/`bi`/`bD` only).
**Fix:** `function() Snacks.bufdelete.all() end`. (Whether a Cancel on the `'confirm'` dialog counts as a halting error was not confirmed from the docs; the plain E89 path already establishes the halt.)

### M23 (new): `"v"` mode on printable-key maps hijacks Select mode
**Location:** `lua/config/keymaps.lua:42-43` (`p`/`P` swap), `:84` (`q` disable)
**Type:** suggestion | **Found by:** Deep-dive keymaps | **Challenged:** Confirmed MEDIUM by Challenger J1 | **Verified:** CONFIRMED — map.txt:424-426 "Mapping a printable character in Select mode may confuse the user. It's better to explicitly use :xmap and :smap"; `vim.snippet` enters Select mode on non-empty tabstops (`snippet.lua:319-326`, `o<c-g>`), and blink's default preset uses `vim.snippet`.
Expected manifestation (derived, not observed): typing `param` over a placeholder yields `Param`; `q` is swallowed. The p/P swap itself is correct in intent (visual `P` already preserves the unnamed register). **Fix:** `"x"` for :42-43; `{ "n", "x" }` for :84. Leave `<C-c>` at :6 alone (non-printable).

---

# Low Priority

### H4 (downgraded from HIGH): LuaSnip loads eagerly (~7.8 ms) and nothing reads it
**Location:** `lua/langs/luasnip.lua:1-11` | **Found by:** Quality, Architecture, Baseline, Data-contract, Spec-compliance | **Challenged:** Downgraded to LOW by Challenger A (zero functional loss) | **Verified:** CONFIRMED — blink `preset = "default"` uses `vim.snippet`; blink scans `stdpath('config')/snippets` + rtp `friendly.snippets` (`registry.lua:16-17,31-33`); LazyVim's blink extra already depends on friendly-snippets (`extras/coding/blink.lua:25`). Main-session correction: an early runtime-facts line said luasnip.lua was the only friendly-snippets source — wrong.
**Fix:** delete `lua/langs/luasnip.lua`; run `:Lazy clean`; retarget the six LuaSnip doc lines (H5 item 11). If LuaSnip features are wanted later, enable the `coding.luasnip` extra instead.

### M2 (downgraded): conform lists lack `stop_after_first`; `java`/`prettier` dead
**Location:** `lua/langs/conform.lua:5-22` | **Challenged:** Downgraded to LOW by Challenger B — three supporting claims were wrong: no "unavailable" warning fires (LazyVim calls `conform.format({ bufnr })` without explicit formatters → `warn_on_missing = false`); "No formatter available" comes from LazyVim's `util/format.lua:136-138`, not conform; C/C++ format via `LazyVim.lsp.formatter()` (clangd), not conform's fallback. Live consequence: in a repo with `node_modules/.bin/prettier`, prettierd AND prettier both run (second pass idempotent). `java = { "prettier" }` is a dead line.
**Fix:** `default_format_opts = { stop_after_first = true }` (accepted key, conform `init.lua:24`) or per-list; drop `java`; optionally enable the `formatting.prettier` extra.

### M3 (downgraded): tokyonight loads at startup, then lume replaces it (~1.1 ms)
Duplicate of H1's root cause; fixed by the same `opts.colorscheme = "lume"`. Challenger H: LOW.

### M4 (downgraded): `n`/`N` override is normal-mode only
**Location:** `lua/config/keymaps.lua:38-39` | **Challenged:** Downgraded to LOW by Challenger B, description corrected: LazyVim's `'Nn'[v:searchforward]` is the one that makes `n` always go forward; the user's `nzz` restores vanilla direction in normal mode while x/o keep LazyVim's — a mode split. The draft fix (`zvzz` in x/o) would insert literal text after `cn` — do not ship. **Fix, user's choice:** (A) `map("n","n","'Nn'[v:searchforward].'zvzz'",{expr=true})` + mirror for `N`, leave x/o; or (B) keep `nzz` and `vim.keymap.del({"x","o"}, "n")`/`"N"`.

### M5 (downgraded): `{"S", false}` disables Flash `S` in normal mode only
**Location:** `lua/misc/flash.lua:9` | **Challenged:** LOW (Challenger B). LazyVim maps `S` in n/o/x (`editor.lua:39`); `false` without `mode` removes only `S`. **Fix:** `{ "S", mode = { "n", "o", "x" }, false }`, or document that visual `S` is Flash treesitter.

### M6 (downgraded, reframed): `<C-k>` is not inert — docs overstate it
**Location:** `lua/langs/blink.lua:7` | **Challenged:** Downgraded to LOW by Challenger C; the original "inert" claim was WRONG: LazyVim binds insert-mode `<c-k>` to `vim.lsp.buf.signature_help()` per LSP buffer (`plugins/lsp/init.lua:87`), and blink's `fallback` runs that buffer map. blink's own signature window is disabled (`signature.enabled = false`), so the key shows (never toggles) LSP signature help in LSP buffers, and is the digraph key elsewhere (vanilla). Line 7 is a byte-identical copy of blink's `default` preset. **Fix:** delete the redundant line; reword docs from "toggle signature help" to "LSP signature help (show)". Do NOT enable blink `signature` (turns on auto-popup) and do NOT delete the key (preset re-adds it).

### M11 (downgraded): checkmate `cancelled.order = 2` ties with `checked.order = 2`
**Location:** `lua/misc/checkmate.lua:85` | LOW (Challenger D): tie resolved by `pairs()` order; stable within a session; worst case one `<leader>t=` writes `- [c]` instead of `- [x]`. **Fix:** `order = 3`.

### M12 (severity contested): guicursor `o:` where docs say command mode; `VisualCursor` unused
**Location:** `lua/config/options.lua:23, 29, 37-38` | Challenger D: LOW; Challenger H: MEDIUM. Main session: LOW (cosmetic; the doc half is H5 item 9). Per options.txt:3027-3032, `o` = operator-pending, `c` = command-line; today operator-pending blinks and `:` does not (blink is independent of the empty highlight groups). **Fix:** `"n-v-o-sm:block-NormalCursor/lCursor"` + `"c:block-CommandCursor/lCursor-blinkwait700-blinkon400-blinkoff250"`; delete `VisualCursor`; confirm with the user that operator-pending yellow was not the intent.

### M15 (downgraded): `<Tab>` removes jumplist-forward (`<C-i>`)
**Location:** `lua/ui/bufferline.lua:7` | LOW/thought (Challenger D): documented trade-off; motion.txt:1057-1065 confirms the two keys are separable only outside tmux, and fzf.lua:30 shows the user runs tmux. **Fix (optional):** map a replacement for `<C-i>`; fix the CLAUDE.md row (H5 item 8).

### M17 (downgraded): Angular extra enabled while `angularls = false`
**Location:** `lua/langs/lsp.lua:6` vs `lazyvim.json:7` | LOW (Challenger E). Deliberate-looking delta: treesitter `angular`/`scss` and the vtsls Angular plugin survive; `ngserver` is excluded from Mason `ensure_installed` and from auto-enable. Warning: disabling the extra and deleting lsp.lua would REMOVE the exclusion, and mason-lspconfig's auto-enable would start `angularls` from the still-installed package. **Fix:** replace the trailing comment with the reason; leave the code.

### M18 (downgraded): `lua/search/grug-far.lua` is a verbatim copy of LazyVim's spec; `headerMaxWidth` is not a grug-far option
**Location:** `lua/search/grug-far.lua:1-22` | LOW (Challenger E). Only delta: `mode = {"n","v"}` adds a Select-mode binding. `headerMaxWidth` has zero matches in grug-far (LazyVim's own stale option). **Fix:** delete the file.

### M19 (downgraded): options.lua has 24 inert lines and six contradictory comments
**Location:** `lua/config/options.lua` | LOW (Challenger E, which counted 24: 15 LazyVim-identical values incl. `nu`, `cursorcolumn`, `diagnostic.enable`, `guicursor = ""`, 3 netrw vars, `backup`/`hlsearch`/`autoread` at nvim defaults). Comments at :5, :11, :63, :95, :101 (and keymaps.lua:80) state the opposite of the code. **Fix:** keep only real deltas — `tabstop`/`softtabstop = 4`, `shiftwidth = 0`, `breakindent`, `swapfile = false`, `scrolloff = 3`, `cursorline = false`, `updatetime = 50`, `sessionoptions` (decide on `"folds"`), `iskeyword`/`isfname`, guicursor, providers, netrw disable, `snacks_animate`, `autoformat`, `mkdp_auto_close` — with correct comments.

### M20 (downgraded): missing `desc` on leader maps; `<leader>z` group unnamed
**Location:** `lua/config/keymaps.lua:46,47,89`; `lua/misc/multicursor.lua:19-33` (five maps, not ten) | LOW (Challenger E): which-key shows blank labels for Lua-callback maps and "5 keymaps" for the group. **Fix:** add `desc`; add `{ "<leader>z", group = "multicursor" }` to which-key spec.

### L1: Dead files and a no-op disable
`lua/search/harpoon2.lua` (all commented), `lua/ui/scrollbar.lua` (`return {}` + 124 commented lines), `lua/misc/disabled.lua` (empty entry; neo-tree lives only in the un-enabled `editor.neo-tree` extra — snacks_explorer is LazyVim's auto-imported default explorer at `install_version` 8). Confirmed LOW (Challenger F). **Fix:** delete the two files and update the five harpoon doc mentions in the same change; annotate disabled.lua rather than delete.

### L2: Commented-out code blocks
keymaps.lua:16,76-78,98-103; options.lua:116-117; conform.lua:15; oil.lua:54; bufferline.lua:13; multicursor.lua:10-16,46-48,50-51; disabled.lua:3-4,12-20. Confirmed LOW (Challenger F): delete with their header comments; keep checkmate.lua:76-78 (documents fixed built-in markers).

### L8: 5 files fail `stylua --check`; stylua only in Mason bin
treesitter-context.lua, arrow.lua, keymaps.lua, autocmds.lua, oil.lua (main session ran Mason's stylua 2.5.2). CLAUDE.md's "Run `stylua .`" assumes PATH. **Fix:** run `~/.local/share/nvim/mason/bin/stylua .` as its own commit; add Mason bin to PATH or use the absolute path in CLAUDE.md.

### L9: Tracked cruft
`.neoconf.json` (no consumer; lazydev does not read it), root `KEYMAPS.md` (duplicate), boilerplate `README.md`, five dated docs at `docs/` root without frontmatter (move to `docs/investigations/`), empty untracked `ref/` and gitignored `.tests/` (`rmdir`). Confirmed LOW (Challenger G).

### Notes (not defects)
- **L3 (nit):** fzf.lua mutates fzf-lua defaults in place — same idiom LazyVim uses; all four alt keys exist; `rg_opts` rebuild is idempotent. Optional: `opts.grep.rg_opts or defaults...`.
- **L5 (informational):** arrow, multicursor, treesitter-context load eagerly; unquantified. Safe changes: arrow `keys = { ";", "m" }`, treesitter-context `event = "LazyFile"`, multicursor `event = "VeryLazy"` (NOT `keys` — its `setup` checks `<C-i>`/`<C-o>` availability at setup time).
- **L6 (thought):** `#1e1e2e`/`#f9e2af` are Catppuccin Mocha values; `#ffd400` is not. Cosmetic.
- **L7 (note):** oil filetype column calls `vim.filetype.match` per entry per render, uncached (mini.icons caches by name). If optimised, cache by basename, not extension.
- **L10 (note):** three RHS idioms and two leader spellings coexist; the one change that pays: convert `<leader>r` (:69-74) from a `:lua` string to a Lua function.
- **L11 (note):** `<C-y>` also accepts completions (blink preset + LazyVim) and is undocumented; `<C-.>`/`<C-,>` need CSI u or modifyOtherKeys (most modern terminals; Terminal.app does not).
- **L12 (note):** `sessionoptions` omits `"folds"` (LazyVim includes it) — decide; `log = {}`, `enabled = true`, `vim.diagnostic.enable(true)` are no-ops; `<C-c>` → `"+y` is zero-delta; oil `---@type` annotation sits on `dependencies`. Dismissed sub-claims: gitsigns return value (LazyVim's `on_attach` never returns `false`), checkmate `done` override (all seven default fields reproduced).

---

# Dismissed Findings

- **M16 — `clipboard` set in keymaps.lua overrides LazyVim's SSH-aware default.** DISMISSED by Challenger D, confirmed by main session: LazyVim captures the SSH-aware value into `lazy_clipboard` at init (`config/init.lua:340`), blanks the option, and restores `lazy_clipboard` in the VeryLazy callback AFTER `M.load("keymaps")` (`:192-194`). keymaps.lua:5 is therefore inert. Do NOT move it to options.lua — that WOULD break the SSH case (options.lua runs before the capture). Safe action: delete the line.
- **H5 item 7 (half):** "CLAUDE.md extras list omits dap" — CLAUDE.md:56 scopes the list to lazyvim.json; the dap imports are in lazy.lua. Not drift.
- **M6 original claim** "`<C-k>` is inert" — wrong; see reframed entry.
- **L12 (b), (c)** — see notes.

---

# Cross-Review Notes

- Severity contest on M12: Challenger D (LOW, cosmetic) vs Challenger H (MEDIUM, documented behaviour absent). Main session: LOW — the doc half is already counted in H5.
- Conflict on `:LspStop` semantics: deep-dive keymaps claimed `vim.lsp.enable(name, false)` leaves the client running; Challenger C claimed it stops clients. Main session read nvim 0.11.4 `lsp.lua:588-632`: it calls `client:stop()` for every client with that name (`:625-629`). Challenger C is right.
- Correction chain on friendly-snippets: runtime-facts initially said luasnip.lua was its only source; spec-compliance agent corrected it (LazyVim blink extra depends on it, `extras/coding/blink.lua:25`); main session verified and amended runtime-facts. H4's fix became "delete the file" with no replacement spec.
- Correction on `lCursor`: deep-dive colorscheme noted it is a Neovim built-in group, not lume's; runtime-facts amended.
- Three fix proposals were caught as wrong before delivery: M4 (`zvzz` in operator-pending inserts text), M6 (enabling blink signature / deleting the key), M10 (`update_prefills` does not exist). L5's multicursor `keys` trigger and M17's "disable the extra" were flagged as regressions.
- Deliberate trade-offs not filed as defects (all agents agreed): `=`/`-` increment remaps, arrow `;`/`m` leaders, `updatetime = 50`, fixed `20<C-d>`, `<Tab>` buffer cycling (noted as M15 for docs).

---

# Verification Log (main session, Critical/High and reversals)

| Finding | What the lead read | Claim matched? | Magnitude | Verdict |
|-|-|-|-|-|
| H1 | headless `nvim_get_hl` for 9 groups; lume init.lua:16-34, theme.lua:68-84, colors/lume.lua; tokyonight theme.lua:12; LazyVim config/init.lua:11-15,250-256 | Yes | Documented feature absent in every mode | CONFIRMED HIGH; fix SOUND |
| H5 | every cited doc line; checkmate config/init.lua:528-552, defaults.lua:157,169,179; LazyVim keymaps.lua:202-203; git log | 9/10 + item 11 | Wrong facts in always-loaded context | CONFIRMED HIGH |
| M13 | vimfn.txt:2200-2212; insert.txt:340-345,380-385; map.txt:192-196; autocmds.lua:19-34 | Yes (Doxygen sub-case corrected by J1) | Deterministic undo split; batch-dependent transposition | CONFIRMED MEDIUM |
| H6 | headless `pcall(vim.keymap.del, missing)` → E31; LazyVim config/init.lua:286-300; lazy.nvim handler/keys.lua:78-87, handler/init.lua:90-98 | Yes | Latent; notified; needs upstream rename | CONFIRMED MEDIUM; fix verified by deep-dive and J1 |
| H2 | headless maparg `s`, `sv`; `timeoutlen` | Yes | Bounded, reversible | DOWNGRADED to MEDIUM |
| H3 | mini/comment.lua:86-100,355-366; LazyVim extra :7-9; ts-context config.lua:62-70; ftplugin/c.lua:2, cpp.vim:17 | Yes | Visible immediately, one `u` | DOWNGRADED to MEDIUM |
| H7 | fzf-lua defaults.lua:972-977; make_entry.lua:410-420 | Yes | Narrow input class | DOWNGRADED to MEDIUM |
| H4 | blink registry.lua:16-33; LazyVim extras/coding/blink.lua:15-45; startuptime self-time 7.8 ms | Yes | No functional loss | DOWNGRADED to LOW |
| M6 | LazyVim plugins/lsp/init.lua:87 | Original claim wrong | Docs wording only | REFRAMED LOW |
| M7/M22 | nvim-lspconfig plugin/lspconfig.lua:168-195; nvim lsp.lua:588-632; snippet.lua:317-327 | Partly (stop semantics corrected) | Session-wide stop | CONFIRMED MEDIUM |
| M16 | LazyVim config/init.lua:172,186-196,340 | Mechanism refuted | None | REJECTED |
| M10 | grug-far.lua:500-522; LazyVim config/init.lua:343-345 | Yes; draft fix wrong | Future hard error, warning suppressed | CONFIRMED MEDIUM, fix corrected |
| M9 | oil mutator/init.lua:168-182; adapters/files.lua trash branch (via deep-dive) | Yes | Freeze on dir delete | CONFIRMED MEDIUM |
| M14 | headless `formatoptions`; _options.lua semantics (via deep-dive); filetype.lua:347,561 | Yes | Latent global `t` loss; duplicate autocmds on reload | CONFIRMED MEDIUM |

---

# Merge Criteria

Verdict: APPROVE — no Critical findings. Recommended order of work (each independent unless noted):
1. H1 + M12 together: colorscheme spec rewrite with `custom_highlights`; delete options.lua:21-25; fix guicursor mode letters.
2. M13: rewrite the `*` insert map as an `expr` mapping with `<C-g>U<Left>` and a string/comment guard, under an augroup.
3. H3 + M14 together: delete mini-comment.lua; add ts-context-commentstring `languages.c`; relocate the formatoptions autocmd with `vim.opt_local`.
4. H6 + M21 + M23 + M7 + H2: keymaps.lua cleanup (bufferline `keys` override, `Snacks.bufdelete.all()`, `x` mode, LspStop key, delete `sv`).
5. H7, M1, M8, M9, M10: one-line fixes in fzf.lua and oil.lua.
6. H5 + H4 + L1 + L9: docs update and dead-file removal in one change so docs and code move together; run stylua as a separate commit (L8).
