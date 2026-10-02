---
title: Spec Compliance Review — nvim config docs vs code
created: 2026-09-06
updated: 2026-09-06
status: final
topics:
  - spec-compliance
  - documentation
  - nvim-config
---

# Spec Compliance Review

Spec = `CLAUDE.md`, `docs/specs/{architecture,plugins,keymaps,customization-guide,debugging}.md`, root `KEYMAPS.md`.
Implementation = `init.lua`, `lua/**/*.lua`, `lazyvim.json`, `snippets/*.json`.
LazyVim/plugin sources read from `~/.local/share/nvim/lazy/`. No nvim run; no files edited except this one.

## Compliance Matrix

MATCH rows are not individually enumerated; every non-MATCH row is listed below. debugging.md produced no non-MATCH rows among the claims checked (dap.core keymap set, `automatic_installation = true`, four-plugin install list, php adapter-defined-but-not-installed, rust `<leader>dr` buffer-local remap).

| Doc:line | Claim | Code location | Verdict | Note |
|-|-|-|-|-|
| CLAUDE.md:15 | `lua/search/` = "fzf, grug-far, harpoon, arrow" | lua/search/harpoon2.lua:1-44 | MISMATCH | Whole spec commented out; harpoon absent from lazy-lock.json |
| architecture.md:74 | `harpoon2.lua` \| harpoon (v2 branch) \| "File bookmarking with `<leader>1-5`" | lua/search/harpoon2.lua:1-44 | MISMATCH | Returns `{ { } }` — one empty spec table |
| plugins.md:106-116 | harpoon section: `<leader>a`, `<leader>h`, `<leader>1-5`, `save_on_toggle` | lua/search/harpoon2.lua:1-44 | MISMATCH | None of these keys exist |
| keymaps.md:120-126 | Harpoon keymap table | lua/search/harpoon2.lua:1-44 | MISMATCH | Same |
| KEYMAPS.md:56-64 | Harpoon keymap table | lua/search/harpoon2.lua:1-44 | MISMATCH | Same |
| plugins.md:233, keymaps.md:192, KEYMAPS.md:165 | `<leader>ta` Archive completed | lua/misc/checkmate.lua:11-74 | NOT IN CODE | User `keys` replaces plugin defaults entirely |
| plugins.md:239, keymaps.md:198, KEYMAPS.md:168-169 | `<leader>t]` / `<leader>t[` jump metadata | lua/misc/checkmate.lua:11-74 | NOT IN CODE | Same mechanism |
| plugins.md:235, keymaps.md:194, KEYMAPS.md:170 | `<leader>tp` @priority | checkmate defaults.lua:157 | MISMATCH | Real key is `<leader>Tp` (capital T) |
| plugins.md:236, keymaps.md:195, KEYMAPS.md:171 | `<leader>ts` @started | checkmate defaults.lua:169 | MISMATCH | Real key is `<leader>Ts` |
| CLAUDE.md:52, keymaps.md:91-92 | `<leader>uz`/`<leader>uZ` = "Fold toggles" | LazyVim config/keymaps.lua:202-203 | MISMATCH | Snacks zoom / zen |
| plugins.md:153-159, keymaps.md:204-211, KEYMAPS.md:121-128 | Oil keymap tables | lua/ui/oil.lua:119-132 | NOT IN DOCS | `gy` = copy current dir path |
| plugins.md:219-241, keymaps.md:182-198 | Checkmate key/state tables | lua/misc/checkmate.lua:64-73, 75-93, 8-10 | NOT IN DOCS | `<leader>tx`, `<leader>th`, `cancelled`, `on_hold`, `smart_toggle.enabled=false` |
| plugins.md:85-93, keymaps.md:106-112 | fzf-lua = "Overrides three LazyVim default keymaps" | lua/search/fzf.lua:29-68 | NOT IN DOCS | 40-line `opts` function |
| plugins.md:143-159 | oil.nvim section | lua/ui/oil.lua:136-176 | NOT IN DOCS | `OilActionsPost` buffer-cleanup autocmd |
| architecture.md:54 | `autocmds.lua` = "markdown/text settings" | lua/config/autocmds.lua:19-34 | NOT IN DOCS | C/C++ insert-mode `*` block-comment autocmd |
| plugins.md:45-51 | "prettierd, prettier (fallback)" | conform.nvim init.lua:424,573; LazyVim formatting.lua:67-72 | MISMATCH | `stop_after_first` defaults false → both run |
| plugins.md:59-64, CLAUDE.md:18, CLAUDE.md:107, customization-guide.md:171 | LuaSnip is the snippet engine loading `snippets/` | LazyVim extras/coding/blink.lua:39-41; blink registry.lua:17,31-33 | MISMATCH | blink preset `default`; never queries LuaSnip |
| plugins.md:187-192, architecture.md:93 | mini.comment = "C/C++ `//`, disables auto-continue" | lua/misc/mini-comment.lua:7-9 | NOT IN DOCS | `custom_commentstring` replaces LazyVim's ts_context_commentstring hook |
| architecture.md:125 | "Set in `lua/config/lazy.lua:36-54`" | lua/config/lazy.lua:30-57 | MISMATCH | Range omits `defaults.lazy=false` (line 33), first bullet listed |
| architecture.md:29 | "Defined in `lua/config/lazy.lua:18-26`" | lua/config/lazy.lua:18-29 | MISMATCH | Block ends at :29; quote strips lines 19/21/24 comments |
| architecture.md:108 | `.neoconf.json` = "Neodev/neoconf settings for Lua LSP" | lazy-lock.json (no neoconf); `~/.local/share/nvim/lazy/neoconf*` absent | MISMATCH | No installed plugin reads it (lazydev.nvim is installed instead) |
| CLAUDE.md:128-131 | Documentation @-includes | docs/specs/debugging.md exists | NOT IN DOCS | debugging.md not @-included; CLAUDE.md never mentions dap |
| CLAUDE.md:43 | `<Tab>`/`<S-Tab>` replaced "Indent/snippet navigation" | LazyVim config/keymaps.lua (no normal-mode Tab map) | MISMATCH | Real casualty is `<C-i>` jumplist-forward |
| CLAUDE.md:33 | "Yellow blinking in insert/replace/command, white in normal" | lua/config/options.lua:29,38 | MISMATCH | `c` sits in the white `NormalCursor` group; yellow `CommandCursor` is bound to `o` (operator-pending) |
| customization-guide.md:242 | Branches: main, macbook, macbook-reset, ubuntu-desktop | .git/packed-refs:2-6 | MISMATCH | `macbook-backup` also exists |
| CLAUDE.md:48 | "`<leader>bp` / `<leader>bP` → BufferLine move prev/next" | lua/config/keymaps.lua:53-66 | MISMATCH | `<leader>bP` is deleted, not remapped; "next" is `<leader>bn` |
| keymaps.md:90 | `S` disabled — "Conflicts with mini.surround workflow" | lua/config/keymaps.lua:80 | MISMATCH | Code comment says "equivalent to `cc` and clashes with nvim-surround" (not installed) |
| architecture.md:25, :54 | keymaps and autocmds load "on the `VeryLazy` event" | LazyVim config/init.lua:179-192 | MISMATCH | autocmds load at setup when `argc(-1) > 0` |
| keymaps.md:164-176, plugins.md:198-207 | Multicursor tables | lua/misc/multicursor.lua:38 | NOT IN DOCS | `<C-LeftRelease>` handler |
| plugins.md:213 | nvim-spider opts | lua/misc/nvim-spider.lua:6 | NOT IN DOCS | `consistentOperatorPending = true` |
| keymaps.md:69 | `<leader>r` "search/replace in current file" | lua/config/keymaps.lua:72 | NOT IN DOCS | Flags `-F -i` omitted (KEYMAPS.md:28 has them) |
| plugins.md:25-35 | blink keymap table | lua/langs/blink.lua:24 | NOT IN DOCS | `<C-b>` fallback missing (keymaps.md:147 has it) |
| plugins.md:191 | mini.comment "C/C++ files" | lua/misc/mini-comment.lua:12 | NOT IN DOCS | Pattern also covers `h`, `hpp` |
| specs frontmatter `updated: 2026-05-26` | — | .git/logs/HEAD:88-98 | MISMATCH | Code changed 2026-06-08 → 2026-09-06 |

## Findings

## HIGH: Harpoon documented as an active plugin in five places; it is fully commented out
Spec requirement: plugins.md:106-108 — "### harpoon v2 (`harpoon2.lua`)\n\nFile bookmarking. Uses the `harpoon2` branch of ThePrimeagen/harpoon."
Current code: `/Users/zcu/.config/nvim/lua/search/harpoon2.lua`:1-44 — the file returns `{ { -- ...all commented... } }`; every line from `-- "ThePrimeagen/harpoon",` (:3) to `-- end,` (:42) is a comment. `harpoon` has no entry in `/Users/zcu/.config/nvim/lazy-lock.json`, so the plugin is not even installed.
Gap: `<leader>a`, `<leader>h`, and `<leader>1`–`<leader>5` are documented as working keys in CLAUDE.md:15, architecture.md:74, plugins.md:106-116, keymaps.md:120-126, and KEYMAPS.md:56-64. None are bound. Worse, `<leader>1`–`<leader>5` are free, so a future session could be told they are taken.
Fix: update docs. Delete the harpoon sections from plugins.md, keymaps.md and KEYMAPS.md; change architecture.md:74 to `harpoon2.lua | (disabled) | Harpoon spec retained but fully commented out`; change CLAUDE.md:15 to `(fzf, grug-far, arrow)`. Add a "Disabled / removed" line so the empty file is not mistaken for a bug. Drift dates to commit `941603d` "mod: disabled harpoon2", 2026-06-08 (.git/logs/HEAD:88) — 13 days after the specs' `updated: 2026-05-26`.
Confidence: HIGH
Counter-argument: the file still exists, so one could argue the docs describe intent. It still stands: all three keymap tables list the keys without qualification, and CLAUDE.md is fed to every AI session as ground truth.

## HIGH: `<leader>ta`, `<leader>t]`, `<leader>t[` documented but not bound — checkmate replaces its default keys
Spec requirement: plugins.md:233 — "| `<leader>ta` | Archive completed items |"; plugins.md:239 — "| `<leader>t]` / `<leader>t[` | Jump to next/prev metadata tag |".
Current code: `/Users/zcu/.config/nvim/lua/misc/checkmate.lua`:11-74 defines a `keys` table containing exactly `tt tc tu t= t- tn tr tR tF tv tx th`. Checkmate does not merge it: `~/.local/share/nvim/lazy/checkmate.nvim/lua/checkmate/config/init.lua`:537-538 — `if o.keys then config.keys = nil end`, with the comment at :535 "we can't merge `keys` because they are keyed on unique strings". The 13 plugin defaults at `config/defaults.lua`:22-88 (`<leader>Tt` … `<leader>T[`, including `<leader>Ta` archive at :63) are therefore discarded.
Gap: three documented keys do not exist in any case variant — the user's table drops them and the defaults are nil'd.
Fix: update code or docs. Minimal doc fix: delete those three rows from plugins.md:233,239, keymaps.md:192,198 and KEYMAPS.md:165,168-169. If the keys are wanted, add to lua/misc/checkmate.lua's `keys`: `["<leader>ta"] = { rhs = "<cmd>Checkmate archive<CR>", desc = "Archive checked/completed todo items", modes = { "n" } }` plus `<leader>t]` → `<cmd>Checkmate metadata jump_next<CR>` and `<leader>t[` → `<cmd>Checkmate metadata jump_previous<CR>`.
Confidence: HIGH
Counter-argument: one could assume `opts.keys` deep-merges like most lazy.nvim opts. It does not — `prevent_merge` runs before `vim.tbl_deep_extend` at init.lua:570-571, and the plugin's own comment names the duplicate-mapping bug that motivated it.

## HIGH: `<leader>tp` / `<leader>ts` are documented lowercase; the live keys are `<leader>Tp` / `<leader>Ts`
Spec requirement: plugins.md:235-236 — "| `<leader>tp` | Add/update `@priority` tag |" and "| `<leader>ts` | Add `@started` tag (auto-dates) |".
Current code: `/Users/zcu/.config/nvim/lua/misc/checkmate.lua`:105-122 supplies only `metadata.done` (with `key = "<leader>td"` at :113). `metadata` uses a different merge rule from `keys`: `checkmate/config/init.lua`:546-550 nils only the names the user supplies (`for meta_name, _ in pairs(o.metadata) do config.metadata[meta_name] = nil end`), so `priority` and `started` survive from `config/defaults.lua`:138-171 — with their default keys `key = "<leader>Tp"` (:157) and `key = "<leader>Ts"` (:169), bound because `use_metadata_keymaps = true` (:135).
Gap: the documented lowercase keys are unbound; the working keys are capital-T and appear nowhere in the docs. This is why `<leader>td` works (user override) while `<leader>tp`/`<leader>ts` do not — two different merge rules in the same opts table.
Fix: update docs to `<leader>Tp` / `<leader>Ts`, or add explicit `key = "<leader>tp"` / `key = "<leader>ts"` overrides under `metadata.priority` / `metadata.started` in lua/misc/checkmate.lua. Add a doc note that checkmate's `keys` is replace-semantics and `metadata` is per-name replace-semantics.
Confidence: HIGH
Counter-argument: the tags themselves do work, so the feature is not missing — only the key. It still stands: a key table that lists a wrong key is worse than one that omits it, and the capital/lowercase split is exactly the trap this doc set exists to prevent.

## MEDIUM: `<leader>uz` / `<leader>uZ` described as "Fold toggles"; they are Snacks zen and zoom
Spec requirement: CLAUDE.md:52 — "| `<leader>uz` / `<leader>uZ` | Deleted | Fold toggles |"; keymaps.md:91-92 — "Fold toggle removed".
Current code: `/Users/zcu/.config/nvim/lua/config/keymaps.lua`:108-109 deletes both. `~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/config/keymaps.lua`:202 — `Snacks.toggle.zoom():map("<leader>wm"):map("<leader>uZ")`; :203 — `Snacks.toggle.zen():map("<leader>uz")`.
Gap: the deletion is documented correctly; what was deleted is not. Zen mode is now unreachable; zoom survives on `<leader>wm`.
Fix: update docs. CLAUDE.md:52 third column → `Snacks zen / zoom (zoom still on <leader>wm)`; keymaps.md:91-92 reason → `Snacks zen removed` / `Snacks zoom removed (still on <leader>wm)`.
Confidence: HIGH
Counter-argument: the practical instruction ("don't re-add these") is unaffected. It stands because a session looking for zen mode would search folds and never find it.

## MEDIUM: Oil `gy` keymap absent from all three keymap tables
Spec requirement: plugins.md:153-159, keymaps.md:204-211, KEYMAPS.md:121-128 — Oil tables listing `<C-s>`, `q`, `gs`, `<leader>fo`, `<C-h>`, `<C-t>`.
Current code: `/Users/zcu/.config/nvim/lua/ui/oil.lua`:119-132 — `gy` with `desc = "oil: Copy current directory path"`, calling `vim.fn.setreg("+", dir)` on `require("oil").get_current_dir()`.
Gap: a seventh Oil keymap exists in none of the three tables. Added in `5de9fee` "add: oil keymap to yank absolute path", 2026-07-09 (.git/logs/HEAD:95).
Fix: update docs. Add `| `gy` | Copy current Oil directory path to system clipboard |` to all three tables.
Confidence: HIGH
Counter-argument: none — it is a plain omission.

## MEDIUM: Checkmate custom states, keys, and `smart_toggle` disabled are undocumented
Spec requirement: plugins.md:241 — "Metadata tags: `@priority` (low/medium/high with color), `@started` (date), `@done` (date, auto-checks)." plus the key table at :223-239, neither of which mentions custom states.
Current code: `/Users/zcu/.config/nvim/lua/misc/checkmate.lua`:64-73 adds `<leader>tx` (`Checkmate toggle cancelled`) and `<leader>th` (`Checkmate toggle on_hold`); :75-93 defines `cancelled` (`markdown = "c"`, `type = "complete"`) and `on_hold` (`markdown = "/"`, `type = "inactive"`); :94-104 adds six highlight groups; :8-10 sets `smart_toggle = { enabled = false }`.
Gap: two live keymaps, two on-disk markdown formats (`- [c]`, `- [/]`), and a disabled default behavior are invisible to the docs. The markdown formats matter most — a session editing a todo file will not recognize `- [c]`. From `3922f2b`, 2026-06-08 (.git/logs/HEAD:89).
Fix: update docs. Add `<leader>tx` / `<leader>th` rows to plugins.md, keymaps.md, KEYMAPS.md; add to plugins.md a "Custom states: `cancelled` (`- [c]`, counts as done), `on_hold` (`- [/]`, ignored in counts). `smart_toggle` disabled — parent/child todos do not auto-propagate."
Confidence: HIGH
Counter-argument: none.

## MEDIUM: fzf-lua doc says "overrides three keymaps"; the spec also rewrites picker actions and defaults
Spec requirement: plugins.md:87 — "Fuzzy finder. Overrides three LazyVim default keymaps to use cwd instead of project root:".
Current code: `/Users/zcu/.config/nvim/lua/search/fzf.lua`:29-68 — an `opts` function that moves `alt-i`/`alt-h`/`alt-q`/`alt-f` onto `ctrl-o`/`ctrl-y`/`ctrl-l`/`ctrl-g` and nils the alt keys (:34-50), sets `opts.grep.no_ignore = true` and `opts.grep.hidden = true` (:54-55), prepends `-g "!.git" -g "!.jj"` to `rg_opts` (:56), sets `opts.files.no_ignore = true` (:61), and sets `winopts.width/height = 0.90` (:64-66).
Gap: the docs describe only the `keys` table. Search semantics changed — grep now searches gitignored and hidden files by default, which changes results for `<leader>/`. From `276cc2b` (2026-07-03) and `cd512b0` (2026-08-17), .git/logs/HEAD:94,97.
Fix: update docs. Add to plugins.md's fzf-lua section: an in-picker action table (`<C-o>` toggle gitignore, `<C-y>` toggle hidden, `<C-l>` send to quickfix, `<C-g>` follow symlinks — moved off Alt because tmux eats macOS Option) and a Defaults line (`grep.no_ignore`, `grep.hidden`, `files.no_ignore` on; `.git`/`.jj` excluded; window 0.90 x 0.90).
Confidence: HIGH
Counter-argument: keymaps.md legitimately scopes itself to keys — but plugins.md is the option reference and the `<C-*>` picker actions are keymaps by any reading.

## MEDIUM: Oil's deleted-file buffer cleanup autocmd is undocumented in the specs
Spec requirement: plugins.md:151 — "Settings: `delete_to_trash = true`, hidden files shown, natural sort order." architecture.md:83 — "File explorer with custom columns (filetype, mtime)".
Current code: `/Users/zcu/.config/nvim/lua/ui/oil.lua`:136-176 — a `canonical_path` helper (:140-150) and a `User`/`OilActionsPost` autocmd (:152-176) that force-deletes buffers whose canonical path matches a deleted file, skipping unnamed and `modified` buffers (:168).
Gap: 40 of oil.lua's 179 lines implement behavior no spec doc mentions. `docs/investigations/oil-deleted-file-buffer-freeze.md` exists but is not @-included by CLAUDE.md, so it never reaches a session. From `ed5fb23`, 2026-06-09 (.git/logs/HEAD:90).
Fix: update docs. Add to plugins.md's oil section: "On `OilActionsPost` delete, the matching buffer is wiped (unnamed and modified buffers are skipped) — otherwise Neovim's deleted-file handling freezes the UI for about a second. See `docs/investigations/oil-deleted-file-buffer-freeze.md`."
Confidence: HIGH
Counter-argument: it is a bug workaround, not a feature. It stands — it force-deletes buffers, which any session editing oil.lua must know about.

## MEDIUM: C/C++ block-comment autocmd is undocumented, including its insert-mode `*` keymap
Spec requirement: architecture.md:54 — "| `autocmds.lua` | Custom autocommands (markdown/text settings) | VeryLazy event |". keymaps.md lists no insert-mode keymaps outside blink.
Current code: `/Users/zcu/.config/nvim/lua/config/autocmds.lua`:19-34 — a `FileType` autocmd on `{ "c", "cpp" }` that buffer-locally maps insert-mode `*`; when the preceding character is `/` it feeds `*  */<Left><Left><Left>`, otherwise a literal `*` (:27-31).
Gap: an insert-mode keymap in `c`/`cpp` buffers appears in no keymap table, and architecture.md's one-line summary claims the file only holds markdown/text settings.
Fix: update docs. architecture.md:54 → "Custom autocommands (markdown/text settings, C/C++ block-comment auto-close)"; add to keymaps.md a row: `| `*` | i (c/cpp) | After `/`, expands to `/*  */` with the cursor inside |`.
Confidence: HIGH
Counter-argument: it is a tiny convenience. It stands — it remaps a printable character in insert mode, the single most surprising class of undocumented keymap.

## MEDIUM: "prettierd, prettier (fallback)" — conform runs both, it does not fall back
Spec requirement: plugins.md:45-47 — "| astro, html, css, scss | prettierd, prettier (fallback) |" (three rows use the same "(fallback)" wording).
Current code: `/Users/zcu/.config/nvim/lua/langs/conform.lua`:6-21 lists `{ "prettierd", "prettier" }`. `~/.local/share/nvim/lazy/conform.nvim/lua/conform/init.lua`:424 and :573 both default `stop_after_first = false`; :345 `M.resolve_formatters = function(names, bufnr, warn_on_missing, stop_after_first)` and :367 `if stop_after_first and #all_info > 0 then` — only that flag stops after the first. `~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/formatting.lua`:67-72 sets `default_format_opts` to `timeout_ms`, `async`, `quiet`, `lsp_format` — not `stop_after_first`.
Gap: with both binaries present, prettierd and prettier both run in sequence on every format. The doc's "(fallback)" states a mechanism that requires an option nobody sets.
Fix: update docs (and optionally code). Doc: "prettierd, then prettier — both run if both are installed; conform's `stop_after_first` defaults to false." Code, if fallback is the intent: add `default_format_opts = { stop_after_first = true }` to lua/langs/conform.lua's `opts`.
Confidence: HIGH
Counter-argument: `prettier` is not installed (Mason has prettierd only, per runtime-facts.md:35-36), so today only prettierd runs and the doc reads correct. It stands: the doc states a mechanism, not an observation, and the day prettier lands the behavior silently doubles.

## MEDIUM: LuaSnip is documented as the snippet engine; blink.cmp never queries it
Spec requirement: plugins.md:59-64 — "### LuaSnip (`luasnip.lua`)\n\nSnippet engine with two sources: 1. **friendly-snippets** … 2. **Custom snippets** — From `~/.config/nvim/snippets/`". Also CLAUDE.md:18 ("loaded by LuaSnip"), CLAUDE.md:107 ("LuaSnip auto-loads from that directory"), customization-guide.md:171 ("LuaSnip matches the filename to the filetype").
Current code: `/Users/zcu/.config/nvim/lua/langs/luasnip.lua`:6-10 calls `require("luasnip.loaders.from_vscode").lazy_load()` twice. But `~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/coding/blink.lua`:39-41 sets `snippets = { preset = "default" }`, and `~/.local/share/nvim/lazy/blink.cmp/lua/blink/cmp/config/snippets.lua`:9-11 dispatches every snippet handler through `require('blink.cmp.config').snippets.preset` (default `'default'` at :27). `/Users/zcu/.config/nvim/lua/langs/blink.lua` never sets `snippets`. Blink's own scanner supplies the completions: `~/.local/share/nvim/lazy/blink.cmp/lua/blink/cmp/sources/snippets/default/registry.lua`:17 `search_paths = { vim.fn.stdpath('config') .. '/snippets' }` and :31-33, which appends any runtime path matching `friendly.snippets`.
Gap: both documented sources reach the completion menu — through blink's scanner, not LuaSnip. LuaSnip loads at startup (~7.8 ms per runtime-facts.md:30) and its registry is never read.
Fix: update docs. plugins.md:59 → "### LuaSnip (`luasnip.lua`) — Installed, but not the completion path. blink.cmp uses `snippets.preset = \"default\"` (set by LazyVim), so completions come from blink's own scanner, which reads `stdpath('config')/snippets` and any `friendly.snippets` runtime path. This spec's practical effect is pulling in friendly-snippets and keeping LuaSnip available for plugins that call it." Adjust CLAUDE.md:18/:107 and customization-guide.md:171 to say blink scans `snippets/`.
Confidence: HIGH
Counter-argument: user-visible behavior is identical (same directory, same filename→filetype rule), so the how-to instructions still work. It stands because the docs name a component as load-bearing when it is not — the exact claim someone would rely on when deciding whether luasnip.lua can be deleted.
Related correction to `context/runtime-facts.md`:30: it states lua/langs/luasnip.lua "is the ONLY spec that installs friendly-snippets". False — LazyVim's blink extra declares `"rafamadriz/friendly-snippets"` as a dependency at extras/coding/blink.lua:25. Deleting luasnip.lua would not remove friendly-snippets.

## MEDIUM: mini.comment's `custom_commentstring` override drops LazyVim's treesitter-aware commentstring
Spec requirement: plugins.md:189-192 — "Comment toggling. Two autocmds are set inside the opts table: 1. C/C++ files … 2. All files …". architecture.md:93 — "Comment toggling (C/C++ uses `//`, disables auto-continue)".
Current code: `/Users/zcu/.config/nvim/lua/misc/mini-comment.lua`:6-10 sets `options.custom_commentstring = function() return vim.bo.commentstring end`. LazyVim's value at `~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/coding/mini-comment.lua`:7-9 is `custom_commentstring = function() return require("ts_context_commentstring.internal").calculate_commentstring() or vim.bo.commentstring end`, and :13-16 installs `JoosepAlviste/nvim-ts-context-commentstring` to back it.
Gap: the docs describe only the two autocmds and never mention the third, behavior-changing key. Context-aware commenting (JSX inside TSX, embedded CSS in HTML) is disabled config-wide.
Fix: update docs. Add to plugins.md's mini.comment section: "`custom_commentstring` is overridden to plain `vim.bo.commentstring`, replacing LazyVim's `ts_context_commentstring` integration — comments are not context-aware inside embedded languages (JSX in TSX, `<style>` in HTML)."
Confidence: HIGH
Counter-argument: the user may have overridden it deliberately to avoid the ts_context_commentstring dependency. It stands — a deliberate behavior change is exactly what the plugin reference should record, and `nvim-ts-context-commentstring` is still installed while nothing calls it.

## MEDIUM: architecture.md's Performance Configuration line reference misses the option it lists first
Spec requirement: architecture.md:125 — "Set in `lua/config/lazy.lua:36-54`:" followed by four bullets whose first is "`defaults.lazy = false`".
Current code: `/Users/zcu/.config/nvim/lua/config/lazy.lua` — `defaults = {` at :30, `lazy = false` at :33, `version = false` at :36, `checker = {` at :39, `performance = {` at :43, `"zipPlugin",` at :54, block closes at :57.
Gap: the cited range starts at :36, three lines after the `lazy = false` it claims to cover, and stops at :54, before the block closes at :57.
Fix: update doc. architecture.md:125 → "Set in `lua/config/lazy.lua:30-57`:".
Confidence: HIGH
Counter-argument: line refs drift by nature. It stands — this one was wrong when written, and the file has not changed size.

## MEDIUM: `.neoconf.json` is documented as active Lua LSP config; neoconf.nvim is not installed
Spec requirement: architecture.md:108 — "| `.neoconf.json` | Neodev/neoconf settings for Lua LSP |".
Current code: `/Users/zcu/.config/nvim/.neoconf.json` exists (15 lines, `neodev.library` and `neoconf.plugins.lua_ls`). `/Users/zcu/.config/nvim/lazy-lock.json` has no `neoconf.nvim` and no `neodev.nvim` entry; `~/.local/share/nvim/lazy/neoconf*` matches nothing. The installed equivalent is `lazydev.nvim` (lazy-lock.json:20), which does not read `.neoconf.json`.
Gap: the doc presents an inert file as live configuration. A session tuning Lua LSP would edit it and see no effect.
Fix: update doc (and consider deleting the file — flagged, not removed). architecture.md:108 → "| `.neoconf.json` | Inert — neoconf.nvim/neodev.nvim are not installed; LazyVim uses lazydev.nvim. Left over from the LazyVim starter template. |".
Confidence: HIGH
Counter-argument: neoconf could ship inside another plugin. Checked — no `neoconf*` directory exists under `~/.local/share/nvim/lazy/` and no lock entry names it.

## MEDIUM: CLAUDE.md neither @-includes debugging.md nor mentions the debugger at all
Spec requirement: CLAUDE.md:126-131 — "Read these before making changes:" followed by `@docs/specs/architecture.md`, `@docs/specs/plugins.md`, `@docs/specs/keymaps.md`, `@docs/specs/customization-guide.md`.
Current code: `/Users/zcu/.config/nvim/docs/specs/debugging.md` exists (300 lines) and is cross-referenced from architecture.md:66, plugins.md:81 and keymaps.md:215. `/Users/zcu/.config/nvim/lua/config/lazy.lua`:22-23 imports `lazyvim.plugins.extras.dap.core` and `lazyvim.plugins.extras.dap.nlua`; `/Users/zcu/.config/nvim/lua/langs/dap.lua`:8-11 installs `php-debug-adapter`.
Gap: CLAUDE.md's "LazyVim Extras" list (:58-61) enumerates only the 15 entries in lazyvim.json and omits the two dap extras imported in code, and the `<leader>d` prefix (19 keymaps) never appears. A session reading only CLAUDE.md would believe `<leader>d` is free.
Fix: update doc. Add `@docs/specs/debugging.md` to CLAUDE.md:131, and to the Extras section: "Also imported directly in `lua/config/lazy.lua` (not via `:LazyExtras`): `dap.core`, `dap.nlua`."
Confidence: HIGH
Counter-argument: debugging.md is reachable via architecture.md, which IS @-included. It stands — the transitively-referenced file is not itself @-included, so its content never enters the context window.

## MEDIUM: `<Tab>` override row names a LazyVim default that does not exist
Spec requirement: CLAUDE.md:43 — "| `<Tab>` / `<S-Tab>` | Cycle buffers (BufferLine) | Indent/snippet navigation |".
Current code: `/Users/zcu/.config/nvim/lua/ui/bufferline.lua`:7-8 binds `<Tab>` and `<S-Tab>` with no `mode` field, so lazy.nvim's default mode `"n"` applies. `~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/config/keymaps.lua` maps no bare `<Tab>` in any mode (only `<leader><tab>*` tab-page keys at :206-212), and `/Users/zcu/.config/nvim/lua/langs/blink.lua`:22-23 sets `<Tab>`/`<S-Tab>` to `"fallback"` in blink.
Gap: the "LazyVim default replaced" column describes insert-mode completion behavior that this config already unbinds inside blink. What normal-mode `<Tab>` actually displaces is Vim's `<C-i>` — jumplist-forward — which no doc mentions.
Fix: update doc. CLAUDE.md:43 third column → "Vim's `<C-i>` jumplist-forward in normal mode (`<Tab>` and `<C-i>` are the same key code). Use `<C-i>`'s counterpart `<C-o>` to go back; forward jumps are no longer bound."
Confidence: HIGH
Counter-argument: `<Tab>` is conventionally described as a completion key, so the row reads plausibly. It stands — the row's purpose is to say what was lost, and it names the wrong thing while omitting the real loss.

## MEDIUM: Cursor design decision says command mode is yellow; command mode is white
Spec requirement: CLAUDE.md:33 — "**Cursor**: Block cursor in all modes. Yellow blinking in insert/replace/command, white in normal."
Current code: `/Users/zcu/.config/nvim/lua/config/options.lua`:29 — `"n-v-c-sm:block-NormalCursor/lCursor"`, so command-line mode `c` uses `NormalCursor` (`bg = "#ffffff"`, :21) with no blink. The yellow `CommandCursor` group (`bg = "#ffd400"`, :25) is applied at :38 — `"o:block-CommandCursor/lCursor-blinkwait700-blinkon400-blinkoff250"` — where `o` is operator-pending mode, not command mode, despite the `-- Command mode:` comment at :37.
Gap: for one of the three listed modes the doc states the opposite of the code. Insert (`i-ci-ve`, :32) and replace (`r-cr`, :35) are correct.
Fix: update doc (the code's mode letter is also likely a typo — flagged, not changed). CLAUDE.md:33 → "Block cursor in all modes. Yellow blinking in insert, replace, and operator-pending; white in normal, visual, and command-line."
Confidence: HIGH
Counter-argument: purely cosmetic. It stands under the rubric — a doc sentence whose claim is the opposite of the code, and it also masks a probable `o:` / `c:` mix-up at options.lua:37-38 that a reader trusting the doc would never look for.

## MEDIUM: Branch list omits `macbook-backup`
Spec requirement: customization-guide.md:242 — "This repo has branches for different machines: `main`, `macbook`, `macbook-reset`, `ubuntu-desktop`."
Current code: `/Users/zcu/.config/nvim/.git/packed-refs`:2-6 lists `refs/heads/macbook`, `refs/heads/macbook-backup`, `refs/heads/macbook-reset`, `refs/heads/main`, `refs/heads/ubuntu-desktop` (plus `refs/stash` at :7). `.git/refs/heads/macbook-reset` is the only loose ref, consistent with the doc's "current branch is `macbook-reset`".
Gap: five branches exist, four are documented.
Fix: update doc. customization-guide.md:242 → "`main`, `macbook`, `macbook-backup`, `macbook-reset`, `ubuntu-desktop`" — and state what `macbook-backup` is for, or delete it.
Confidence: HIGH
Counter-argument: a backup branch may be deliberately unlisted. It stands — the sentence enumerates and reads as exhaustive; an AI session merging "back to `main`" should know a fifth head exists.

## LOW: Spec-import quote is not verbatim and its line range stops three lines short
Spec requirement: architecture.md:29-41 — "Defined in `lua/config/lazy.lua:18-26`:" followed by a ```lua block.
Current code: `/Users/zcu/.config/nvim/lua/config/lazy.lua`:18-29 — `spec = {` at :18, `{ import = "misc" },` at :28, `},` at :29. The doc's block omits the comments at :19, :21 and :24 (including "debugging: nvim-dap core + Lua adapter…", the only in-code note explaining the dap imports).
Gap: line range off by three; the quote silently drops the comment that documents why the dap imports are there.
Fix: update doc. Change to `lua/config/lazy.lua:18-29` and either include the comment lines or reference the range instead of quoting.
Confidence: HIGH
Counter-argument: the spec entries themselves are reproduced in the right order — the sequence claim is correct. It stands as LOW: harmless today, but a reader comparing quote to file sees a mismatch.

## LOW: `<leader>bp` / `<leader>bP` override row conflates three keys
Spec requirement: CLAUDE.md:48 — "| `<leader>bp` / `<leader>bP` | BufferLine move prev/next | Pin buffer / delete non-pinned |".
Current code: `/Users/zcu/.config/nvim/lua/config/keymaps.lua`:53-54 deletes both; :55-60 binds `<leader>bn` → `:BufferLineMoveNext<Return>`; :61-66 binds `<leader>bp` → `:BufferLineMovePrev<Return>`. `<leader>bP` is never re-bound (runtime-facts.md:12 confirms it resolves to nil).
Gap: the row implies `<leader>bP` becomes "move next"; it is simply gone, and the real "move next" key `<leader>bn` is absent from this table (keymaps.md:62-63 and KEYMAPS.md:26-27 get it right).
Fix: update doc. Split into two rows: "| `<leader>bp` | BufferLine move prev | Pin buffer |" and "| `<leader>bP` | Deleted (nothing) | Delete non-pinned buffers |"; add `<leader>bn` as a new-key row.
Confidence: HIGH
Counter-argument: keymaps.md documents it correctly, so the information exists. It stands — CLAUDE.md is the always-loaded summary, and it is the one that is wrong.

## LOW: Root `KEYMAPS.md` is an unreferenced duplicate that drifts against `docs/specs/keymaps.md`
Spec requirement: both `/Users/zcu/.config/nvim/KEYMAPS.md`:1-173 and `/Users/zcu/.config/nvim/docs/specs/keymaps.md`:1-238 claim to be the complete custom-keymap reference.
Current code: CLAUDE.md:128-131 @-includes only `@docs/specs/keymaps.md`. KEYMAPS.md is never referenced by any doc.
Gap — content in only one file:
- specs-only: "Disabled Keys" table (:85-94) incl. `<leader>uz`/`<leader>uZ`/`<leader>bP`; nvim-dap section (:213-237); Yank Paths / LSP section headings; Flash `s` row (:153).
- KEYMAPS.md-only: `<leader>r` `-F -i` detail — "fixed-string, case-insensitive" (:28); blink `<C-b>` row (:147); Oil row ordering.
- Both wrong: harpoon section (specs :120-126, KEYMAPS.md :56-64). Both missing: Oil `gy`, checkmate `<leader>tx`/`<leader>th`, insert-mode `*`.
- KEYMAPS.md also has no YAML frontmatter and sits outside `docs/`.
Fix: update docs. Merge the two KEYMAPS.md-only details into `docs/specs/keymaps.md`, then replace KEYMAPS.md's body with a one-line pointer to `docs/specs/keymaps.md` (or delete it — flagged, not removed).
Confidence: HIGH
Counter-argument: a root-level KEYMAPS.md is discoverable for a human browsing the repo. It stands — a pointer file keeps that discoverability without a second copy to drift.

## LOW: `S` disable rationale differs between doc and code comment
Spec requirement: keymaps.md:90 — "| `S` | n | Conflicts with mini.surround workflow |"; plugins.md:181 — "to avoid conflicting with the disabled `S` normal-mode mapping and mini.surround workflow"; CLAUDE.md:49 lists the replaced default as "Substitute line".
Current code: `/Users/zcu/.config/nvim/lua/config/keymaps.lua`:80 — "-- disable default 'S' key since it's equivalent to doing 'cc' and clashes with nvim-surround"; :81 `vim.keymap.set({ "n" }, "S", "", { noremap = true })`. `nvim-surround` has no entry in lazy-lock.json; the installed plugin is `mini.surround` (lua/misc/mini-surround.lua:3).
Gap: doc and code comment name different plugins. The doc's `mini.surround` matches what is installed; the code comment is stale.
Fix: update code comment (out of doc scope — flagged for the parent) to say mini.surround, or note in keymaps.md:90 "code comment at keymaps.lua:80 still says nvim-surround (not installed)". CLAUDE.md:49 "Substitute line" is a Vim default, not a LazyVim one — the table header says "LazyVim default replaced".
Confidence: MEDIUM — both sources are prose rationale; neither changes behavior.
Counter-argument: cosmetic. It stands as LOW because it names a plugin that is not installed, which reads as a real dependency.

## LOW: autocmds do not always load on VeryLazy
Spec requirement: architecture.md:25 — "keymaps and autocmds on the `VeryLazy` event"; architecture.md:54 — "| `autocmds.lua` | … | VeryLazy event |".
Current code: `~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/config/init.lua`:179 — `local lazy_autocmds = vim.fn.argc(-1) == 0`; :180-182 loads autocmds immediately when that is false; :189-190 defers only when it is true. Keymaps always load in the VeryLazy callback (:192). Options load earlier still, at :332.
Gap: launching `nvim somefile.lua` loads autocmds during LazyVim setup, before VeryLazy. The doc states the deferred path as unconditional.
Fix: update doc. architecture.md:25 → "options first; keymaps on `VeryLazy`; autocmds during setup when Neovim is started with file arguments, otherwise on `VeryLazy`."
Confidence: HIGH
Counter-argument: the ordering relative to user code is unchanged either way. It stands as LOW — it matters only when reasoning about an autocmd that fires on the first buffer.

## LOW: Spec frontmatter `updated:` dates predate every drift in this report
Spec requirement: architecture.md:4, plugins.md:4, keymaps.md:4, customization-guide.md:4 — `updated: 2026-05-26`; debugging.md:4 — `updated: 2026-07-01`. All five carry `status: active`.
Current code: `/Users/zcu/.config/nvim/.git/logs/HEAD`:88-98 — `941603d` harpoon disabled and `3922f2b` checkmate states 2026-06-08; `ed5fb23` oil buffer cleanup 2026-06-09; `276cc2b` fzf 2026-07-03; `5de9fee` oil `gy` 2026-07-09; `cd512b0` fzf gitignored+hidden 2026-08-17; `5a320bc` 2026-09-06.
Gap: every finding above traces to a commit after the specs' `updated` date. debugging.md (2026-07-01) is the only doc with no drift found — the dap.core, php and rust claims checked all verified; its nlua/osv, `launch.json`-loading, adapter-table and chrome-filetype claims were not checked (see Verification Notes).
Fix: update docs. Bump `updated:` on each spec file when the above fixes land.
Confidence: HIGH — timestamps decoded from the reflog's unix-seconds field.
Counter-argument: none.

## Referential Integrity Table

| Source doc:line | Reference | Target | Exists? |
|-|-|-|-|
| CLAUDE.md:128 | `@docs/specs/architecture.md` | /Users/zcu/.config/nvim/docs/specs/architecture.md | YES |
| CLAUDE.md:129 | `@docs/specs/plugins.md` | /Users/zcu/.config/nvim/docs/specs/plugins.md | YES |
| CLAUDE.md:130 | `@docs/specs/keymaps.md` | /Users/zcu/.config/nvim/docs/specs/keymaps.md | YES |
| CLAUDE.md:131 | `@docs/specs/customization-guide.md` | /Users/zcu/.config/nvim/docs/specs/customization-guide.md | YES |
| (none) | `docs/specs/debugging.md` | exists, 300 lines | YES — but never @-included (see MEDIUM finding) |
| architecture.md:66 | "see `debugging.md`" | docs/specs/debugging.md | YES |
| plugins.md:81 | "See `debugging.md`" | docs/specs/debugging.md | YES |
| keymaps.md:215 | "See `debugging.md`" | docs/specs/debugging.md | YES |
| debugging.md:19 | `#adding-a-language` | debugging.md:230 "## Adding a language" | YES |
| debugging.md:29, :213 | `#installation` | debugging.md:207 "## Installation" | YES |
| debugging.md:71, :95 | `#rust` | debugging.md:88 "### Rust" | YES |
| debugging.md:122, :149 | `#project-launchjson` | debugging.md:200 "## Project launch.json" | YES |
| architecture.md:66,:110 | `lua/langs/dap.lua`, `snippets/*.json` | both exist (dap.lua 12 lines; cpp.json, rust.json) | YES |
| architecture.md:107 | `lazy-lock.json` | /Users/zcu/.config/nvim/lazy-lock.json | YES |
| architecture.md:108 | `.neoconf.json` | file exists; consuming plugin does not | FILE YES / PLUGIN NO |
| plugins.md:68-69 | `cpp.json` / `rust.json` prefixes | snippets/cpp.json:3,15; snippets/rust.json:3,10,17,24 | YES — all six prefixes match |
| CLAUDE.md:115 | `~/Library/Application Support/lazygit/config.yml` | outside repo | NOT VERIFIED (out of scope; snacks.lua:7 `configure = false` confirmed) |
| plugins.md:106, keymaps.md:120, KEYMAPS.md:58 | `lua/search/harpoon2.lua` | file exists, contents commented out | FILE YES / CONTENT NO |

## Optional Improvements

1. Add a "Disabled / removed" section to plugins.md listing harpoon2.lua (commented out, `941603d`) and scrollbar.lua (already noted at :173-175), so empty specs are not read as bugs.
2. `lua/config/options.lua` carries several comments that contradict their own code — `:5` "Disable relative line numbers" above `relativenumber = true`, `:63` "Use actual tabs (not spaces)" above `expandtab = true`, `:95` "Highlight the current line" above `cursorline = false`, `:101` "Keep 8 lines visible" above `scrolloff = 3`. Out of scope for doc compliance; flagged for the code reviewer.
3. `KEYMAPS.md` has no YAML frontmatter and lives outside `docs/`, unlike every file under `docs/specs/`.
4. debugging.md:194-198 documents the `dap.nlua` "Run this file" config as broken upstream — that is the only spec doc that records a known-broken path. The same pattern would help elsewhere (e.g. a "Known gaps" section in plugins.md).

## Verification Notes

Verified this session by reading source: all files listed in the matrix and findings, plus `~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/config/{keymaps.lua,init.lua}`, `.../plugins/{formatting.lua,xtras.lua}`, `.../plugins/extras/{coding/blink.lua,coding/mini-comment.lua,dap/core.lua,lang/php.lua,lang/rust.lua}`, `~/.local/share/nvim/lazy/checkmate.nvim/lua/checkmate/config/{init.lua,defaults.lua}`, `~/.local/share/nvim/lazy/conform.nvim/lua/conform/init.lua`, `~/.local/share/nvim/lazy/blink.cmp/lua/blink/cmp/config/snippets.lua` and `.../sources/snippets/default/registry.lua`, `/Users/zcu/.config/nvim/{lazy-lock.json,.git/packed-refs,.git/logs/HEAD,snippets/cpp.json,snippets/rust.json}`.

Not verified this session: debugging.md's `dap.nlua`/osv claims (port 8086, `run_this` removed upstream, :184-198), its `launch.json`-loading claim (the comment at dap/core.lua:71 was read, not the loading call), its adapter→language table (:219-224), and its `chrome` vs `pwa-chrome` filetype-mapping claim (:129-131); the external lazygit config file (outside the repo); anything requiring a running Neovim. No Bash tool was available, so `git log` was unavailable — commit dates were decoded from the unix-seconds field of `.git/logs/HEAD`, where all six referenced hashes were present.
